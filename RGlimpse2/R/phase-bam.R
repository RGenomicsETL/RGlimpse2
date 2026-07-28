#' Phase and impute one GLIMPSE2 chunk directly from one BAM or CRAM
#'
#' Invokes `GLIMPSE2_phase` once against a binary reference chunk and one
#' coordinate-sorted, indexed alignment. The alignment index is an explicit
#' input and must use a filename that HTSlib's `sam_index_load()` will discover
#' beside the alignment. RGlimpse2 fixes the internal phase thread count at one
#' so a supplied seed is not coupled to worker scheduling; callers should
#' parallelize independent chunks.
#'
#' @param input_bam Absolute `.bam` or `.cram` alignment path.
#' @param input_index Absolute BAM/CRAM index path. BAM accepts adjacent `.bai`
#'   or `.csi` naming; CRAM accepts adjacent `.crai` naming.
#' @param reference_bin Absolute GLIMPSE2 binary reference path.
#' @param output_bcf Absolute `.bcf` output path.
#' @param executable Absolute selected `GLIMPSE2_phase` path.
#' @param seed Non-negative random seed.
#' @param sample_name Empty or one output sample name. When omitted, GLIMPSE2
#'   derives the name from the alignment filename.
#' @param sample_ploidy Empty or one integer, `1L` or `2L`. If supplied without
#'   `sample_name`, the alignment filename stem is used for the temporary
#'   sample/ploidy table passed to GLIMPSE2.
#' @param reference_fasta Empty or one absolute faidx-indexed reference FASTA.
#'   Required for CRAM input.
#' @param reference_fasta_index Empty or one absolute FASTA index path.
#'   Required with `reference_fasta` and must be `paste0(reference_fasta,
#'   ".fai")`, which is the path HTSlib will discover.
#' @param mapq Minimum read mapping quality.
#' @param baseq Minimum base quality.
#' @param max_depth Maximum reads retained at one site before downsampling.
#' @param call_indels Whether to compute genotype likelihoods at reference
#'   indels. The default leaves indel likelihoods flat while retaining the
#'   reference haplotype scaffold.
#' @param keep_orphan_reads Whether to keep paired reads whose mate is unmapped.
#' @param ignore_orientation Whether to ignore mate-pair orientation.
#' @param check_proper_pairing Whether to discard reads not marked as properly
#'   paired.
#' @param keep_failed_qc Whether to keep reads marked as failed sequencing QC.
#' @param keep_duplicates Whether to keep reads marked as duplicates.
#' @param burnin Number of burn-in iterations.
#' @param main Number of main iterations, at most 15.
#' @param ne Positive effective diploid population size.
#' @param pbwt_depth Positive PBWT neighbour depth.
#' @param pbwt_modulo_cm Positive PBWT selection spacing in cM.
#' @param k_init,k_pbwt Positive conditioning-state limits.
#' @param log Empty or one absolute log output path.
#' @return `RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
#' @export
rglimpse2_phase_bam <- function(
  input_bam,
  input_index,
  reference_bin,
  output_bcf,
  executable,
  seed,
  sample_name = character(),
  sample_ploidy = integer(),
  reference_fasta = character(),
  reference_fasta_index = character(),
  mapq = 10L,
  baseq = 10L,
  max_depth = 40L,
  call_indels = FALSE,
  keep_orphan_reads = FALSE,
  ignore_orientation = FALSE,
  check_proper_pairing = FALSE,
  keep_failed_qc = FALSE,
  keep_duplicates = FALSE,
  burnin = 5L,
  main = 15L,
  ne = 100000L,
  pbwt_depth = 12L,
  pbwt_modulo_cm = 0.1,
  k_init = 1000L,
  k_pbwt = 2000L,
  log = character()
) {
  .rgl_contract_call(
    code = "invalid_phase_bam_request",
    details = list(api = "rglimpse2_phase_bam"),
    expression = {
      input_bam <- .rgl_assert_absolute_path(input_bam, "input_bam")
      input_index <- .rgl_assert_absolute_path(input_index, "input_index")
      reference_bin <- .rgl_assert_absolute_path(reference_bin, "reference_bin")
      output_bcf <- .rgl_assert_absolute_path(output_bcf, "output_bcf")
      executable <- .rgl_assert_absolute_path(executable, "executable")
      .rgl_validate_optional_string(sample_name, "sample_name")
      .rgl_validate_optional_path(reference_fasta, "reference_fasta")
      .rgl_validate_optional_path(
        reference_fasta_index,
        "reference_fasta_index"
      )
      .rgl_validate_optional_path(log, "log")

      alignment_format <- .rgl_alignment_format(input_bam)
      .rgl_validate_discoverable_alignment_index(
        input_bam,
        input_index,
        alignment_format
      )
      .rgl_validate_alignment_reference(
        alignment_format,
        reference_fasta,
        reference_fasta_index
      )
      if (!grepl("\\.bcf$", output_bcf, ignore.case = TRUE)) {
        .rgl_signal_contract_violation(
          "output_bcf must end in .bcf",
          code = "unsupported_phase_bam_output"
        )
      }

      seed <- .rgl_assert_integer(seed, "seed", 0L, .Machine$integer.max)
      if (
        !is.numeric(sample_ploidy) ||
          length(sample_ploidy) > 1L ||
          anyNA(sample_ploidy) ||
          (length(sample_ploidy) && (
            !is.finite(sample_ploidy) ||
              sample_ploidy != floor(sample_ploidy) ||
              !sample_ploidy %in% c(1, 2)
          ))
      ) {
        .rgl_signal_contract_violation(
          "sample_ploidy must be empty, 1L, or 2L",
          code = "invalid_sample_ploidy",
          details = list(sample_ploidy = sample_ploidy)
        )
      }
      if (length(sample_ploidy)) sample_ploidy <- as.integer(sample_ploidy)
      resolved_sample_name <- if (length(sample_name)) {
        sample_name
      } else {
        tools::file_path_sans_ext(basename(input_bam))
      }
      if (grepl("[[:space:]]", resolved_sample_name)) {
        .rgl_signal_contract_violation(
          paste0(
            "sample_name must contain no whitespace; supply it explicitly ",
            "when the alignment filename stem contains whitespace"
          ),
          code = "invalid_sample_name",
          details = list(sample_name = resolved_sample_name)
        )
      }
      mapq <- .rgl_assert_integer(mapq, "mapq", 0L, 255L)
      baseq <- .rgl_assert_integer(baseq, "baseq", 0L, 255L)
      max_depth <- .rgl_assert_integer(
        max_depth,
        "max_depth",
        1L,
        .Machine$integer.max
      )
      call_indels <- .rgl_assert_flag(call_indels, "call_indels")
      keep_orphan_reads <- .rgl_assert_flag(
        keep_orphan_reads,
        "keep_orphan_reads"
      )
      ignore_orientation <- .rgl_assert_flag(
        ignore_orientation,
        "ignore_orientation"
      )
      check_proper_pairing <- .rgl_assert_flag(
        check_proper_pairing,
        "check_proper_pairing"
      )
      keep_failed_qc <- .rgl_assert_flag(keep_failed_qc, "keep_failed_qc")
      keep_duplicates <- .rgl_assert_flag(keep_duplicates, "keep_duplicates")
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

      inputs <- list(
        input_bam = input_bam,
        input_index = input_index,
        reference_bin = reference_bin
      )
      if (length(reference_fasta)) {
        inputs$reference_fasta <- reference_fasta
        inputs$reference_fasta_index <- reference_fasta_index
      }
      outputs <- c(list(output_bcf = output_bcf), if (length(log)) list(log = log))
      ready <- .rgl_preflight(
        "phase_bam",
        executable,
        inputs = inputs,
        outputs = outputs
      )
      if (rglimpse2_is_error(ready)) return(ready)

      sample_ploidy_path <- character()
      if (length(sample_ploidy)) {
        sample_ploidy_path <- tempfile("rglimpse2-sample-ploidy-", fileext = ".txt")
        writeLines(
          paste(resolved_sample_name, sample_ploidy),
          sample_ploidy_path,
          useBytes = TRUE
        )
        on.exit(unlink(sample_ploidy_path, force = TRUE), add = TRUE)
      }

      arguments <- c(
        "--bam-file", input_bam,
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
        "--mapq", as.character(mapq),
        "--baseq", as.character(baseq),
        "--max-depth", as.character(max_depth),
        .rgl_optional_cli("--ind-name", sample_name),
        .rgl_optional_cli("--samples-file", sample_ploidy_path),
        .rgl_optional_cli("--fasta", reference_fasta),
        if (call_indels) "--call-indels",
        if (keep_orphan_reads) "--keep-orphan-reads",
        if (ignore_orientation) "--ignore-orientation",
        if (check_proper_pairing) "--check-proper-pairing",
        if (keep_failed_qc) "--keep-failed-qc",
        if (keep_duplicates) "--keep-duplicates",
        .rgl_optional_cli("--log", log)
      )
      .rgl_run_process("phase_bam", executable, arguments, outputs)
    }
  )
}
