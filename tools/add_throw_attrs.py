#!/usr/bin/env python3
"""Annotate android headers with __THROW/__THROWNL from glibc mapping.

Approach: 
1. Strip all comments from the file (producing clean text + position map)
2. Find function declarations in clean text
3. Map positions back to original file to insert annotations
"""

import json
import os
import re
import sys

def load_func_set(path):
    with open(path) as f:
        return set(json.load(f))

# ===== Directories to skip =====
SKIP_DIR_PREFIXES = (
    'c++/', 'EGL/', 'GLES/', 'GLES2/', 'GLES3/', 'KHR/',
    'OMXAL/', 'SLES/', 'aaudio/', 'amidi/', 'android/', 'camera/',
    'drm/', 'linux/', 'media/', 'misc/', 'mtd/',
    'rdma/', 'scsi/', 'sound/', 'video/', 'vk_video/', 'vulkan/', 'xen/',
    'unicode/', 'asm-generic/',
    'aarch64-unknown-linux-android/', 'armv5-unknown-linux-androideabi/',
    'armv7-unknown-linux-androideabi/', 'i686-unknown-linux-android/',
    'mips64el-unknown-linux-android/', 'mipsel-unknown-linux-android/',
    'riscv64-unknown-linux-android/', 'x86_64-unknown-linux-android/',
)

def should_skip(rel_path):
    for prefix in SKIP_DIR_PREFIXES:
        if rel_path.startswith(prefix):
            return True
    return False

# ===== Comment stripping with position mapping =====
def strip_comments_with_map(text):
    """Remove C comments (/* */ and //) and replace string/char interior with spaces.
    
    Returns (clean_text, pos_map) where pos_map[i] = original position for clean-text position i.
    pos_map[i] = j means clean_text[i] maps to text[j].
    For positions that are removed (comments), there's no mapping.
    String/char literal interior is replaced with spaces so content doesn't leak into pattern matching.
    """
    result_chars = []
    pos_map = []
    i = 0
    in_block_comment = False
    in_line_comment = False
    in_string = False
    in_char = False
    
    while i < len(text):
        c = text[i]
        
        if in_block_comment:
            if c == '*' and i + 1 < len(text) and text[i+1] == '/':
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue
        
        if in_line_comment:
            if c == '\n':
                in_line_comment = False
                result_chars.append(c)
                pos_map.append(i)
            i += 1
            continue
        
        if in_string:
            if c == '\\' and i + 1 < len(text):
                result_chars.append(' ')
                pos_map.append(i)
                result_chars.append(' ')
                pos_map.append(i+1)
                i += 2
                continue
            elif c == '"':
                in_string = False
                result_chars.append(c)
                pos_map.append(i)
            else:
                result_chars.append(' ')
                pos_map.append(i)
            i += 1
            continue
        
        if in_char:
            if c == '\\' and i + 1 < len(text):
                result_chars.append(' ')
                pos_map.append(i)
                result_chars.append(' ')
                pos_map.append(i+1)
                i += 2
                continue
            elif c == "'":
                in_char = False
                result_chars.append(c)
                pos_map.append(i)
            else:
                result_chars.append(' ')
                pos_map.append(i)
            i += 1
            continue
        
        # Not in any comment/string
        if c == '/' and i + 1 < len(text):
            if text[i+1] == '/':
                in_line_comment = True
                i += 2
                continue
            elif text[i+1] == '*':
                in_block_comment = True
                i += 2
                continue
        
        if c == '"':
            in_string = True
            result_chars.append(c)
            pos_map.append(i)
            i += 1
            continue
        
        if c == "'":
            in_char = True
            result_chars.append(c)
            pos_map.append(i)
            i += 1
            continue
        
        # Normal character
        result_chars.append(c)
        pos_map.append(i)
        i += 1
    
    return ''.join(result_chars), pos_map


# ===== Function declaration detection =====
SKIP_KEYWORDS = {
    'if', 'while', 'for', 'switch', 'return', 'sizeof', 'defined', 'else',
    'case', 'do', 'int', 'char', 'void', 'float', 'double', 'long', 'short',
    'unsigned', 'signed', 'const', 'volatile', 'auto', 'register', 'struct',
    'union', 'enum', 'typedef', 'static', 'extern', 'inline', '__inline',
    '__inline__', '__extension__',
}

def find_func_declarations(clean_text):
    """Find function declarations in comment-free text.
    Returns list of {name, clean_start, clean_end, semi_pos, already_has_throw}
    where positions are in clean_text.
    """
    results = []
    
    # Normalize whitespace for parsing but keep original positions
    lines = clean_text.split('\n')
    
    brace_depth = 0
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Track brace depth to skip function bodies.
        # Don't count braces on extern "C" { lines since declarations inside should be annotated.
        if not stripped.startswith('extern "C"'):
            brace_depth += line.count('{')
        brace_depth -= line.count('}')
        if brace_depth < 0:
            brace_depth = 0
        
        # Skip lines inside braces
        if brace_depth > 0:
            i += 1
            continue
        
        # Skip empty lines, preprocessor lines
        if not stripped or stripped.startswith('#'):
            i += 1
            continue
        
        # Build statement up to ;
        # Stop at lines that can't be part of a declaration:
        #   preprocessor, '}' (end of block), blank lines
        stmt_lines = []
        j = i
        while j < len(lines):
            l = lines[j]
            ls = l.strip()
            # Stop at preprocessor lines or block-close lines
            if ls.startswith('#') or ls == '}' or ls == '};' or (not ls and j > i):
                break
            stmt_lines.append(l)
            if ';' in l and not l.rstrip().endswith('\\'):
                break
            j += 1
        
        stmt_text = '\n'.join(stmt_lines)
        
        # Skip if no ; or (
        if ';' not in stmt_text or '(' not in stmt_text:
            i = j + 1
            continue
        
        # Flatten for easier pattern matching
        flat = ' '.join(stmt_text.split())
        
        # Skip typedef, struct, union, enum
        first_word = flat.split()[0] if flat.split() else ''
        if first_word in ('typedef', 'struct', 'union', 'enum'):
            i = j + 1
            continue
        
        # Skip __BEGIN_DECLS / __END_DECLS
        if flat in ('__BEGIN_DECLS', '__END_DECLS', 'extern "C" {', '}'):
            i = j + 1
            continue
        
        # Skip inline definitions (contain {)
        if '{' in flat:
            i = j + 1
            continue
        
        # Strip leading keywords/attributes to get to the function name
        working = flat
        
        # Remove leading extern/static/inline
        working = re.sub(r'^(extern\s+|static\s+|inline\s+|__inline__\s+|__static_inline__\s+)*', '', working)
        working = re.sub(r'^__extension__\s+', '', working)
        
        # Remove leading __attribute__((...)) blocks
        while True:
            m = re.match(r'__attribute__\s*\(\(.*?\)\)\s*', working, re.DOTALL)
            if m:
                working = working[m.end():]
            else:
                break
        
        # Remove leading __attribute_pure__
        working = re.sub(r'^__attribute_pure__\s+', '', working)
        working = re.sub(r'^__nodiscard\s+', '', working)
        working = re.sub(r'^__RENAME\s*\([^)]*\)\s+', '', working)
        
        # Remove __printflike/__scanflike attributes (they appear before return type sometimes)
        while True:
            m = re.match(r'__(printflike|scanflike|printf|scanf)\s*\([^)]*\)\s+', working)
            if m:
                working = working[m.end():]
            else:
                break
        
        # Now find the function's parameter list opening paren
        paren_idx = working.find('(')
        if paren_idx < 0:
            i = j + 1
            continue
        
        before_paren = working[:paren_idx].strip()
        
        # Skip if this looks like a return/assignment: "return func_name(..." or "x = func_name(..."
        if before_paren.startswith('return ') or before_paren == 'return':
            i = j + 1
            continue
        if '=' in before_paren:
            i = j + 1
            continue
        
        # Get last token
        tokens = before_paren.split()
        if not tokens:
            i = j + 1
            continue
        
        candidate_name = tokens[-1].strip('*')
        
        # Skip function pointers: void (*name)(
        if '(' in before_paren and ')' in before_paren:
            i = j + 1
            continue
        
        # Skip keywords
        if candidate_name in SKIP_KEYWORDS:
            i = j + 1
            continue
        
        # Must start with letter or underscore
        if not candidate_name or not re.match(r'^[a-zA-Z_]', candidate_name):
            i = j + 1
            continue
        
        # Check if already has __THROW or __THROWNL
        has_throw = '__THROW' in flat or '__THROWNL' in flat
        
        # Find position of ';' in clean text
        # We need the character position in clean_text, not just line
        # Calculate position from start of stmt_text
        stmt_start_clean = clean_text.find(stmt_text)
        if stmt_start_clean < 0:
            i = j + 1
            continue
        
        last_semi = stmt_text.rfind(';')
        semi_pos_clean = stmt_start_clean + last_semi
        
        # Find closing paren of the function parameter list for insertion point.
        # Insert __THROW right after the ) so it's the first thing after the
        # function prototype, before any __attribute__, __RENAME, etc.
        ins_pos_clean = semi_pos_clean  # fallback
        func_re = re.compile(r'\b' + re.escape(candidate_name) + r'\s*\(')
        m = func_re.search(stmt_text)
        if m:
            depth = 1
            k = m.end()
            while k < len(stmt_text) and depth > 0:
                if stmt_text[k] == '(':
                    depth += 1
                elif stmt_text[k] == ')':
                    depth -= 1
                k += 1
            if depth == 0:
                # Position right after ), past any whitespace
                ins = k
                while ins < len(stmt_text) and stmt_text[ins] in ' \t\n\r':
                    ins += 1
                ins_pos_clean = stmt_start_clean + ins
        
        results.append({
            'name': candidate_name,
            'stmt_text': stmt_text,
            'stmt_flat': flat,
            'stmt_start_clean': stmt_start_clean,
            'semi_pos_clean': semi_pos_clean,
            'ins_pos_clean': ins_pos_clean,
            'already_has_throw': has_throw,
        })
        
        i = j + 1
    
    return results


def process_file(filepath, rel_path, nothrow_leaf, nothrow_only, neither, dry_run=False):
    """Process a single header file."""
    glibc_all = nothrow_leaf | nothrow_only | neither
    
    with open(filepath) as f:
        content = f.read()
    
    # Strip comments and build position map
    clean_text, pos_map = strip_comments_with_map(content)
    
    # Find function declarations in clean text
    decls = find_func_declarations(clean_text)
    
    # Find which decls need annotation
    to_annotate = []
    already_count = 0
    
    for d in decls:
        name = d['name']
        if name in glibc_all:
            if d['already_has_throw']:
                already_count += 1
            else:
                to_annotate.append(d)
    
    if not to_annotate:
        return False, 0, already_count
    
    # Apply modifications to original content
    # Build list of (original_pos, annotation_text) sorted from end of file
    modifications = []
    
    for d in to_annotate:
        name = d['name']
        
        # Determine annotation text
        # Trailing space (not leading) because we insert right at the next token's
        # first character, and the original whitespace before it serves as separator
        # between )/__RENAME and __THROW.
        if name in nothrow_leaf:
            annotation = '__THROW '
        elif name in nothrow_only:
            annotation = '__THROWNL '
        else:
            continue
        
        # Map ins_pos from clean to original
        ins_pos_clean = d['ins_pos_clean']
        if ins_pos_clean < len(pos_map):
            ins_pos_orig = pos_map[ins_pos_clean]
        else:
            continue
        
        # Map semi_pos for safety check
        semi_pos_clean = d['semi_pos_clean']
        semi_pos_orig = pos_map[semi_pos_clean] if semi_pos_clean < len(pos_map) else ins_pos_orig
        
        # Before inserting, verify no __THROW/__THROWNL in the declaration itself.
        # Use the statement text from clean text to find the declaration bounds.
        stmt_clean = d['stmt_flat']
        stmt_len_clean = len(stmt_clean)
        # Estimate where the declaration starts in original
        orig_start = max(0, semi_pos_orig - stmt_len_clean - 30)
        orig_till_semi = content[orig_start:semi_pos_orig]
        
        # Check only within the declaration context (up to the semicolon we found)
        # by checking for __THROW or __THROWNL between the function name and ;
        func_name = d['name']
        name_idx = orig_till_semi.rfind(func_name)
        if name_idx >= 0:
            decl_only = orig_till_semi[name_idx:semi_pos_orig - orig_start]
            if '__THROW' in decl_only or '__THROWNL' in decl_only:
                continue
        
        modifications.append((ins_pos_orig, annotation))
    
    if not modifications:
        return False, 0, already_count
    
    # Apply in reverse order (last to first to preserve positions)
    modifications.sort(key=lambda x: x[0], reverse=True)
    
    content_list = list(content)
    for pos, ann in modifications:
        content_list.insert(pos, ann)
    
    modified_content = ''.join(content_list)
    
    # Verify we can still find comments and structure
    if not dry_run:
        with open(filepath, 'w') as f:
            f.write(modified_content)
    
    print(f"  [{'MODIFY' if not dry_run else 'DRY-RUN'}] {rel_path}: {len(modifications)} added, {already_count} already annotated", file=sys.stderr)
    
    return True, len(modifications), already_count


def main():
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <include_dir> <throw.json> <thrownl.json> <none.json> [--dry-run]",
              file=sys.stderr)
        sys.exit(1)
    
    include_dir = sys.argv[1]
    throw_json = sys.argv[2]
    thrownl_json = sys.argv[3]
    none_json = sys.argv[4]
    dry_run = '--dry-run' in sys.argv
    
    nothrow_leaf = load_func_set(throw_json)
    nothrow_only = load_func_set(thrownl_json)
    neither = load_func_set(none_json)
    print(f"Loaded {len(nothrow_leaf)} nothrow_leaf, {len(nothrow_only)} nothrow_only, "
          f"{len(neither)} neither, {len(nothrow_leaf | nothrow_only | neither)} total",
          file=sys.stderr)
    
    # Find all .h files
    all_h_files = []
    for root, dirs, files in os.walk(include_dir):
        for f in files:
            if f.endswith('.h'):
                rel_path = os.path.relpath(os.path.join(root, f), include_dir)
                if should_skip(rel_path):
                    continue
                all_h_files.append(rel_path)
    
    print(f"Found {len(all_h_files)} relevant .h files", file=sys.stderr)
    
    total_added = 0
    total_already = 0
    total_modified = 0
    
    for rel_path in sorted(all_h_files):
        full_path = os.path.join(include_dir, rel_path)
        modified, added, already = process_file(full_path, rel_path,
                                                nothrow_leaf, nothrow_only, neither,
                                                dry_run)
        if modified:
            total_modified += 1
            total_added += added
        total_already += already
    
    print(file=sys.stderr)
    print(f"Summary: {total_modified} files modified, {total_added} annotations added, {total_already} already annotated", file=sys.stderr)


if __name__ == '__main__':
    main()
