#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

extern SEXP RC_rglimpse2_cpu_features(void);

static const R_CallMethodDef CallEntries[] = {
    {"RC_rglimpse2_cpu_features", (DL_FUNC) &RC_rglimpse2_cpu_features, 0},
    {NULL, NULL, 0}
};

void attribute_visible R_init_RGlimpse2(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
