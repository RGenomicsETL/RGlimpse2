#' Phase and impute one GLIMPSE2 chunk directly from several BAMs or CRAMs
#'
#' Invokes `GLIMPSE2_phase` once with its native `--bam-list` input. Genotype
#' likelihoods are computed from every alignment inside that process; no
#' intermediate likelihood VCF or BCF is written. The BAM list and the complete
#' sample/ploidy file are private temporary inputs removed before this function
#' returns.
#'
#' RGlimpse2 fixes the internal phase thread count at one so a supplied seed is
#' not coupled to worker scheduling. The final BCF is published without
#' replacing an existing path only after the child process succeeds.
#'
#' @param alignments A non-empty data frame with one row per sample and columns:
#'   `input_bam` (character absolute `.bam` or `.cram` path), `input_index`
#'   (character absolute adjacent index path), `sample_name` (character unique
#'   sample name without whitespace), and `sample_ploidy` (numeric integer value
#'   `1` or `2`). Alignment paths cannot contain whitespace because
#'   `GLIMPSE2_phase --bam-list` uses a whitespace-delimited native format.
#' @param reference_bin Absolute GLIMPSE2 binary reference path.
#' @param output_bcf Absolute `.bcf` output path.
#' @param executable Absolute selected `GLIMPSE2_phase` path.
#' @param seed Non-negative random seed.
#' @param reference_fasta Empty or one absolute faidx-indexed reference FASTA.
#'   Required when any row in `alignments` is a CRAM.
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
rglimpse2_phase_bams <- function(
  alignments,
  reference_bin,
  output_bcf,
  executable,
  seed,
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
    code = "invalid_phase_bams_request",
    details = list(api = "rglimpse2_phase_bams"),
    expression = {
      required_columns <- c(
        "input_bam",
        "input_index",
        "sample_name",
        "sample_ploidy"
      )
      valid_column_names <- is.data.frame(alignments) &&
        all(vapply(
          required_columns,
          function(column) sum(names(alignments) == column) == 1L,
          logical(1L)
        ))
      if (!valid_column_names || nrow(alignments) < 1L) {
        .rgl_signal_contract_violation(
          paste0(
            "alignments must be a non-empty data frame with one each of: ",
            paste(required_columns, collapse = ", ")
          ),
          code = "invalid_alignment_table",
          details = list(required_columns = required_columns)
        )
      }

      row_count <- nrow(alignments)
      input_bam <- alignments[["input_bam"]]
      input_index <- alignments[["input_index"]]
      sample_name <- alignments[["sample_name"]]
      sample_ploidy <- alignments[["sample_ploidy"]]
      character_columns <- list(
        input_bam = input_bam,
        input_index = input_index,
        sample_name = sample_name
      )
      invalid_character_columns <- names(character_columns)[
        !vapply(
          character_columns,
          function(column) {
            is.character(column) &&
              is.null(dim(column)) &&
              length(column) == row_count &&
              !anyNA(column) &&
              all(nzchar(column))
          },
          logical(1L)
        )
      ]
      if (length(invalid_character_columns)) {
        .rgl_signal_contract_violation(
          paste0(
            "alignment character columns contain invalid values: ",
            paste(invalid_character_columns, collapse = ", ")
          ),
          code = "invalid_alignment_table_columns",
          details = list(columns = invalid_character_columns)
        )
      }
      valid_ploidy <- is.numeric(sample_ploidy) &&
        is.null(dim(sample_ploidy)) &&
        length(sample_ploidy) == row_count &&
        !anyNA(sample_ploidy) &&
        all(is.finite(sample_ploidy)) &&
        all(sample_ploidy == floor(sample_ploidy)) &&
        all(sample_ploidy %in% c(1, 2))
      if (!valid_ploidy) {
        .rgl_signal_contract_violation(
          "alignments$sample_ploidy must contain only integer values 1 or 2",
          code = "invalid_sample_ploidy",
          details = list(sample_ploidy = sample_ploidy)
        )
      }
      sample_ploidy <- as.integer(sample_ploidy)
      if (any(grepl("[[:space:]]", input_bam))) {
        .rgl_signal_contract_violation(
          "alignments$input_bam cannot contain whitespace",
          code = "alignment_path_contains_whitespace"
        )
      }
      if (any(grepl("[[:space:]]", sample_name))) {
        .rgl_signal_contract_violation(
          "alignments$sample_name must contain no whitespace",
          code = "invalid_sample_name"
        )
      }
      if (anyDuplicated(sample_name)) {
        .rgl_signal_contract_violation(
          "alignments$sample_name must be unique",
          code = "duplicate_sample_names",
          details = list(
            sample_names = unique(sample_name[duplicated(sample_name)])
          )
        )
      }

      reference_bin <- .rgl_assert_absolute_path(reference_bin, "reference_bin")
      output_bcf <- .rgl_assert_absolute_path(output_bcf, "output_bcf")
      executable <- .rgl_assert_absolute_path(executable, "executable")
      .rgl_validate_optional_path(reference_fasta, "reference_fasta")
      .rgl_validate_optional_path(
        reference_fasta_index,
        "reference_fasta_index"
      )
      .rgl_validate_optional_path(log, "log")
      if (!grepl("\\.bcf$", output_bcf, ignore.case = TRUE)) {
        .rgl_signal_contract_violation(
          "output_bcf must end in .bcf",
          code = "unsupported_phase_bams_output"
        )
      }

      formats <- character(row_count)
      for (row in seq_len(row_count)) {
        input_bam[[row]] <- .rgl_assert_absolute_path(
          input_bam[[row]],
          paste0("alignments$input_bam[", row, "]")
        )
        input_index[[row]] <- .rgl_assert_absolute_path(
          input_index[[row]],
          paste0("alignments$input_index[", row, "]")
        )
        formats[[row]] <- .rgl_alignment_format(input_bam[[row]])
        .rgl_validate_discoverable_alignment_index(
          input_bam[[row]],
          input_index[[row]],
          formats[[row]]
        )
      }
      input_bam_keys <- vapply(input_bam, .rgl_path_key, character(1L))
      if (anyDuplicated(input_bam_keys)) {
        .rgl_signal_contract_violation(
          "alignments$input_bam must be unique",
          code = "duplicate_alignment_paths",
          details = list(
            rows = which(
              duplicated(input_bam_keys) |
                duplicated(input_bam_keys, fromLast = TRUE)
            )
          )
        )
      }
      .rgl_validate_alignment_reference(
        if (any(formats == "cram")) "cram" else "bam",
        reference_fasta,
        reference_fasta_index
      )

      seed <- .rgl_assert_integer(seed, "seed", 0L, .Machine$integer.max)
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

      inputs <- list(reference_bin = reference_bin)
      for (row in seq_len(row_count)) {
        inputs[[paste0("input_bam_", row)]] <- input_bam[[row]]
        inputs[[paste0("input_index_", row)]] <- input_index[[row]]
      }
      if (length(reference_fasta)) {
        inputs$reference_fasta <- reference_fasta
        inputs$reference_fasta_index <- reference_fasta_index
      }
      outputs <- c(list(output_bcf = output_bcf), if (length(log)) list(log = log))
      ready <- .rgl_preflight(
        "phase_bams",
        executable,
        inputs = inputs,
        outputs = outputs
      )
      if (rglimpse2_is_error(ready)) return(ready)

      bam_list <- tempfile("rglimpse2-bam-list-", fileext = ".txt")
      samples_file <- tempfile("rglimpse2-samples-", fileext = ".txt")
      staged_bcf <- tempfile(
        ".rglimpse2-phase-bams-",
        tmpdir = dirname(output_bcf),
        fileext = ".bcf"
      )
      on.exit(
        unlink(c(bam_list, samples_file, staged_bcf), force = TRUE),
        add = TRUE
      )
      writeLines(
        paste(input_bam, sample_name, sep = "\t"),
        bam_list,
        useBytes = TRUE
      )
      writeLines(
        paste(sample_name, sample_ploidy, sep = "\t"),
        samples_file,
        useBytes = TRUE
      )

      arguments <- c(
        "--bam-list", bam_list,
        "--samples-file", samples_file,
        "--reference", reference_bin,
        "--output", staged_bcf,
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
        .rgl_optional_cli("--fasta", reference_fasta),
        if (call_indels) "--call-indels",
        if (keep_orphan_reads) "--keep-orphan-reads",
        if (ignore_orientation) "--ignore-orientation",
        if (check_proper_pairing) "--check-proper-pairing",
        if (keep_failed_qc) "--keep-failed-qc",
        if (keep_duplicates) "--keep-duplicates",
        .rgl_optional_cli("--log", log)
      )
      staged_outputs <- c(
        list(output_bcf = staged_bcf),
        if (length(log)) list(log = log)
      )
      run <- .rgl_run_process(
        "phase_bams",
        executable,
        arguments,
        staged_outputs
      )
      if (rglimpse2_is_error(run)) return(run)

      published <- suppressWarnings(file.link(staged_bcf, output_bcf))
      if (!isTRUE(published)) {
        occupied <- file.exists(output_bcf)
        return(rglimpse2_error_value(
          message = if (occupied) {
            paste0("output_bcf already exists: ", output_bcf)
          } else {
            paste0("could not publish output_bcf: ", output_bcf)
          },
          kind = "output",
          code = if (occupied) "output_exists" else "output_publish_failed",
          details = list(
            argument = "output_bcf",
            path = output_bcf
          )
        ))
      }
      unlink(staged_bcf, force = TRUE)

      RGlimpse2RunResult(
        operation = run@operation,
        outputs = outputs,
        status = run@status,
        stdout = run@stdout,
        stderr = run@stderr
      )
    }
  )
}
