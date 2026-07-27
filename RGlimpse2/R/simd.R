#' RGlimpse2 phasing-executable dispatch information
#'
#' RGlimpse2 dispatches whole child executables rather than mutating a backend
#' in the R process. The scalar SIMDe executable is always the fallback. A
#' native executable is selected only when it was built and the package's
#' baseline CPUID/HWCAP probe confirms CPU and operating-system support.
#'
#' @param requested_backend Requested backend (`"auto"`, `"scalar"`,
#'   `"avx2"`, `"avx512"`, or `"neon"`).
#' @param selected_backend Resolved backend.
#' @param compiled_backends Backends represented by installed executables.
#' @param cpu_supported_backends Backends supported by the runtime CPU and OS.
#' @param available_backends Intersection of compiled and CPU-supported
#'   backends.
#' @param phase_executable Selected absolute executable path.
#' @param target_arch,target_os Baseline probe target identifiers.
#' @export
RGlimpse2SimdInfo <- S7::new_class(
  "RGlimpse2SimdInfo",
  package = "RGlimpse2",
  properties = list(
    requested_backend = .rgl_id,
    selected_backend = .rgl_id,
    compiled_backends = S7::class_character,
    cpu_supported_backends = S7::class_character,
    available_backends = S7::class_character,
    phase_executable = .rgl_scalar_string,
    target_arch = .rgl_id,
    target_os = .rgl_id
  )
)

.rgl_phase_backend <- function(backend) {
  backend <- .rgl_assert_scalar_character(backend, "phase_backend")
  allowed <- c("auto", "scalar", "avx2", "avx512", "neon")
  if (!backend %in% allowed) {
    .rgl_signal_contract_violation(
      paste0("phase_backend must be one of ", paste(allowed, collapse = ", ")),
      code = "invalid_phase_backend",
      details = list(phase_backend = backend)
    )
  }
  backend
}

.rgl_cpu_features <- function() {
  .Call(C_RC_rglimpse2_cpu_features)
}

#' Inspect and resolve packaged GLIMPSE2 phase SIMD executables
#'
#' This function does not set process-global state. Pass the same backend to
#' `rglimpse2_executables()` to obtain the selected executable explicitly.
#' AVX-512 means AVX-512F, AVX-512BW, and AVX-512VL with enabled OS ZMM state.
#'
#' @param phase_backend One of `"auto"`, `"scalar"`, `"avx2"`,
#'   `"avx512"`, or `"neon"`.
#' @return `RGlimpse2SimdInfo` or `RGlimpse2InputErrorValue` when the requested
#'   backend is unavailable.
#' @export
rglimpse2_simd_info <- function(phase_backend = "auto") {
  .rgl_contract_call(
    code = "invalid_simd_request",
    details = list(api = "rglimpse2_simd_info"),
    expression = {
      phase_backend <- .rgl_phase_backend(phase_backend)
      directory <- system.file("glimpse2", "bin", package = "RGlimpse2")
      phase_paths <- c(
        scalar = .rgl_program_path(directory, "GLIMPSE2_phase"),
        avx2 = .rgl_program_path(directory, "GLIMPSE2_phase_avx2"),
        avx512 = .rgl_program_path(directory, "GLIMPSE2_phase_avx512"),
        neon = .rgl_program_path(directory, "GLIMPSE2_phase_neon")
      )
      compiled <- names(phase_paths)[file.exists(phase_paths)]

      features <- .rgl_cpu_features()
      cpu <- c(
        "scalar",
        if (isTRUE(features$avx2)) "avx2",
        if (isTRUE(features$avx512)) "avx512",
        if (isTRUE(features$neon)) "neon"
      )
      available <- intersect(compiled, cpu)
      selected <- if (identical(phase_backend, "auto")) {
        priority <- c("avx512", "avx2", "neon", "scalar")
        candidates <- priority[priority %in% available]
        if (length(candidates)) candidates[[1L]] else "scalar"
      } else {
        phase_backend
      }

      if (!selected %in% available) {
        return(rglimpse2_error_value(
          message = paste0("requested phase backend is unavailable: ", selected),
          kind = "input",
          code = "phase_backend_unavailable",
          details = list(
            requested_backend = phase_backend,
            compiled_backends = compiled,
            cpu_supported_backends = cpu,
            target_arch = features$target_arch,
            target_os = features$target_os
          )
        ))
      }

      RGlimpse2SimdInfo(
        requested_backend = phase_backend,
        selected_backend = selected,
        compiled_backends = compiled,
        cpu_supported_backends = cpu,
        available_backends = available,
        phase_executable = unname(phase_paths[[selected]]),
        target_arch = features$target_arch,
        target_os = features$target_os
      )
    }
  )
}
