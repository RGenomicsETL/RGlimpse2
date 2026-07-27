#' Ligate ordered GLIMPSE2 chunk outputs
#'
#' Invokes `GLIMPSE2_ligate` once. The input list must contain exactly one
#' existing absolute VCF/BCF path per line in chromosome order. Blank lines and
#' surrounding whitespace are rejected because the native reader treats them
#' as part of a path.
#'
#' @param input_list Absolute text-file path containing ordered chunk paths.
#' @param output_bcf Absolute output `.bcf`, `.vcf`, or `.vcf.gz` path.
#' @param executable Absolute `GLIMPSE2_ligate` path.
#' @param seed Non-negative random seed.
#' @param threads Positive worker count.
#' @param log Empty or one absolute log output path.
#' @return `RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
#' @export
rglimpse2_ligate <- function(
  input_list,
  output_bcf,
  executable,
  seed,
  threads = 1L,
  log = character()
) {
  .rgl_contract_call(
    code = "invalid_ligate_request",
    details = list(api = "rglimpse2_ligate"),
    expression = {
      input_list <- .rgl_assert_absolute_path(input_list, "input_list")
      output_bcf <- .rgl_assert_absolute_path(output_bcf, "output_bcf")
      executable <- .rgl_assert_absolute_path(executable, "executable")
      .rgl_validate_optional_path(log, "log")
      if (!grepl("\\.(bcf|vcf|vcf\\.gz)$", output_bcf, ignore.case = TRUE)) {
        .rgl_signal_contract_violation(
          "output_bcf must end in .bcf, .vcf, or .vcf.gz",
          code = "unsupported_ligate_output"
        )
      }
      seed <- .rgl_assert_integer(seed, "seed", 0L, .Machine$integer.max)
      threads <- .rgl_assert_integer(threads, "threads", 1L, .Machine$integer.max)

      outputs <- c(list(output_bcf = output_bcf), if (length(log)) list(log = log))
      ready <- .rgl_preflight(
        "ligate",
        executable,
        inputs = list(input_list = input_list),
        outputs = outputs
      )
      if (rglimpse2_is_error(ready)) {
        return(ready)
      }

      chunks <- readLines(input_list, warn = FALSE, encoding = "UTF-8")
      malformed <- chunks[!nzchar(chunks) | chunks != trimws(chunks)]
      invalid <- chunks[
        !vapply(chunks, .rgl_is_absolute_path, logical(1L)) |
          vapply(chunks, .rgl_has_parent_traversal, logical(1L))
      ]
      missing <- chunks[!file.exists(chunks) | dir.exists(chunks)]
      if (
        !length(chunks) || length(malformed) || length(invalid) ||
          length(missing) || anyDuplicated(chunks)
      ) {
        return(rglimpse2_error_value(
          message = paste(
            "input_list must contain one unique existing absolute chunk path",
            "per line without blank lines or surrounding whitespace"
          ),
          kind = "input",
          code = "invalid_ligate_input_list",
          details = list(
            input_list = input_list,
            malformed = unique(malformed),
            invalid = unique(invalid),
            missing = unique(missing),
            duplicated = unique(chunks[duplicated(chunks)])
          )
        ))
      }

      arguments <- c(
        "--input", input_list,
        "--output", output_bcf,
        "--seed", as.character(seed),
        "--threads", as.character(threads),
        .rgl_optional_cli("--log", log)
      )
      .rgl_run_process("ligate", executable, arguments, outputs)
    }
  )
}
