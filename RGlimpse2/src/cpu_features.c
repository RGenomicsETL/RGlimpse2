/*
 * Runtime CPU and OS vector-state detection for executable selection.
 *
 * This ports the guarded CPUID/xgetbv structure used by RsimdDispatch into
 * RGlimpse2 so the package has no dispatch-package runtime dependency.
 */

#include <R.h>
#include <Rinternals.h>
#include <stdint.h>

#if defined(__linux__) && defined(__arm__) && !defined(__aarch64__)
#include <sys/auxv.h>
#include <asm/hwcap.h>
#endif

#if defined(__EMSCRIPTEN__)
#define RGL_TARGET_OS "emscripten"
#elif defined(_WIN32)
#define RGL_TARGET_OS "windows"
#elif defined(__APPLE__)
#define RGL_TARGET_OS "darwin"
#elif defined(__linux__)
#define RGL_TARGET_OS "linux"
#else
#define RGL_TARGET_OS "unknown"
#endif

#if defined(__x86_64__) || defined(_M_X64)
#define RGL_TARGET_ARCH "x86_64"
#elif defined(__i386__) || defined(_M_IX86)
#define RGL_TARGET_ARCH "x86"
#elif defined(__aarch64__) || defined(_M_ARM64)
#define RGL_TARGET_ARCH "aarch64"
#elif defined(__arm__) || defined(_M_ARM)
#define RGL_TARGET_ARCH "arm"
#else
#define RGL_TARGET_ARCH "unknown"
#endif

#if defined(__x86_64__) || defined(__i386__) || defined(_M_X64) || defined(_M_IX86)
#define RGL_X86 1
#else
#define RGL_X86 0
#endif

#if RGL_X86

typedef struct RglCpuRegs {
    uint32_t eax;
    uint32_t ebx;
    uint32_t ecx;
    uint32_t edx;
} RglCpuRegs;

#if defined(_MSC_VER)
#include <intrin.h>
static int rgl_cpuid(uint32_t leaf, uint32_t subleaf, RglCpuRegs *out) {
    int regs[4];
    __cpuidex(regs, (int)leaf, (int)subleaf);
    out->eax = (uint32_t)regs[0];
    out->ebx = (uint32_t)regs[1];
    out->ecx = (uint32_t)regs[2];
    out->edx = (uint32_t)regs[3];
    return 1;
}
static uint64_t rgl_xgetbv(uint32_t index) {
    return (uint64_t)_xgetbv(index);
}
#elif defined(__GNUC__) || defined(__clang__)
#if defined(__has_include)
#if __has_include(<cpuid.h>)
#define RGL_HAVE_CPUID_H 1
#endif
#endif
#ifndef RGL_HAVE_CPUID_H
#define RGL_HAVE_CPUID_H 0
#endif
#if RGL_HAVE_CPUID_H
#include <cpuid.h>
static int rgl_cpuid(uint32_t leaf, uint32_t subleaf, RglCpuRegs *out) {
    unsigned int eax = 0, ebx = 0, ecx = 0, edx = 0;
    if (!__get_cpuid_count(leaf, subleaf, &eax, &ebx, &ecx, &edx)) {
        out->eax = out->ebx = out->ecx = out->edx = 0;
        return 0;
    }
    out->eax = (uint32_t)eax;
    out->ebx = (uint32_t)ebx;
    out->ecx = (uint32_t)ecx;
    out->edx = (uint32_t)edx;
    return 1;
}
#else
static int rgl_cpuid(uint32_t leaf, uint32_t subleaf, RglCpuRegs *out) {
    uint32_t eax = 0, ebx = 0, ecx = 0, edx = 0;
#if defined(__i386__) && defined(__PIC__)
    __asm__ volatile("xchgl %%ebx, %1; cpuid; xchgl %%ebx, %1"
                     : "=a"(eax), "=&r"(ebx), "=c"(ecx), "=d"(edx)
                     : "0"(leaf), "2"(subleaf));
#else
    __asm__ volatile("cpuid"
                     : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
                     : "a"(leaf), "c"(subleaf));
#endif
    out->eax = eax;
    out->ebx = ebx;
    out->ecx = ecx;
    out->edx = edx;
    return 1;
}
#endif
static uint64_t rgl_xgetbv(uint32_t index) {
    uint32_t eax = 0;
    uint32_t edx = 0;
    __asm__ volatile("xgetbv" : "=a"(eax), "=d"(edx) : "c"(index));
    return ((uint64_t)edx << 32) | eax;
}
#else
static int rgl_cpuid(uint32_t leaf, uint32_t subleaf, RglCpuRegs *out) {
    (void)leaf;
    (void)subleaf;
    out->eax = out->ebx = out->ecx = out->edx = 0;
    return 0;
}
static uint64_t rgl_xgetbv(uint32_t index) {
    (void)index;
    return 0;
}
#endif

static int rgl_bit(uint32_t value, unsigned int bit) {
    return (value & (UINT32_C(1) << bit)) != 0;
}

static int rgl_max_leaf_at_least(uint32_t leaf) {
    RglCpuRegs regs;
    return rgl_cpuid(0, 0, &regs) && regs.eax >= leaf;
}

static int rgl_os_supports_avx(RglCpuRegs leaf1) {
    if (!rgl_bit(leaf1.ecx, 26) || !rgl_bit(leaf1.ecx, 27)) return 0;
    return (rgl_xgetbv(0) & UINT64_C(0x6)) == UINT64_C(0x6);
}

static int rgl_os_supports_avx512(RglCpuRegs leaf1) {
    if (!rgl_os_supports_avx(leaf1)) return 0;
    return (rgl_xgetbv(0) & UINT64_C(0xE6)) == UINT64_C(0xE6);
}

static int rgl_cpu_has_avx2(void) {
    RglCpuRegs leaf1;
    RglCpuRegs leaf7;
    if (!rgl_max_leaf_at_least(7) || !rgl_cpuid(1, 0, &leaf1)) return 0;
    if (!rgl_bit(leaf1.ecx, 28) || !rgl_os_supports_avx(leaf1)) return 0;
    if (!rgl_cpuid(7, 0, &leaf7)) return 0;
    return rgl_bit(leaf7.ebx, 5);
}

static int rgl_cpu_has_avx512(void) {
    RglCpuRegs leaf1;
    RglCpuRegs leaf7;
    if (!rgl_max_leaf_at_least(7) || !rgl_cpuid(1, 0, &leaf1)) return 0;
    if (!rgl_os_supports_avx512(leaf1)) return 0;
    if (!rgl_cpuid(7, 0, &leaf7)) return 0;
    return rgl_bit(leaf7.ebx, 16) &&
           rgl_bit(leaf7.ebx, 30) &&
           rgl_bit(leaf7.ebx, 31);
}

#else
static int rgl_cpu_has_avx2(void) { return 0; }
static int rgl_cpu_has_avx512(void) { return 0; }
#endif

static int rgl_cpu_has_neon(void) {
#if defined(__aarch64__) || defined(_M_ARM64)
    return 1;
#elif defined(__linux__) && defined(__arm__) && defined(HWCAP_NEON)
    return (getauxval(AT_HWCAP) & HWCAP_NEON) != 0;
#elif defined(__ARM_NEON) || defined(__ARM_NEON__)
    return 1;
#else
    return 0;
#endif
}

SEXP RC_rglimpse2_cpu_features(void) {
    const char *field_names[] = {
        "avx2", "avx512", "neon", "target_arch", "target_os"
    };
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 5));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 5));
    SET_VECTOR_ELT(out, 0, Rf_ScalarLogical(rgl_cpu_has_avx2()));
    SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(rgl_cpu_has_avx512()));
    SET_VECTOR_ELT(out, 2, Rf_ScalarLogical(rgl_cpu_has_neon()));
    SET_VECTOR_ELT(out, 3, Rf_mkString(RGL_TARGET_ARCH));
    SET_VECTOR_ELT(out, 4, Rf_mkString(RGL_TARGET_OS));
    for (R_xlen_t i = 0; i < 5; ++i) {
        SET_STRING_ELT(names, i, Rf_mkChar(field_names[i]));
    }
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}
