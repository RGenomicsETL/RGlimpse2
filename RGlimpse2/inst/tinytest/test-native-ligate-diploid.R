if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for native diploid ligation validation")
}

local({
  root <- tempfile("rglimpse2-ligate-diploid-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  connection <- Rduckhts::rduckhts_connect()
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE), add = TRUE)
  write_chunk <- function(
    path,
    records,
    phase_sets = FALSE,
    extra_header = FALSE
  ) {
    writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
    writer$addContig("X")
    if (extra_header) {
      writer$addINFO("EXTRA", "1", "Integer", "Independent header dictionary")
    }
    writer$addINFO("ORIGIN", "1", "String", "Original biological scope")
    writer$addFORMAT("GT", "1", "String", "Genotype")
    writer$addFORMAT("GP", "G", "Float", "Unphased probabilities")
    writer$addFORMAT("DS", "A", "Float", "Alternate dosages")
    if (phase_sets) {
      writer$addFORMAT("PS", "1", "Integer", "Input phase set")
    }
    writer$addSample("maternal")
    writer$addSample("fetal")
    for (record in records) {
      writer$writeline(record)
    }
    writer$close()
    expect_true(Rduckhts::rduckhts_bcf_index(connection, path)$success)
  }
  record <- function(
    position,
    maternal,
    fetal = "0|1",
    alt = "C",
    scope = "left"
  ) {
    gp <- if (alt == "C") "0.1,0.8,0.1" else "0.01,0.02,0.03,0.04,0.85,0.05"
    ds <- if (alt == "C") "1" else "0.9,1.1"
    paste(
      "X",
      position,
      ".",
      "A",
      alt,
      ".",
      "PASS",
      paste0("ORIGIN=", scope),
      "GT:GP:DS",
      paste(maternal, gp, ds, sep = ":"),
      paste(fetal, gp, ds, sep = ":"),
      sep = "\t"
    )
  }
  chunks <- file.path(root, c("left.bcf", "right.bcf"))
  write_chunk(
    chunks[1L],
    vapply(c(100L, 200L, 300L, 400L), record, character(1L), maternal = "0|1")
  )
  right_records <- c(
    record(250L, "1|0", scope = "right"),
    record(300L, "1|0", scope = "right"),
    record(350L, "1|0", scope = "right"),
    record(400L, "1|0", scope = "right"),
    record(500L, "2|1", alt = "C,G", scope = "right"),
    record(600L, ".|1", fetal = "1", scope = "right")
  )
  write_chunk(chunks[2L], right_records, extra_header = TRUE)
  input_list <- file.path(root, "input.txt")
  writeLines(chunks, input_list)
  executable <- rglimpse2_executables(phase_backend = "scalar")@ligate
  output <- file.path(root, "joined.bcf")
  joined <- rglimpse2_ligate(input_list, output, executable, seed = 37L)
  expect_true(S7::S7_inherits(joined, RGlimpse2RunResult))
  Rduckhts::rduckhts_bcf(connection, "joined", output, tidy_format = TRUE)
  maternal <- DBI::dbGetQuery(
    connection,
    "SELECT * FROM joined WHERE SAMPLE_ID = 'maternal' ORDER BY POS"
  )
  fetal <- DBI::dbGetQuery(
    connection,
    "SELECT * FROM joined WHERE SAMPLE_ID = 'fetal' ORDER BY POS"
  )
  expect_equal(maternal$POS, c(100L, 200L, 250L, 300L, 350L, 400L, 500L, 600L))
  expect_identical(maternal$FORMAT_GT, c(rep("0|1", 6L), "1|2", ".|1"))
  expect_identical(fetal$FORMAT_GT, c(rep("0|1", 7L), "1"))
  expect_identical(
    maternal$INFO_LIGATE_CHUNK,
    c(1L, 1L, 2L, 1L, 2L, 2L, 2L, 2L)
  )
  expect_identical(
    maternal$FORMAT_LIGATE_FLIP,
    c(0L, 0L, 1L, 0L, 1L, 1L, 1L, 0L)
  )
  expect_identical(maternal$FORMAT_PS, c(rep(100L, 7L), NA_integer_))
  expect_identical(fetal$FORMAT_PS, c(rep(100L, 7L), NA_integer_))
  expect_identical(maternal$ALT[[7L]], c("C", "G"))
  expect_equal(
    maternal$FORMAT_GP[[7L]],
    c(0.01, 0.02, 0.03, 0.04, 0.85, 0.05),
    tolerance = 1e-7
  )
  expect_equal(maternal$FORMAT_DS[[7L]], c(0.9, 1.1), tolerance = 1e-7)
  expect_identical(
    maternal$INFO_ORIGIN,
    c("left", "left", "right", "left", rep("right", 4L))
  )

  tied <- file.path(root, "tied.bcf")
  right_records[2L] <- record(300L, "0|1", scope = "right")
  write_chunk(tied, right_records)
  writeLines(c(chunks[1L], tied), input_list)
  tied_output <- file.path(root, "tied-joined.bcf")
  expect_true(S7::S7_inherits(
    rglimpse2_ligate(input_list, tied_output, executable, seed = 37L),
    RGlimpse2RunResult
  ))
  Rduckhts::rduckhts_bcf(connection, "tied", tied_output, tidy_format = TRUE)
  boundary <- DBI::dbGetQuery(
    connection,
    "SELECT SAMPLE_ID, FORMAT_PS FROM tied WHERE POS = 500 ORDER BY SAMPLE_ID"
  )
  expect_identical(boundary$SAMPLE_ID, c("fetal", "maternal"))
  expect_identical(boundary$FORMAT_PS, c(100L, 250L))

  absent <- file.path(root, "absent.bcf")
  write_chunk(absent, c(record(250L, "1|0"), record(350L, "1|0")))
  writeLines(c(chunks[1L], absent), input_list)
  failed <- rglimpse2_ligate(
    input_list,
    file.path(root, "absent-joined.bcf"),
    executable,
    seed = 37L
  )
  expect_true(rglimpse2_is_error(failed))
  expect_identical(failed@code, "ligate_failed")

  categorical <- file.path(
    root,
    c("categorical-left.bcf", "categorical-right.bcf")
  )
  write_chunk(
    categorical[1L],
    c(
      record(100L, "1|2", alt = "C,G"),
      record(300L, "1|2", alt = "C,G"),
      record(400L, "1|2", alt = "C,G")
    )
  )
  write_chunk(
    categorical[2L],
    c(
      record(250L, "2|1", alt = "C,G"),
      record(300L, "2|1", alt = "C,G"),
      record(400L, "2|1", alt = "C,G"),
      record(500L, "2|1", alt = "C,G")
    )
  )
  writeLines(categorical, input_list)
  categorical_output <- file.path(root, "categorical-joined.bcf")
  expect_true(S7::S7_inherits(
    rglimpse2_ligate(input_list, categorical_output, executable, seed = 37L),
    RGlimpse2RunResult
  ))
  Rduckhts::rduckhts_bcf(
    connection,
    "categorical",
    categorical_output,
    tidy_format = TRUE
  )
  expect_identical(
    DBI::dbGetQuery(
      connection,
      "SELECT FORMAT_GT FROM categorical WHERE SAMPLE_ID = 'maternal' ORDER BY POS"
    )$FORMAT_GT,
    rep("1|2", 5L)
  )

  reordered <- file.path(root, "reordered.bcf")
  write_chunk(
    reordered,
    c(
      record(250L, "1|0"),
      record(300L, "2|1", alt = "G,C"),
      record(400L, "2|1", alt = "C,G"),
      record(500L, "2|1", alt = "C,G")
    )
  )
  writeLines(c(categorical[1L], reordered), input_list)
  reordered_output <- file.path(root, "reordered-joined.bcf")
  expect_true(S7::S7_inherits(
    rglimpse2_ligate(input_list, reordered_output, executable, seed = 37L),
    RGlimpse2RunResult
  ))
  Rduckhts::rduckhts_bcf(
    connection,
    "reordered",
    reordered_output,
    tidy_format = TRUE
  )
  allele_orders <- DBI::dbGetQuery(
    connection,
    "SELECT ALT FROM reordered WHERE POS = 300 AND SAMPLE_ID = 'maternal'"
  )$ALT
  expect_identical(allele_orders, list(c("C", "G"), c("G", "C")))

  uninformative <- file.path(root, "uninformative.bcf")
  write_chunk(
    uninformative,
    c(
      record(250L, "0|0", fetal = "0|0"),
      record(300L, "0|0", fetal = "0|0"),
      record(400L, "0|0", fetal = "0|0"),
      record(500L, "1|0")
    )
  )
  writeLines(c(chunks[1L], uninformative), input_list)
  uninformative_output <- file.path(root, "uninformative-joined.bcf")
  expect_true(S7::S7_inherits(
    rglimpse2_ligate(input_list, uninformative_output, executable, seed = 37L),
    RGlimpse2RunResult
  ))
  Rduckhts::rduckhts_bcf(
    connection,
    "uninformative",
    uninformative_output,
    tidy_format = TRUE
  )
  expect_identical(
    DBI::dbGetQuery(
      connection,
      "SELECT FORMAT_PS FROM uninformative WHERE POS = 500 ORDER BY SAMPLE_ID"
    )$FORMAT_PS,
    c(250L, 250L)
  )

  fetal_reversed <- file.path(root, "fetal-reversed.bcf")
  write_chunk(
    fetal_reversed,
    c(
      record(250L, "0|1", fetal = "1|0"),
      record(300L, "0|1", fetal = "1|0"),
      record(400L, "0|1", fetal = "1|0"),
      record(500L, "0|1", fetal = "1|0")
    )
  )
  writeLines(c(chunks[1L], fetal_reversed), input_list)
  fetal_reversed_output <- file.path(root, "fetal-reversed-joined.bcf")
  expect_true(S7::S7_inherits(
    rglimpse2_ligate(input_list, fetal_reversed_output, executable, seed = 37L),
    RGlimpse2RunResult
  ))
  Rduckhts::rduckhts_bcf(
    connection,
    "fetal_reversed",
    fetal_reversed_output,
    tidy_format = TRUE
  )
  orientations <- DBI::dbGetQuery(
    connection,
    "SELECT FORMAT_GT, FORMAT_LIGATE_FLIP FROM fetal_reversed WHERE POS = 500 ORDER BY SAMPLE_ID"
  )
  expect_identical(orientations$FORMAT_GT, c("0|1", "0|1"))
  expect_identical(orientations$FORMAT_LIGATE_FLIP, c(1L, 0L))

  gap <- file.path(root, "gap.bcf")
  write_chunk(gap, c(record(700L, "1|0"), record(800L, "1|0")))
  writeLines(c(chunks[1L], gap), input_list)
  gap_result <- rglimpse2_ligate(
    input_list,
    file.path(root, "gap-joined.bcf"),
    executable,
    seed = 37L
  )
  expect_true(rglimpse2_is_error(gap_result))
  expect_identical(gap_result@code, "ligate_failed")

  equal_start <- file.path(root, "equal-start.bcf")
  write_chunk(
    equal_start,
    c(
      record(100L, "1|0"),
      record(300L, "1|0"),
      record(400L, "1|0"),
      record(500L, "1|0")
    )
  )
  writeLines(c(chunks[1L], equal_start), input_list)
  equal_result <- rglimpse2_ligate(
    input_list,
    file.path(root, "equal-start-joined.bcf"),
    executable,
    seed = 37L
  )
  expect_true(rglimpse2_is_error(equal_result))
  expect_false(file.exists(file.path(root, "equal-start-joined.bcf")))

  internal_sets <- file.path(root, "internal-sets.bcf")
  write_chunk(
    internal_sets,
    c(
      "X\t100\t.\tA\tC\t.\tPASS\t.\tGT:PS\t0|1:100\t0|1:100",
      "X\t300\t.\tA\tC\t.\tPASS\t.\tGT:PS\t0|1:300\t0|1:300"
    ),
    phase_sets = TRUE
  )
  writeLines(c(internal_sets, chunks[2L]), input_list)
  sets_result <- rglimpse2_ligate(
    input_list,
    file.path(root, "internal-sets-joined.bcf"),
    executable,
    seed = 37L
  )
  expect_true(rglimpse2_is_error(sets_result))
  expect_false(file.exists(file.path(root, "internal-sets-joined.bcf")))
})
