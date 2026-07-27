#' Explicit GLIMPSE2 child executables
#'
#' @param chunk Absolute path to `GLIMPSE2_chunk`.
#' @param split_reference Absolute path to `GLIMPSE2_split_reference`.
#' @param phase Absolute path to the selected `GLIMPSE2_phase` executable.
#' @param ligate Absolute path to `GLIMPSE2_ligate`.
#' @param phase_backend Backend represented by `phase`.
#' @export
RGlimpse2Executables <- S7::new_class(
  "RGlimpse2Executables",
  package = "RGlimpse2",
  properties = list(
    chunk = .rgl_scalar_string,
    split_reference = .rgl_scalar_string,
    phase = .rgl_scalar_string,
    ligate = .rgl_scalar_string,
    phase_backend = .rgl_id
  ),
  validator = function(self) {
    paths <- c(
      chunk = self@chunk,
      split_reference = self@split_reference,
      phase = self@phase,
      ligate = self@ligate
    )
    invalid <- names(paths)[
      !vapply(paths, function(path) {
        .rgl_is_absolute_path(path) && !.rgl_has_parent_traversal(path)
      }, logical(1L))
    ]
    if (length(invalid)) {
      paste0(
        paste(invalid, collapse = ", "),
        " must be absolute paths without parent traversal"
      )
    }
  }
)

.rgl_executable_names <- c(
  chunk = "GLIMPSE2_chunk",
  split_reference = "GLIMPSE2_split_reference",
  phase = "GLIMPSE2_phase",
  ligate = "GLIMPSE2_ligate"
)

.rgl_program_path <- function(directory, name) {
  suffixes <- if (identical(.Platform$OS.type, "windows")) {
    c(".exe", "")
  } else {
    c("", ".exe")
  }
  candidates <- file.path(directory, paste0(name, suffixes))
  existing <- candidates[file.exists(candidates) & !dir.exists(candidates)]
  if (length(existing)) existing[[1L]] else candidates[[1L]]
}

.rgl_validate_packaged_htslib <- function() {
  version_path <- system.file("glimpse2", "htslib-version", package = "RGlimpse2")
  if (!nzchar(version_path) || !file.exists(version_path)) {
    return(rglimpse2_error_value(
      message = "the packaged htslib build version is missing",
      kind = "input",
      code = "packaged_htslib_version_missing"
    ))
  }
  expected <- readLines(version_path, n = 1L, warn = FALSE, encoding = "UTF-8")
  config <- tryCatch(
    rduckhts_htslib_config(validate = TRUE),
    error = identity
  )
  if (inherits(config, "error")) {
    return(rglimpse2_error_value(
      message = conditionMessage(config),
      kind = "input",
      code = "rduckhts_htslib_validation_failed",
      details = list(expected_version = expected),
      source = config
    ))
  }
  loaded <- config$runtime_version
  if (
    length(expected) != 1L || !nzchar(expected) ||
      !identical(expected, config$htslib_version) ||
      !identical(expected, loaded)
  ) {
    return(rglimpse2_error_value(
      message = "packaged, Rduckhts, and loaded htslib versions do not match",
      kind = "input",
      code = "htslib_version_mismatch",
      details = list(
        packaged_version = expected,
        rduckhts_version = config$htslib_version,
        loaded_version = loaded,
        rduckhts_build_id = config$build_id
      )
    ))
  }
  invisible(TRUE)
}

#' Resolve packaged or explicitly supplied GLIMPSE2 executables
#'
#' This function never searches `PATH`. Supply either one absolute directory
#' containing all four standard executable names or all four absolute paths.
#' With no supplied paths, only the installed package directory is inspected;
#' `phase_backend` then selects a portable or AVX2 phase executable.
#'
#' @param directory Empty or one absolute executable directory.
#' @param phase_backend Packaged phase backend: `"auto"`, `"scalar"`,
#'   `"avx2"`, `"avx512"`, or `"neon"`. It must remain `"auto"` for
#'   explicitly supplied executables.
#' @inheritParams RGlimpse2Executables
#' @return `RGlimpse2Executables` or `RGlimpse2InputErrorValue`.
#' @export
rglimpse2_executables <- function(
  directory = character(),
  chunk = character(),
  split_reference = character(),
  phase = character(),
  ligate = character(),
  phase_backend = "auto"
) {
  .rgl_contract_call(
    code = "invalid_executable_request",
    details = list(api = "rglimpse2_executables"),
    expression = {
      phase_backend <- .rgl_phase_backend(phase_backend)
      supplied <- list(
        chunk = chunk,
        split_reference = split_reference,
        phase = phase,
        ligate = ligate
      )
      lapply(names(supplied), function(name) {
        .rgl_validate_optional_path(supplied[[name]], name)
      })
      .rgl_validate_optional_path(directory, "directory")

      has_directory <- length(directory) == 1L
      supplied_count <- sum(vapply(supplied, length, integer(1L)) == 1L)
      if (has_directory && supplied_count) {
        .rgl_signal_contract_violation(
          "supply directory or four explicit executable paths, not both",
          code = "ambiguous_executable_source"
        )
      }
      if (!has_directory && supplied_count && supplied_count != 4L) {
        .rgl_signal_contract_violation(
          "all four executable paths are required when directory is omitted",
          code = "incomplete_executable_set"
        )
      }
      if ((has_directory || supplied_count) && !identical(phase_backend, "auto")) {
        .rgl_signal_contract_violation(
          "phase_backend applies only to packaged executables",
          code = "backend_with_external_executables"
        )
      }

      resolved_backend <- "external"
      if (!has_directory && !supplied_count) {
        directory <- system.file("glimpse2", "bin", package = "RGlimpse2")
        if (!nzchar(directory)) {
          return(rglimpse2_error_value(
            message = "the installed package has no executable directory",
            kind = "input",
            code = "packaged_executable_directory_missing"
          ))
        }
        htslib_ok <- .rgl_validate_packaged_htslib()
        if (rglimpse2_is_error(htslib_ok)) {
          return(htslib_ok)
        }
        simd <- rglimpse2_simd_info(phase_backend)
        if (rglimpse2_is_error(simd)) {
          return(simd)
        }
        resolved_backend <- simd@selected_backend
        supplied <- list(
          chunk = .rgl_program_path(
            directory,
            .rgl_executable_names[["chunk"]]
          ),
          split_reference = .rgl_program_path(
            directory,
            .rgl_executable_names[["split_reference"]]
          ),
          phase = simd@phase_executable,
          ligate = .rgl_program_path(
            directory,
            .rgl_executable_names[["ligate"]]
          )
        )
      } else if (has_directory) {
        if (!dir.exists(directory)) {
          return(rglimpse2_error_value(
            message = paste0("executable directory does not exist: ", directory),
            kind = "input",
            code = "executable_directory_missing",
            details = list(directory = directory)
          ))
        }
        supplied <- stats::setNames(
          lapply(
            unname(.rgl_executable_names),
            function(name) .rgl_program_path(directory, name)
          ),
          names(.rgl_executable_names)
        )
      }

      paths <- vapply(supplied, identity, character(1L), USE.NAMES = TRUE)
      missing <- names(paths)[!file.exists(paths) | dir.exists(paths)]
      non_executable <- names(paths)[
        file.exists(paths) & !dir.exists(paths) & file.access(paths, 1L) != 0L
      ]
      if (length(missing) || length(non_executable)) {
        return(rglimpse2_error_value(
          message = "one or more GLIMPSE2 executables are unavailable",
          kind = "input",
          code = "executable_unavailable",
          details = list(
            missing = missing,
            non_executable = non_executable,
            paths = as.list(paths)
          )
        ))
      }

      do.call(
        RGlimpse2Executables,
        c(as.list(paths), list(phase_backend = resolved_backend))
      )
    }
  )
}

.rgl_require_executable <- function(path, operation) {
  .rgl_assert_absolute_path(path, "executable")
  if (!file.exists(path) || dir.exists(path) || file.access(path, 1L) != 0L) {
    return(rglimpse2_error_value(
      message = paste0("executable is unavailable: ", path),
      kind = "input",
      code = "executable_unavailable",
      details = list(path = path, operation = operation)
    ))
  }
  invisible(TRUE)
}
