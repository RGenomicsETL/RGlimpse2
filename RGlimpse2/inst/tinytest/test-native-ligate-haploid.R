if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for haploid ligation validation")
}

local({
  root <- tempfile("rglimpse2-native-haploid-ligate-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  samples <- paste0("S", seq_len(32L))
  write_chunk <- function(path, positions) {
    writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
    writer$addContig("Y")
    writer$addINFO("AC", "A", "Integer", "Alternate allele count")
    writer$addINFO("AN", "1", "Integer", "Total allele count")
    writer$addFORMAT("GT", "1", "String", "Phased haploid genotype")
    for (sample in samples) writer$addSample(sample)

    for (position in positions) {
      global_index <- (position - 100L) %/% 50L + 1L
      genotypes <- as.character((seq_along(samples) + global_index) %% 2L)
      writer$writeline(paste(
        "Y",
        position,
        paste0("v", position),
        "A",
        "C",
        ".",
        "PASS",
        paste0("AC=", sum(as.integer(genotypes)), ";AN=", length(genotypes)),
        "GT",
        paste(genotypes, collapse = "\t"),
        sep = "\t"
      ))
    }
    writer$close()
  }

  chunks <- file.path(root, c("chunk-1.bcf", "chunk-2.bcf"))
  write_chunk(chunks[[1L]], seq(100L, 600L, 50L))
  write_chunk(chunks[[2L]], seq(400L, 900L, 50L))

  connection <- Rduckhts::rduckhts_connect()
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE), add = TRUE)
  for (chunk in chunks) {
    indexed <- Rduckhts::rduckhts_bcf_index(
      connection,
      chunk,
      threads = 1L
    )
    expect_true(indexed$success)
  }

  input_list <- file.path(root, "chunks.txt")
  writeLines(chunks, input_list, useBytes = TRUE)
  output <- file.path(root, "ligated.bcf")
  result <- rglimpse2_ligate(
    input_list = input_list,
    output_bcf = output,
    executable = rglimpse2_executables(phase_backend = "scalar")@ligate,
    seed = 917L
  )
  expect_true(S7::S7_inherits(result, RGlimpse2RunResult))
  expect_true(file.exists(paste0(output, ".csi")))

  reader <- vcfppR::vcfreader$new(output)
  expect_identical(reader$samples(), samples)
  records <- character()
  while (reader$variant()) records <- c(records, reader$line())
  expect_identical(length(records), 17L)

  fields <- strsplit(records, "\t", fixed = TRUE)
  positions <- vapply(fields, function(record) as.integer(record[[2L]]), integer(1L))
  expect_identical(positions, seq(100L, 900L, 50L))
  for (index in seq_along(fields)) {
    observed <- fields[[index]][-(seq_len(9L))]
    expected <- as.character((seq_along(samples) + index) %% 2L)
    expect_identical(observed, expected, info = paste("position", positions[[index]]))
  }
})
