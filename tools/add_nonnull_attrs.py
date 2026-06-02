#!/usr/bin/env python3
"""
Add __attribute__((nonnull(...))) to function declarations based on _Nonnull
type qualifier annotations on parameters.

The Android NDK headers use Clang's _Nonnull/_Nullable type qualifiers, which
GCC does not recognize (they are #defined to empty in sys/cdefs.h). This script
adds the equivalent GCC __attribute__((nonnull(indices...))) to each function
declaration that has _Nonnull-annotated pointer parameters.

Existing _Nonnull annotations are preserved (they are removed separately). The
script only ADDS the GCC attributes.
"""

import os
import re
import sys
from pathlib import Path

SKIP_DIRS = {
    'aarch64-linux-android',
    'arm-linux-androideabi',
    'i686-linux-android',
    'x86_64-linux-android',
    'riscv64-linux-android',
}

NULLABILITY_KEYWORDS = frozenset({
    '_Nonnull', '_Nullable', '_Null_unspecified',
    '__BIONIC_COMPLICATED_NULLNESS',
})

C_KEYWORDS = frozenset({
    'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do',
    'double', 'else', 'enum', 'extern', 'float', 'for', 'goto', 'if',
    'inline', 'int', 'long', 'register', 'restrict', 'return', 'short',
    'signed', 'sizeof', 'static', 'struct', 'switch', 'typedef', 'union',
    'unsigned', 'void', 'volatile', 'while', '_Bool', '_Complex', '_Imaginary',
    '__inline', '__inline__', '__extension__',
    '__BEGIN_DECLS', '__END_DECLS', '__BEGIN_DECLS', '__END_DECLS',
})

SKIP_KEYWORDS = NULLABILITY_KEYWORDS | C_KEYWORDS


def is_ident_char(c):
    return c.isalnum() or c == '_'


def find_matching_paren(text, start):
    """Find matching ')' for '(' at position start."""
    depth = 1
    i = start + 1
    n = len(text)
    while i < n and depth > 0:
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
        elif text[i] == '"':
            i += 1
            while i < n and text[i] != '"':
                if text[i] == '\\':
                    i += 1
                i += 1
        elif text[i] == "'":
            i += 1
            while i < n and text[i] != "'":
                if text[i] == '\\':
                    i += 1
                i += 1
        i += 1
    return i - 1 if depth == 0 else -1


def skip_ws_and_attrs(text, pos):
    """Skip whitespace and attribute macros starting from pos. Return new pos."""
    n = len(text)
    while pos < n:
        # Whitespace
        if text[pos] in ' \t\n\r\f\v':
            pos += 1
            continue
        # Check if we're at an identifier (attribute macro like __INTRODUCED_IN)
        if pos < n and (text[pos].isalpha() or text[pos] == '_'):
            start = pos
            while pos < n and (text[pos].isalnum() or text[pos] == '_'):
                pos += 1
            ident = text[start:pos]
            # Skip if it looks like an attribute macro (starts with __ and may have ())
            # or known attribute-like macros
            if ident in ('__INTRODUCED_IN', '__RENAME', '__attribute_pure__',
                         '__printflike', '__scanflike', '__strftimelike',
                         '__nodiscard', '__wur', '__noreturn', '__dead',
                         '__mallocfunc', '__returns_twice', '__warnattr_strict',
                         '__clang_error_if', '__clang_warning_if', '__enable_if',
                         '__BIONIC_AVAILABILITY_GUARD',
                         '__INTRODUCED_IN_32', '__INTRODUCED_IN_64',
                         '__INTRODUCED_IN_ARM', '__INTRODUCED_IN_X86',
                         '__INTRODUCED_IN_MIPS'):
                # Check if followed by (
                ws_pos = pos
                while ws_pos < n and text[ws_pos] in ' \t\n\r':
                    ws_pos += 1
                if ws_pos < n and text[ws_pos] == '(':
                    close = find_matching_paren(text, ws_pos)
                    if close > ws_pos:
                        pos = close + 1
                        continue
            # Not an attribute macro, stop here
            break
        if text.startswith('__attribute__', pos):
            pos += 13  # len('__attribute__')
            # Skip whitespace then '('
            while pos < n and text[pos] in ' \t\n':
                pos += 1
            if pos < n and text[pos] == '(':
                close = find_matching_paren(text, pos)
                if close > pos:
                    pos = close + 1
                    continue
            break
        if text[pos] == '(':
            # Could be __attribute((...)) without __attribute__ keyword
            # Let's check a few tokens back
            break
        break
    return pos


def scan_function_declarations(text):
    """
    Find function declarations in text.

    Looks for patterns:
      [...stuff...] ( params ) [...attributes...] ;
    or
      [...stuff...] ( params ) [...attributes...] {

    Returns list of (func_start, paren_start, close_paren, decl_end, params_text)
    where:
      - func_start: start of relevant content (return type + name + params)
      - paren_start: position of '('
      - close_paren: position of ')'
      - decl_end: position right after ';' or '{'
      - params_text: text between '(' and ')'
    """
    declarations = []
    n = len(text)
    i = 0

    while i < n:
        c = text[i]

        # Skip comments and strings
        if c == '/' and i + 1 < n:
            if text[i + 1] == '/':
                end = text.find('\n', i)
                i = (end + 1) if end != -1 else n
                continue
            elif text[i + 1] == '*':
                end = text.find('*/', i + 2)
                i = (end + 2) if end != -1 else n
                continue
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                if text[i] == '\\':
                    i += 1
                i += 1
            i += 1
            continue
        if c == "'":
            i += 1
            while i < n and text[i] != "'":
                if text[i] == '\\':
                    i += 1
                i += 1
            i += 1
            continue

        # Skip preprocessor directives
        if c == '#':
            while i < n and text[i] != '\n':
                i += 1
            if i < n:
                i += 1
            continue

        # Skip function definition bodies { ... } only if preceded by ')'
        if c == '{':
            # Walk back to check if this is a function body
            before = i - 1
            while before >= 0 and text[before] in ' \t\n\r':
                before -= 1
            if before >= 0 and text[before] == ')':
                depth = 1
                i += 1
                while i < n and depth > 0:
                    if text[i] == '{':
                        depth += 1
                    elif text[i] == '}':
                        depth -= 1
                    i += 1
                continue

        # Look for '(' that could start a function parameter list
        if c == '(':
            paren_start = i

            # Check this isn't inside a something we shouldn't process
            # Walk back a bit to see context
            before = i - 1
            while before >= 0 and text[before] in ' \t\n\r':
                before -= 1

            # If preceded by ) or identifier or *, could be function
            # If preceded by = or , or ( or ! or & etc, it's an expression
            if before >= 0 and text[before] in '=!,&|<>+-*/%^~?':
                i += 1
                continue

            # Check if preceded by a known attribute macro (__INTRODUCED_IN(26), etc.)
            if before >= 0 and is_ident_char(text[before]):
                # Walk backwards to get the full identifier
                id_end = before + 1
                id_start = before
                while id_start >= 0 and is_ident_char(text[id_start]):
                    id_start -= 1
                id_start += 1
                preceding_ident = text[id_start:id_end]
                # Known attribute-like macros that take (args) and are NOT functions
                ATTR_MACROS = frozenset({
                    '__INTRODUCED_IN', '__RENAME', '__INTRODUCED_IN_32',
                    '__INTRODUCED_IN_64', '__INTRODUCED_IN_ARM',
                    '__INTRODUCED_IN_X86', '__INTRODUCED_IN_MIPS',
                    '__BIONIC_AVAILABILITY_GUARD',
                    '__attribute__', '__attribute_deprecated__',
                    '__attribute_pure__', '__attribute_const__',
                })
                if preceding_ident in ATTR_MACROS:
                    # Skip past the (...) of this macro
                    close_paren = find_matching_paren(text, i)
                    if close_paren > i:
                        i = close_paren + 1
                        continue
                    i += 1
                    continue

            # Find matching ')'
            close_paren = find_matching_paren(text, i)
            if close_paren <= i:
                i += 1
                continue

            # Check what comes after ')'
            after = skip_ws_and_attrs(text, close_paren + 1)

            if after < n and text[after] in (';', '{'):
                # This is a function declaration or definition
                # Extract the parameter list
                params_text = text[paren_start + 1:close_paren].strip()

                # Find the function name: walk back from paren_start
                func_name_start = paren_start - 1
                # skip whitespace
                while func_name_start >= 0 and text[func_name_start] in ' \t\n\r':
                    func_name_start -= 1
                # skip the function name (identifier)
                while func_name_start >= 0 and is_ident_char(text[func_name_start]):
                    func_name_start -= 1
                func_name_start += 1  # Now points to start of function name

                func_name = text[func_name_start:paren_start].strip().split()[0] if text[func_name_start:paren_start].strip() else ''
                # Remove trailing *
                func_name = func_name.rstrip('*').strip()

                decl_end = after + 1  # include ';' or '{'

                # Determine the start of the declaration (where to look for return type)
                # Walk back from func_name_start, skipping whitespace and attribute macros
                decl_start = func_name_start
                # We'll keep decl_start as the start of a meaningful block

                # Filter out obviously non-function cases:
                # - typedefs (contain 'typedef' keyword before)
                # - extern variable declarations
                # We'll check by looking for 'typedef' in the vicinity
                line_before = text[max(0, paren_start - 200):paren_start]
                if re.search(r'\btypedef\b', line_before):
                    i = close_paren + 1
                    continue

                # Check for extern variable: the pattern "extern type (*name)(...)"
                # or "extern type name[...]" or "extern type name"
                # These end with ; but are not function declarations
                # Heuristic: if what's before '(' looks like just a variable name
                # (no space-separated type parts before the name except qualifiers),
                # it might be a variable declaration.

                # Also skip if params_text is just "void" with no _Nonnull
                # (functions with no interesting params)

                declarations.append((
                    paren_start, close_paren, decl_end, params_text, func_name, func_name_start
                ))

                i = decl_end
                continue

        i += 1

    return declarations


def parse_params(params_text):
    """
    Parse parameter list into individual parameter text fragments.
    Handles nested parentheses for function pointer parameters.
    Returns list of (param_text, start_offset, end_offset).
    """
    params = []
    depth = 0
    start = 0
    i = 0
    n = len(params_text)

    while i < n:
        c = params_text[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        elif c == ',' and depth == 0:
            param = params_text[start:i].strip()
            if param:
                params.append(param)
            start = i + 1
        i += 1

    param = params_text[start:].strip()
    if param:
        params.append(param)

    return params


def find_param_name(param_text):
    """
    Find the parameter name in a parameter declaration.
    Walks right-to-left, distinguishing function pointer declarators
    `(* name)` from function parameter lists `(params)`.

    - `(* name)` groups are scanned inside (they contain the param name)
    - `(params)` groups are skipped entirely (they belong to a nested function)

    Returns (name, name_start) relative to param_text, or (None, -1).
    """
    i = len(param_text) - 1
    bracket_depth = 0

    while i >= 0:
        c = param_text[i]
        if c == ')':
            # Find matching '('
            close_paren = i
            open_paren = close_paren
            depth = 1
            open_paren -= 1
            while open_paren >= 0 and depth > 0:
                if param_text[open_paren] == ')':
                    depth += 1
                elif param_text[open_paren] == '(':
                    depth -= 1
                open_paren -= 1
            open_paren += 1  # Position of '('

            # Check content between parens
            inner = param_text[open_paren + 1:close_paren].strip()

            # Heuristic: if inner content starts with '*', it's a function
            # pointer declarator `(* name)` -> scan inside it for the name.
            # Otherwise it's a function parameter list `(params)` -> skip.
            if inner.startswith('*'):
                # Function pointer declarator - scan inside the group
                i = close_paren - 1
            else:
                # Function parameter list - skip past the opening '('
                i = open_paren - 1

        elif c == ']':
            bracket_depth += 1
            i -= 1
        elif c == '[':
            bracket_depth -= 1
            i -= 1
        elif bracket_depth > 0:
            i -= 1
        elif c in ' \t\n\r\f\v,':
            i -= 1
        elif is_ident_char(c):
            end = i + 1
            while i >= 0 and is_ident_char(param_text[i]):
                i -= 1
            start = i + 1
            token = param_text[start:end]
            if token not in SKIP_KEYWORDS:
                return token, start
        else:
            i -= 1

    return None, -1


def param_has_nonnull(param_text):
    """
    Check if a parameter's outermost pointer is annotated with _Nonnull.

    Returns True if the parameter should be listed in __attribute__((nonnull(...))).

    Heuristic:
    - Check for _Nonnull at depth 0 before the parameter name
      (covers: type* _Nonnull p, void (* _Nonnull p)(...), type* _Nullable * _Nonnull p)
    - Check for _Nonnull inside [...] after the parameter name
      (covers: int p[_Nonnull 2])
    - Do NOT count _Nonnull inside nested (...) after the parameter name
      (these belong to function pointer parameters, not this function)
    """
    name, name_pos = find_param_name(param_text)

    if name is None:
        # Unnamed parameter - check entire text for _Nonnull
        return has_nonnull_at_any_depth(param_text)

    # Check before the name (at any depth - function pointer grouping parens
    # like (* _Nonnull name) push _Nonnull to depth 1 but it still applies)
    before = param_text[:name_pos]
    if has_nonnull_at_any_depth(before):
        return True

    # Check inside [...] after the name
    after = param_text[name_pos + len(name):]
    if has_nonnull_in_brackets(after):
        return True

    return False


def has_nonnull_at_any_depth(text):
    """Check if _Nonnull appears in text at any parenthesis depth.
    
    For the "before name" part of a parameter, any _Nonnull at any depth
    is valid since the only nested parens in the type portion are function
    pointer grouping parens (* name), not function parameter lists.
    """
    i = 0
    n = len(text)
    while i < n:
        if text.startswith('_Nonnull', i):
            if (i == 0 or not is_ident_char(text[i - 1])) and \
               (i + 8 >= n or not is_ident_char(text[i + 8])):
                return True
            i += 8
        else:
            i += 1
    return False


def has_nonnull_in_brackets(text):
    """Check if _Nonnull appears inside [...] brackets in text."""
    depth = 0
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '[':
            depth += 1
            i += 1
        elif c == ']':
            depth -= 1
            i += 1
        elif c == '(':
            # Skip nested function parameter lists entirely
            close = find_matching_paren(text, i)
            if close > i:
                i = close + 1
            else:
                i += 1
        elif c == ')':
            i += 1
        elif depth > 0:
            if text.startswith('_Nonnull', i):
                if (i == 0 or not is_ident_char(text[i - 1])) and \
                   (i + 8 >= n or not is_ident_char(text[i + 8])):
                    return True
                i += 8
            else:
                i += 1
        else:
            i += 1
    return False


def process_file(filepath):
    """Process a single header file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
    except (IOError, UnicodeDecodeError) as e:
        print(f"  SKIP: {e}")
        return 0

    declarations = scan_function_declarations(original)

    # Filter to declarations with _Nonnull params
    candidates = []
    for paren_start, close_paren, decl_end, params_text, func_name, func_name_start in declarations:
        # Skip functions with no _Nonnull in params at all
        if not re.search(r'\b_Nonnull\b', params_text):
            continue

        params = parse_params(params_text)
        nonnull_indices = []

        for idx, param_text in enumerate(params):
            pt = param_text.strip()
            if pt and pt != 'void' and pt != '...':
                if param_has_nonnull(pt):
                    nonnull_indices.append(idx + 1)

        if nonnull_indices:
            candidates.append((
                paren_start, close_paren, decl_end,
                nonnull_indices, func_name_start,
            ))

    if not candidates:
        return 0

    # Apply modifications from end to start
    modified = list(original)
    changes = 0

    for paren_start, close_paren, decl_end, indices, func_name_start in sorted(
            candidates, key=lambda x: x[1], reverse=True):
        # Find the ';' or '{' at the end
        # decl_end points to position after ';' or '{'
        end_pos = decl_end - 1
        if end_pos >= len(modified) or modified[end_pos] not in (';', '{'):
            continue

        is_definition = (modified[end_pos] == '{')

        if is_definition:
            # For function definitions (inline bodies), GCC requires the attribute
            # to be placed before the declarator (function name), not after params.
            # Insert at func_name_start with a trailing space.
            attr = '__attribute__((nonnull(' + ','.join(str(i) for i in indices) + '))) '
            modified.insert(func_name_start, attr)
        else:
            # For declarations, insert before ';'
            attr = ' __attribute__((nonnull(' + ','.join(str(i) for i in indices) + ')))'
            modified.insert(end_pos, attr)
        changes += 1

    if changes > 0:
        # Normalize: collapse double spaces that might be introduced
        result = ''.join(modified)
        # But be careful not to collapse spaces in string literals
        # Since we only add __attribute__ which doesn't appear in strings, this is safe
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(result)

    return changes


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('./')
    script_name = Path(__file__).name
    files_found = 0
    total_changes = 0

    for h_file in sorted(root.rglob('*.h')):
        rel = h_file.relative_to(root)
        parts = rel.parts
        if any(p in SKIP_DIRS for p in parts):
            continue
        if h_file.name == script_name:
            continue

        try:
            # Quick check: does the file contain _Nonnull?
            content = h_file.read_text(encoding='utf-8', errors='replace')
            if '_Nonnull' not in content:
                continue
        except IOError:
            continue

        files_found += 1
        print(f"[{files_found}] {rel}", end='')
        sys.stdout.flush()

        try:
            n = process_file(str(h_file))
            if n > 0:
                print(f'  -> {n} functions annotated')
                total_changes += n
            else:
                print()
        except Exception as e:
            print(f'  ERROR: {e}')
            import traceback
            traceback.print_exc()

    print()
    print(f'Processed {files_found} files with _Nonnull annotations.')
    print(f'Added __attribute__((nonnull(...))) to {total_changes} function declarations.')
    print(f'Target directory: {root}')



if __name__ == '__main__':
    main()
