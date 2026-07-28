local({
  root <- tempfile("rglimpse2-phase-bam;literal ")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  input_bam <- file.path(root, "one sample.bam")
  input_index <- paste0(input_bam, ".bai")
  reference_bin <- file.path(root, "reference chunk.bin")
  file.create(input_bam, input_index, reference_bin)

  executable <- file.path(root, "mock phase")
  writeLines(
    c(
      "#!/bin/sh",
      "output=''",
      "log=''",
      "samples=''",
      "previous=''",
      "for argument in \"$@\"; do",
      "  case \"$previous\" in",
      "    --output) output=\"$argument\" ;;",
      "    --log) log=\"$argument\" ;;",
      "    --samples-file) samples=\"$argument\" ;;",
      "  esac",
      "  previous=\"$argument\"",
      "done",
      "[ -n \"$output\" ] || exit 8",
      "printf '%s\\n' \"$@\" > \"$output\"",
      "if [ -n \"$samples\" ]; then",
      "  while IFS= read -r line; do",
      "    printf 'samples-file-content=%s\\n' \"$line\" >> \"$output\"",
      "  done < \"$samples\"",
      "fi",
      "if [ -n \"$log\" ]; then",
      "  printf 'mock phase log\\n' > \"$log\"",
      "fi"
    ),
    executable,
    useBytes = TRUE
  )
  Sys.chmod(executable, mode = "0755")

  output_bcf <- file.path(root, "direct output.bcf")
  log <- file.path(root, "direct output.log")
  result <- rglimpse2_phase_bam(
    input_bam = input_bam,
    input_index = input_index,
    reference_bin = reference_bin,
    output_bcf = output_bcf,
    executable = executable,
    seed = 20260728L,
    sample_name = "sample-A",
    sample_ploidy = 1L,
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
  expect_identical(result@operation, "phase_bam")
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
  expect_identical(argument_value("--bam-file"), input_bam)
  expect_identical(argument_value("--reference"), reference_bin)
  expect_identical(argument_value("--output"), output_bcf)
  expect_identical(argument_value("--seed"), "20260728")
  expect_identical(argument_value("--threads"), "1")
  expect_identical(argument_value("--ind-name"), "sample-A")
  expect_identical(argument_value("--mapq"), "17")
  expect_identical(argument_value("--baseq"), "23")
  expect_identical(argument_value("--max-depth"), "61")
  expect_true(all(c(
    "--call-indels",
    "--keep-orphan-reads",
    "--ignore-orientation",
    "--check-proper-pairing",
    "--keep-failed-qc",
    "--keep-duplicates"
  ) %in% arguments))
  expect_true("samples-file-content=sample-A 1" %in% arguments)
  sample_file <- argument_value("--samples-file")
  expect_true(nzchar(sample_file))
  expect_false(file.exists(sample_file))

  capture_contract <- function(expression) {
    tryCatch(
      force(expression),
      rglimpse2_contract_violation = identity
    )
  }

  unsupported_output <- capture_contract(rglimpse2_phase_bam(
    input_bam = input_bam,
    input_index = input_index,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "unsupported.vcf.gz"),
    executable = executable,
    seed = 1L
  ))
  expect_identical(
    unsupported_output$code,
    "unsupported_phase_bam_output"
  )

  wrong_index <- capture_contract(rglimpse2_phase_bam(
    input_bam = input_bam,
    input_index = file.path(root, "somewhere-else.bai"),
    reference_bin = reference_bin,
    output_bcf = file.path(root, "wrong-index.bcf"),
    executable = executable,
    seed = 1L
  ))
  expect_identical(wrong_index$code, "undiscoverable_alignment_index")

  alternate_index <- sub("\\.bam$", ".bai", input_bam)
  file.create(alternate_index)
  ambiguous_indexes <- capture_contract(rglimpse2_phase_bam(
    input_bam = input_bam,
    input_index = input_index,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "ambiguous-index.bcf"),
    executable = executable,
    seed = 1L
  ))
  expect_identical(ambiguous_indexes$code, "ambiguous_alignment_indexes")
  unlink(alternate_index)

  missing_sample_name <- capture_contract(rglimpse2_phase_bam(
    input_bam = input_bam,
    input_index = input_index,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "missing-sample-name.bcf"),
    executable = executable,
    seed = 1L
  ))
  expect_identical(missing_sample_name$code, "invalid_sample_name")

  invalid_ploidy <- capture_contract(rglimpse2_phase_bam(
    input_bam = input_bam,
    input_index = input_index,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "bad-ploidy.bcf"),
    executable = executable,
    seed = 1L,
    sample_name = "sample-A",
    sample_ploidy = 3L
  ))
  expect_identical(invalid_ploidy$code, "invalid_sample_ploidy")

  input_cram <- file.path(root, "sample.cram")
  input_crai <- paste0(input_cram, ".crai")
  file.create(input_cram, input_crai)
  missing_cram_reference <- capture_contract(rglimpse2_phase_bam(
    input_bam = input_cram,
    input_index = input_crai,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "cram.bcf"),
    executable = executable,
    seed = 1L
  ))
  expect_identical(missing_cram_reference$code, "cram_reference_required")

  reference_fasta <- file.path(root, "reference.fa")
  reference_fasta_index <- paste0(reference_fasta, ".fai")
  file.create(reference_fasta, reference_fasta_index)
  cram_output <- file.path(root, "cram-direct.bcf")
  cram_result <- rglimpse2_phase_bam(
    input_bam = input_cram,
    input_index = input_crai,
    reference_bin = reference_bin,
    output_bcf = cram_output,
    executable = executable,
    seed = 4L,
    reference_fasta = reference_fasta,
    reference_fasta_index = reference_fasta_index
  )
  expect_true(S7::S7_inherits(cram_result, RGlimpse2RunResult))
  cram_arguments <- readLines(cram_output, warn = FALSE, encoding = "UTF-8")
  fasta_position <- match("--fasta", cram_arguments)
  expect_identical(cram_arguments[[fasta_position + 1L]], reference_fasta)
})
