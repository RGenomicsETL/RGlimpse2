local({
  root <- tempfile("rglimpse2-phase-bams-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  haploid_bam <- file.path(root, "haploid.bam")
  haploid_index <- paste0(haploid_bam, ".bai")
  diploid_cram <- file.path(root, "diploid.cram")
  diploid_index <- paste0(diploid_cram, ".crai")
  reference_bin <- file.path(root, "reference.bin")
  reference_fasta <- file.path(root, "reference.fa")
  reference_fasta_index <- paste0(reference_fasta, ".fai")
  file.create(
    haploid_bam,
    haploid_index,
    diploid_cram,
    diploid_index,
    reference_bin,
    reference_fasta,
    reference_fasta_index
  )
  alignments <- data.frame(
    input_bam = c(haploid_bam, diploid_cram),
    input_index = c(haploid_index, diploid_index),
    sample_name = c("sample-haploid", "sample-diploid"),
    sample_ploidy = c(1L, 2L),
    stringsAsFactors = FALSE
  )

  executable <- file.path(root, "mock-phase")
  writeLines(
    c(
      "#!/bin/sh",
      "output=''",
      "log=''",
      "bam_list=''",
      "samples_file=''",
      "previous=''",
      "for argument in \"$@\"; do",
      "  case \"$previous\" in",
      "    --output) output=\"$argument\" ;;",
      "    --log) log=\"$argument\" ;;",
      "    --bam-list) bam_list=\"$argument\" ;;",
      "    --samples-file) samples_file=\"$argument\" ;;",
      "  esac",
      "  previous=\"$argument\"",
      "done",
      "[ -n \"$output\" ] || exit 8",
      "[ -f \"$bam_list\" ] || exit 9",
      "[ -f \"$samples_file\" ] || exit 10",
      "printf '%s\\n' \"$@\" > \"$output\"",
      "while IFS= read -r line; do",
      "  printf 'bam-list-content=%s\\n' \"$line\" >> \"$output\"",
      "done < \"$bam_list\"",
      "while IFS= read -r line; do",
      "  printf 'samples-file-content=%s\\n' \"$line\" >> \"$output\"",
      "done < \"$samples_file\"",
      "if [ -n \"$log\" ]; then",
      "  printf 'mock phase log\\n' > \"$log\"",
      "fi"
    ),
    executable,
    useBytes = TRUE
  )
  Sys.chmod(executable, mode = "0755")

  output_bcf <- file.path(root, "cohort output.bcf")
  log <- file.path(root, "cohort output.log")
  result <- rglimpse2_phase_bams(
    alignments = alignments,
    reference_bin = reference_bin,
    output_bcf = output_bcf,
    executable = executable,
    seed = 20260728L,
    reference_fasta = reference_fasta,
    reference_fasta_index = reference_fasta_index,
    mapq = 17L,
    baseq = 23L,
    max_depth = 61L,
    call_indels = TRUE,
    keep_orphan_reads = TRUE,
    ignore_orientation = TRUE,
    check_proper_pairing = TRUE,
    keep_failed_qc = TRUE,
    keep_duplicates = TRUE,
    burnin = 2L,
    main = 3L,
    ne = 120000L,
    pbwt_depth = 8L,
    pbwt_modulo_cm = 0.25,
    k_init = 64L,
    k_pbwt = 96L,
    log = log
  )
  expect_true(S7::S7_inherits(result, RGlimpse2RunResult))
  expect_identical(result@operation, "phase_bams")
  expect_identical(
    result@outputs,
    list(output_bcf = output_bcf, log = log)
  )

  arguments <- readLines(output_bcf, warn = FALSE, encoding = "UTF-8")
  argument_value <- function(flag) {
    position <- match(flag, arguments)
    if (is.na(position) || position == length(arguments)) return(NA_character_)
    arguments[[position + 1L]]
  }
  expect_false("--bam-file" %in% arguments)
  expect_false("--input-gl" %in% arguments)
  expect_false("--ind-name" %in% arguments)
  expect_identical(argument_value("--reference"), reference_bin)
  expect_identical(argument_value("--seed"), "20260728")
  expect_identical(argument_value("--threads"), "1")
  expect_identical(argument_value("--fasta"), reference_fasta)
  expect_identical(argument_value("--mapq"), "17")
  expect_identical(argument_value("--baseq"), "23")
  expect_identical(argument_value("--max-depth"), "61")
  expect_identical(argument_value("--burnin"), "2")
  expect_identical(argument_value("--main"), "3")
  expect_identical(argument_value("--ne"), "120000")
  expect_identical(argument_value("--pbwt-depth"), "8")
  expect_identical(argument_value("--pbwt-modulo-cm"), "0.25")
  expect_identical(argument_value("--Kinit"), "64")
  expect_identical(argument_value("--Kpbwt"), "96")
  expect_true(all(c(
    "--call-indels",
    "--keep-orphan-reads",
    "--ignore-orientation",
    "--check-proper-pairing",
    "--keep-failed-qc",
    "--keep-duplicates"
  ) %in% arguments))
  expect_true(paste0(
    "bam-list-content=",
    haploid_bam,
    "\tsample-haploid"
  ) %in% arguments)
  expect_true(paste0(
    "bam-list-content=",
    diploid_cram,
    "\tsample-diploid"
  ) %in% arguments)
  expect_true(
    "samples-file-content=sample-haploid\t1" %in% arguments
  )
  expect_true(
    "samples-file-content=sample-diploid\t2" %in% arguments
  )

  bam_list <- argument_value("--bam-list")
  samples_file <- argument_value("--samples-file")
  staged_bcf <- argument_value("--output")
  expect_false(file.exists(bam_list))
  expect_false(file.exists(samples_file))
  expect_false(file.exists(staged_bcf))
  expect_identical(
    normalizePath(dirname(staged_bcf), winslash = "/", mustWork = TRUE),
    normalizePath(dirname(output_bcf), winslash = "/", mustWork = TRUE)
  )
  expect_false(identical(staged_bcf, output_bcf))
  expect_true(grepl("\\.bcf$", staged_bcf))

  failing_executable <- file.path(root, "mock-phase-failure")
  writeLines(
    c(
      "#!/bin/sh",
      "output=''",
      "previous=''",
      "for argument in \"$@\"; do",
      "  if [ \"$previous\" = '--output' ]; then output=\"$argument\"; fi",
      "  previous=\"$argument\"",
      "done",
      "printf 'partial output\\n' > \"$output\"",
      "printf '%s\\n' \"$output\" > \"$0.stage-path\"",
      "exit 17"
    ),
    failing_executable,
    useBytes = TRUE
  )
  Sys.chmod(failing_executable, mode = "0755")
  failed_output <- file.path(root, "failed.bcf")
  failed <- rglimpse2_phase_bams(
    alignments = alignments,
    reference_bin = reference_bin,
    output_bcf = failed_output,
    executable = failing_executable,
    seed = 1L,
    reference_fasta = reference_fasta,
    reference_fasta_index = reference_fasta_index
  )
  expect_true(S7::S7_inherits(failed, RGlimpse2ProcessErrorValue))
  expect_identical(failed@status, 17L)
  failed_stage <- readLines(
    paste0(failing_executable, ".stage-path"),
    warn = FALSE
  )
  expect_false(file.exists(failed_output))
  expect_false(file.exists(failed_stage))

  racing_executable <- file.path(root, "mock-phase-race")
  racing_output <- paste0(racing_executable, ".final.bcf")
  writeLines(
    c(
      "#!/bin/sh",
      "output=''",
      "previous=''",
      "for argument in \"$@\"; do",
      "  if [ \"$previous\" = '--output' ]; then output=\"$argument\"; fi",
      "  previous=\"$argument\"",
      "done",
      "printf 'complete staged output\\n' > \"$output\"",
      "printf '%s\\n' \"$output\" > \"$0.stage-path\"",
      "printf 'concurrent output\\n' > \"$0.final.bcf\""
    ),
    racing_executable,
    useBytes = TRUE
  )
  Sys.chmod(racing_executable, mode = "0755")
  raced <- rglimpse2_phase_bams(
    alignments = alignments,
    reference_bin = reference_bin,
    output_bcf = racing_output,
    executable = racing_executable,
    seed = 2L,
    reference_fasta = reference_fasta,
    reference_fasta_index = reference_fasta_index
  )
  expect_true(S7::S7_inherits(raced, RGlimpse2OutputErrorValue))
  expect_identical(raced@code, "output_exists")
  expect_identical(
    readLines(racing_output, warn = FALSE),
    "concurrent output"
  )
  raced_stage <- readLines(
    paste0(racing_executable, ".stage-path"),
    warn = FALSE
  )
  expect_false(file.exists(raced_stage))

  invalid_ploidy <- alignments
  invalid_ploidy$sample_ploidy[[1L]] <- 3L
  invalid <- tryCatch(
    rglimpse2_phase_bams(
      alignments = invalid_ploidy,
      reference_bin = reference_bin,
      output_bcf = file.path(root, "invalid.bcf"),
      executable = executable,
      seed = 3L,
      reference_fasta = reference_fasta,
      reference_fasta_index = reference_fasta_index
    ),
    rglimpse2_contract_violation = identity
  )
  expect_identical(invalid$code, "invalid_sample_ploidy")

  missing_alignments <- data.frame(
    input_bam = file.path(root, "missing.bam"),
    input_index = file.path(root, "missing.bam.bai"),
    sample_name = "missing",
    sample_ploidy = 2L,
    stringsAsFactors = FALSE
  )
  missing <- rglimpse2_phase_bams(
    alignments = missing_alignments,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "missing.bcf"),
    executable = executable,
    seed = 4L
  )
  expect_true(S7::S7_inherits(missing, RGlimpse2InputErrorValue))
  expect_identical(missing@code, "input_file_missing")
})
