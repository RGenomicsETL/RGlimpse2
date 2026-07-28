if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for split-reference input validation")
}
if (identical(.Platform$OS.type, "windows")) {
  exit_file(
    "POSIX mock-executable tests run on Unix; Windows uses native split tests"
  )
}

local({
  root <- tempfile("rglimpse2-split-input-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  write_reference <- function(path, alternate, allele_count) {
    writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
    writer$addContig("chr1")
    writer$addINFO("AC", "A", "Integer", "Alternate allele count")
    writer$addINFO("AN", "1", "Integer", "Total allele count")
    writer$addFORMAT("GT", "1", "String", "Phased reference genotype")
    for (sample in paste0("R", seq_len(8L))) writer$addSample(sample)
    writer$writeline(paste(
      "chr1",
      100L,
      "test",
      "A",
      alternate,
      ".",
      "PASS",
      paste0("AC=", allele_count, ";AN=16"),
      "GT",
      paste(rep("0|1", 8L), collapse = "\t"),
      sep = "\t"
    ))
    writer$close()
  }

  multiallelic <- file.path(root, "multiallelic.bcf")
  symbolic <- file.path(root, "symbolic.bcf")
  write_reference(multiallelic, "C,G", "4,4")
  write_reference(symbolic, "<DEL>", "8")
  connection <- Rduckhts::rduckhts_connect()
  Rduckhts::rduckhts_bcf_index(connection, multiallelic, threads = 1L)
  Rduckhts::rduckhts_bcf_index(connection, symbolic, threads = 1L)
  DBI::dbDisconnect(connection, shutdown = TRUE)

  genetic_map <- file.path(root, "map.txt")
  writeLines(c("1 chr1 0", "200 chr1 0.01"), genetic_map)
  executable <- file.path(root, "mock-split")
  writeLines(
    c(
      "#!/bin/sh",
      "output=''",
      "region=''",
      "previous=''",
      "for argument in \"$@\"; do",
      "  case \"$previous\" in",
      "    --output) output=\"$argument\" ;;",
      "    --input-region) region=\"$argument\" ;;",
      "  esac",
      "  previous=\"$argument\"",
      "done",
      "token=$(printf '%s' \"$region\" | tr ':-' '__')",
      "printf 'complete\\n' > \"${output}_${token}.bin\"",
      "printf 'invoked\\n' > \"$0.invoked\""
    ),
    executable,
    useBytes = TRUE
  )
  Sys.chmod(executable, mode = "0755")

  rejected <- rglimpse2_split_reference(
    reference_bcf = multiallelic,
    input_region = "chr1:1-200",
    output_region = "chr1:50-150",
    output_prefix = file.path(root, "rejected"),
    executable = executable,
    genetic_map = genetic_map,
    seed = 1L
  )
  expect_true(S7::S7_inherits(rejected, RGlimpse2InputErrorValue))
  expect_identical(rejected@code, "non_biallelic_reference")
  expect_identical(rejected@details$invalid_count, 1)
  expect_identical(rejected@details$examples$alt, "C,G")
  expect_false(file.exists(paste0(executable, ".invoked")))
  expect_false(file.exists(file.path(root, "rejected_chr1_1_200.bin")))

  accepted <- rglimpse2_split_reference(
    reference_bcf = symbolic,
    input_region = "chr1:1-200",
    output_region = "chr1:50-150",
    output_prefix = file.path(root, "accepted"),
    executable = executable,
    genetic_map = genetic_map,
    seed = 2L
  )
  expect_true(S7::S7_inherits(accepted, RGlimpse2RunResult))
  expect_true(file.exists(paste0(executable, ".invoked")))
  expect_true(file.exists(file.path(root, "accepted_chr1_1_200.bin")))
})
