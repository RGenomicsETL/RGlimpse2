if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for haplotype sample ligation validation")
}
if (grepl("wasm|emscripten", R.version$platform, ignore.case = TRUE)) {
  exit_file("GLIMPSE2 child processes are unavailable on WebAssembly")
}

local({
  root <- tempfile("rglimpse2-ligate-samples-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  write_chunk <- function(path, positions, reversed, nmain = 15L, samples = TRUE) {
    writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
    writer$addContig("1")
    # Distinct input header dictionaries exercise records unique to reader 1.
    if (reversed) writer$addINFO("EXTRA", "1", "Integer", "Unused header entry")
    writer$addFORMAT("GT", "1", "String", "GT")
    if (samples) {
      writer$addLine(paste0("##NMAIN=", nmain))
      writer$addFORMAT("HS", "1", "Integer", "Packed allele draws")
      writer$addINFO("HSC", "1", "String", "Chunk-local draw scope")
    }
    writer$addSample("diploid")
    writer$addSample("haploid")
    scope <- if (reversed) "1:400-900:400-900" else "1:100-600:100-600"
    for (position in positions) {
      gt <- if (reversed) "1|0" else "0|1"
      hs <- if (reversed) "357913941" else "715827882"
      writer$writeline(paste(
        "1", position, ".", "A", "C", ".", "PASS",
        if (samples) paste0("HSC=", scope) else ".",
        if (samples) "GT:HS" else "GT",
        if (samples) paste(gt, hs, sep = ":") else gt,
        if (samples) "1:357913941" else "1",
        sep = "\t"
      ))
    }
    writer$close()
  }
  chunks <- file.path(root, c("one.bcf", "two.bcf"))
  write_chunk(chunks[1L], setdiff(seq(100L, 600L, 50L), 450L), FALSE)
  write_chunk(chunks[2L], seq(400L, 900L, 50L), TRUE)
  connection <- Rduckhts::rduckhts_connect()
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE), add = TRUE)
  for (chunk in chunks) {
    expect_true(Rduckhts::rduckhts_bcf_index(connection, chunk, threads = 1L)$success)
  }
  input_list <- file.path(root, "input.txt")
  writeLines(chunks, input_list)
  output <- file.path(root, "ligated.bcf")
  executable <- rglimpse2_executables(phase_backend = "scalar")@ligate
  result <- rglimpse2_ligate(input_list, output, executable, seed = 711L)
  expect_true(S7::S7_inherits(result, RGlimpse2RunResult))
  reader <- vcfppR::vcfreader$new(output)
  positions <- integer()
  scopes <- character()
  while (reader$variant()) {
    record <- strsplit(reader$line(), "\t", fixed = TRUE)[[1L]]
    positions <- c(positions, as.integer(record[2L]))
    scopes <- c(scopes, record[8L])
    expect_identical(record[10:11], c("0|1:715827882", "1:357913941"))
  }
  expect_identical(positions, seq(100L, 900L, 50L))
  expect_identical(scopes[positions == 450L], "HSC=1:400-900:400-900")
  expect_identical(scopes[1L], "HSC=1:100-600:100-600")
  expect_identical(tail(scopes, 1L), "HSC=1:400-900:400-900")

  for (kind in c("different-main", "absent-samples")) {
    incompatible <- file.path(root, paste0(kind, ".bcf"))
    write_chunk(incompatible, seq(400L, 900L, 50L), TRUE,
      nmain = 1L, samples = kind != "absent-samples"
    )
    expect_true(Rduckhts::rduckhts_bcf_index(connection, incompatible, threads = 1L)$success)
    writeLines(c(chunks[1L], incompatible), input_list)
    rejected <- rglimpse2_ligate(input_list, file.path(root, paste0(kind, "-out.bcf")), executable, seed = 712L)
    expect_true(rglimpse2_is_error(rejected))
    expected_message <- if (kind == "different-main") {
      "Cannot ligate HS chunks with different NMAIN draw counts"
    } else {
      "Cannot ligate chunks with and without HS samples"
    }
    expect_true(grepl(expected_message,
      paste(c(rejected@details$stdout, rejected@details$stderr), collapse = "\n"), fixed = TRUE
    ))
  }
})
