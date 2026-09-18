#!/usr/bin/env bash
# Recreates the symlinks in tools/stubs/libm that point at verbatim musl
# sources in the submodules/musl git submodule. Run after cloning the repo
# (or whenever symlinks went missing, e.g. after extracting a tarball or a
# checkout on a filesystem that does not support them).

set -e

cd "$(dirname "$0")/libm"
repo_root="$(git rev-parse --show-toplevel)"

if [ ! -f "${repo_root}/submodules/musl/src/complex/cacos.c" ]; then
	echo "error: the submodules/musl submodule is not initialized." >&2
	echo "       run: git submodule update --init --depth 1 submodules/musl" >&2
	exit 1
fi

# Complex family (plus internal helpers), verbatim from src/complex.
complex_sources=(
	cabs cabsf cacos cacosf cacosh cacoshf carg cargf
	casin casinf casinh casinhf catan catanf catanh catanhf
	ccos ccosf ccosh ccoshf cexp cexpf clog clogf
	cpow cpowf csin csinf csinh csinhf
	csqrt csqrtf ctan ctanf ctanh ctanhf
	cproj cprojf cprojl __cexp __cexpf
	ccoshl cexpl csinhl csqrtl ctanhl
	cabsl cacoshl cacosl cargl casinhl casinl
	catanhl catanl ccosl clogl cpowl csinl ctanl
)

# Real math, verbatim from src/math.
math_sources=(
	atan2 atan2f log2 log2f log2_data log2f_data
	rint rintf round roundf trunc truncf
	nearbyint nearbyintf lrint lrintf llrint llrintf
	# long double variants: the 53-bit branch forwards to the double
	# version (what the hand-written forwards used to do); the 64/113-bit
	# branches enable musl's real extended/quad precision implementations.
	acoshl asinhl coshl erfl expl expm1l ilogbl
	log10l log1pl log2l logl powl sinhl tanhl tgammal
	ldexpl llroundl lroundl nexttowardl
	acosl asinl atanl cbrtl exp2l fmal fmodl hypotl
	nextafterl remquol sinl cosl tanl sqrtl
	atan2l atanhl ceill fdiml floorl fmaxl fminl
	frexpl llrintl logbl lrintl nearbyintl remainderl
	rintl roundl scalblnl scalbnl truncl
	# internal helpers pulled in by the long double implementations
	__sinl __cosl __tanl __rem_pio2l __rem_pio2_large
	__polevll __math_invalidl __invtrigl sqrt_data
	# double/float error helpers referenced by log2/log2f
	__math_invalid __math_invalidf __math_divzero __math_divzerof
)

for name in "${complex_sources[@]}"; do
	rm -f "${name}.c"
	ln -s ../../../submodules/musl/src/complex/${name}.c ${name}.c
done

for name in "${math_sources[@]}"; do
	rm -f "${name}.c"
	ln -s ../../../submodules/musl/src/math/${name}.c ${name}.c
done

# erfcl is defined inside musl's erfl.c, not in a file of its own.
rm -f erfcl.c

# Verbatim musl headers.
header_sources=(
	log2_data.h log2f_data.h __invtrigl.h sqrt_data.h
)

for name in "${header_sources[@]}"; do
	rm -f "${name}"
	ln -s ../../../submodules/musl/src/math/${name} ${name}
done

# Internal headers, verbatim from src/internal.  fp_arch.h is a local
# adaptation file (not musl's) and is intentionally not managed here.
internal_headers=(
	libm.h complex_impl.h
)

for name in "${internal_headers[@]}"; do
	rm -f "${name}"
	ln -s ../../../submodules/musl/src/internal/${name} ${name}
done

echo "recreated $((${#complex_sources[@]} + ${#math_sources[@]} + ${#header_sources[@]} + ${#internal_headers[@]})) musl symlinks"
