if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for symbolic direct-BAM validation")
}

local({
  data_root <- system.file(
    "tinytest",
    "tiny-symbolic-bam",
    package = "RGlimpse2"
  )
  expect_true(dir.exists(data_root))
  required <- file.path(data_root, c(
    "reference.bcf",
    "reference.bcf.csi",
    "genetic-map.txt",
    "symbolic-ref-read.bam",
    "symbolic-ref-read.bam.bai",
    "symbolic-alt-read.bam",
    "symbolic-alt-read.bam.bai"
  ))
  expect_true(all(file.exists(required)))

  root <- tempfile("rglimpse2-native-symbolic-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  executables <- rglimpse2_executables(phase_backend = "scalar")

  split <- rglimpse2_split_reference(
    reference_bcf = file.path(data_root, "reference.bcf"),
    input_region = "chr11:900-1600",
    output_region = "chr11:1000-1490",
    output_prefix = file.path(root, "reference"),
    executable = executables@split_reference,
    genetic_map = file.path(data_root, "genetic-map.txt"),
    seed = 8101L
  )
  expect_true(S7::S7_inherits(split, RGlimpse2RunResult))

  phase_alignment <- function(stem, output) {
    rglimpse2_phase_bam(
      input_bam = file.path(data_root, paste0(stem, ".bam")),
      input_index = file.path(data_root, paste0(stem, ".bam.bai")),
      reference_bin = split@outputs$reference_bin,
      output_bcf = output,
      executable = executables@phase,
      seed = 8102L,
      sample_name = "target",
      burnin = 1L,
      main = 1L,
      pbwt_depth = 2L,
      k_init = 4L,
      k_pbwt = 4L
    )
  }
  ref_output <- file.path(root, "ref-read.bcf")
  alt_output <- file.path(root, "alt-read.bcf")
  ref_run <- phase_alignment("symbolic-ref-read", ref_output)
  alt_run <- phase_alignment("symbolic-alt-read", alt_output)
  expect_true(S7::S7_inherits(ref_run, RGlimpse2RunResult))
  expect_true(S7::S7_inherits(alt_run, RGlimpse2RunResult))

  read_records <- function(path) {
    reader <- vcfppR::vcfreader$new(path)
    records <- character()
    while (reader$variant()) records <- c(records, reader$line())
    records
  }
  ref_records <- read_records(ref_output)
  alt_records <- read_records(alt_output)
  expect_identical(length(ref_records), 50L)
  expect_identical(length(alt_records), 50L)
  ref_symbolic <- ref_records[grepl(
    "^chr11\\t1240\\tsymbolic\\tA\\t<DEL>\\t",
    ref_records
  )]
  alt_symbolic <- alt_records[grepl(
    "^chr11\\t1240\\tsymbolic\\tA\\t<DEL>\\t",
    alt_records
  )]
  expect_identical(length(ref_symbolic), 1L)
  expect_identical(length(alt_symbolic), 1L)
  expect_identical(ref_symbolic, alt_symbolic)
})
