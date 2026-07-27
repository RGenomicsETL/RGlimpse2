#' Phase and impute one GLIMPSE2 chunk from genotype likelihoods
#'
#' Invokes `GLIMPSE2_phase` once against a binary reference chunk. RGlimpse2
#' currently requires one internal phase thread so a fixed seed is not coupled
#' to worker scheduling; parallelism belongs across independent chunks.
#'
#' @param input_gl Absolute VCF/BCF genotype-likelihood path.
#' @param reference_bin Absolute GLIMPSE2 binary reference path.
#' @param output_bcf Absolute `.bcf`, `.vcf`, or `.vcf.gz` output path.
#' @param executable Absolute selected `GLIMPSE2_phase` path.
#' @param seed Non-negative random seed.
#' @param threads Must be `1L` under the current deterministic contract.
#' @param sample_ploidy Empty or one absolute sample/ploidy table path.
#' @param input_field Genotype likelihood field, `"PL"` or `"GL"`.
#' @param burnin Number of burn-in iterations.
#' @param main Number of main iterations, at most 15.
#' @param ne Positive effective diploid population size.
#' @param pbwt_depth Positive PBWT neighbour depth.
#' @param pbwt_modulo_cm Positive PBWT selection spacing in cM.
#' @param k_init,k_pbwt Positive conditioning-state limits.
#' @param impute_reference_only_variants Whether to admit sporadically absent
#'   target likelihood records from the reference.
#' @param use_gl_indels Whether to consume input likelihoods at indels rather
#'   than use the default flat-likelihood scaffold behavior.
#' @param log Empty or one absolute log output path.
#' @return `RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
#' @export
rglimpse2_phase <- function(
  input_gl,
  reference_bin,
  output_bcf,
  executable,
  seed,
  threads = 1L,
  sample_ploidy = character(),
  input_field = c("PL", "GL"),
  burnin = 5L,
  main = 15L,
  ne = 100000L,
  pbwt_depth = 12L,
  pbwt_modulo_cm = 0.1,
  k_init = 1000L,
  k_pbwt = 2000L,
  impute_reference_only_variants = FALSE,
  use_gl_indels = FALSE,
  log = character()
) {
  .rgl_contract_call(
    code = "invalid_phase_request",
    details = list(api = "rglimpse2_phase"),
    expression = {
      input_gl <- .rgl_assert_absolute_path(input_gl, "input_gl")
      reference_bin <- .rgl_assert_absolute_path(reference_bin, "reference_bin")
      output_bcf <- .rgl_assert_absolute_path(output_bcf, "output_bcf")
      executable <- .rgl_assert_absolute_path(executable, "executable")
      .rgl_validate_optional_path(sample_ploidy, "sample_ploidy")
      .rgl_validate_optional_path(log, "log")
      if (!grepl("\\.(bcf|vcf|vcf\\.gz)$", output_bcf, ignore.case = TRUE)) {
        .rgl_signal_contract_violation(
          "output_bcf must end in .bcf, .vcf, or .vcf.gz",
          code = "unsupported_phase_output"
        )
      }
      seed <- .rgl_assert_integer(seed, "seed", 0L, .Machine$integer.max)
      threads <- .rgl_assert_integer(threads, "threads", 1L, .Machine$integer.max)
      if (threads != 1L) {
        .rgl_signal_contract_violation(
          "threads must be 1 until multithreaded phase reproducibility is validated",
          code = "phase_threads_must_be_one",
          details = list(threads = threads)
        )
      }
      input_field <- match.arg(input_field)
      burnin <- .rgl_assert_integer(burnin, "burnin", 0L, .Machine$integer.max)
      main <- .rgl_assert_integer(main, "main", 1L, 15L)
      ne <- .rgl_assert_integer(ne, "ne", 1L, .Machine$integer.max)
      pbwt_depth <- .rgl_assert_integer(
        pbwt_depth,
        "pbwt_depth",
        1L,
        .Machine$integer.max
      )
      pbwt_modulo_cm <- .rgl_assert_number(
        pbwt_modulo_cm,
        "pbwt_modulo_cm",
        0,
        minimum_open = TRUE
      )
      k_init <- .rgl_assert_integer(k_init, "k_init", 1L, .Machine$integer.max)
      k_pbwt <- .rgl_assert_integer(k_pbwt, "k_pbwt", 1L, .Machine$integer.max)
      impute_reference_only_variants <- .rgl_assert_flag(
        impute_reference_only_variants,
        "impute_reference_only_variants"
      )
      use_gl_indels <- .rgl_assert_flag(use_gl_indels, "use_gl_indels")

      inputs <- list(input_gl = input_gl, reference_bin = reference_bin)
      if (length(sample_ploidy)) inputs$sample_ploidy <- sample_ploidy
      outputs <- c(list(output_bcf = output_bcf), if (length(log)) list(log = log))
      ready <- .rgl_preflight(
        "phase",
        executable,
        inputs = inputs,
        outputs = outputs
      )
      if (rglimpse2_is_error(ready)) return(ready)

      arguments <- c(
        "--input-gl", input_gl,
        "--reference", reference_bin,
        "--output", output_bcf,
        "--seed", as.character(seed),
        "--threads", "1",
        "--burnin", as.character(burnin),
        "--main", as.character(main),
        "--ne", as.character(ne),
        "--pbwt-depth", as.character(pbwt_depth),
        "--pbwt-modulo-cm", .rgl_cli_number(pbwt_modulo_cm),
        "--Kinit", as.character(k_init),
        "--Kpbwt", as.character(k_pbwt),
        .rgl_optional_cli("--samples-file", sample_ploidy),
        if (identical(input_field, "GL")) "--input-field-gl",
        if (impute_reference_only_variants) "--impute-reference-only-variants",
        if (use_gl_indels) "--use-gl-indels",
        .rgl_optional_cli("--log", log)
      )
      .rgl_run_process("phase", executable, arguments, outputs)
    }
  )
}
