local({
  data_root <- system.file(
    "tinytest",
    "tiny-read-fraction",
    package = "RGlimpse2"
  )
  reference_root <- system.file(
    "tinytest",
    "tiny-symbolic-bam",
    package = "RGlimpse2"
  )
  root <- tempfile("rglimpse2-read-fraction-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  executables <- rglimpse2_executables(phase_backend = "scalar")
  split <- rglimpse2_split_reference(
    reference_bcf = file.path(reference_root, "reference.bcf"),
    input_region = "chr11:900-1600",
    output_region = "chr11:1000-1490",
    output_prefix = file.path(root, "reference"),
    executable = executables@split_reference,
    genetic_map = file.path(reference_root, "genetic-map.txt"),
    seed = 8101L
  )
  expect_true(S7::S7_inherits(split, RGlimpse2RunResult))

  bcf_payload <- function(path) {
    connection <- gzfile(path, "rb")
    on.exit(close(connection), add = TRUE)
    expect_identical(readBin(connection, "raw", 5L), charToRaw("BCF\002\002"))
    header_size <- readBin(
      connection,
      "integer",
      1L,
      size = 4L,
      endian = "little"
    )
    header <- rawToChar(readBin(connection, "raw", header_size)[-header_size])
    header <- strsplit(header, "\n", fixed = TRUE)[[1L]]
    records <- readBin(connection, "raw", 1000000L)
    expect_identical(length(readBin(connection, "raw", 1L)), 0L)
    list(header = header[!startsWith(header, "##fileDate=")], records = records)
  }

  phase <- function(
    stem = "pairs",
    fraction = 1,
    fraction_seed = 0L,
    cohort = FALSE
  ) {
    alignment <- file.path(data_root, paste0(stem, ".bam"))
    index <- paste0(alignment, ".bai")
    output <- tempfile(tmpdir = root, fileext = ".bcf")
    arguments <- list(
      reference_bin = split@outputs$reference_bin,
      output_bcf = output,
      executable = executables@phase,
      seed = 8102L,
      burnin = 1L,
      main = 3L,
      pbwt_depth = 2L,
      k_init = 4L,
      k_pbwt = 4L,
      read_fraction = fraction,
      read_fraction_seed = fraction_seed
    )
    if (cohort) {
      run <- do.call(
        rglimpse2_phase_bams,
        c(
          list(
            alignments = data.frame(
              input_bam = alignment,
              input_index = index,
              sample_name = "target",
              sample_ploidy = 2L
            )
          ),
          arguments
        )
      )
    } else {
      run <- do.call(
        rglimpse2_phase_bam,
        c(
          list(
            input_bam = alignment,
            input_index = index,
            sample_name = "target"
          ),
          arguments
        )
      )
    }
    expect_true(S7::S7_inherits(run, RGlimpse2RunResult))
    bcf_payload(output)
  }

  connection <- Rduckhts::rduckhts_connect()
  on.exit(DBI::dbDisconnect(connection, shutdown = TRUE), add = TRUE)
  expected_names <- list(
    "pair7",
    c("pair2", "pair4", "pair7"),
    c("pair1", "pair2", "pair4", "pair6", "pair7", "pair8")
  )
  for (index in seq_along(expected_names)) {
    fraction <- c(0.25, 0.5, 0.75)[[index]]
    bam <- file.path(data_root, paste0("pairs-0-", fraction, ".bam"))
    reads <- DBI::dbGetQuery(
      connection,
      paste0(
        "SELECT QNAME, FLAG FROM read_bam(",
        DBI::dbQuoteString(connection, bam),
        ", scan_mode := 'sequential') ORDER BY POS"
      )
    )
    expect_identical(reads$QNAME, rep(expected_names[[index]], each = 2L))
    expect_equal(reads$FLAG, rep(c(99L, 147L), length(expected_names[[index]])))
  }
  expect_true(all(expected_names[[1L]] %in% expected_names[[2L]]))
  expect_true(all(expected_names[[2L]] %in% expected_names[[3L]]))

  full <- phase()
  expect_identical(phase(fraction_seed = 17L), full)
  expect_identical(phase(cohort = TRUE), full)
  for (fraction in c(0.25, 0.5, 0.75)) {
    expected <- phase(paste0("pairs-0-", fraction))
    observed <- phase(fraction = fraction)
    expect_identical(observed, expected)
    expect_identical(phase(fraction = fraction, cohort = TRUE), expected)
    expect_false(identical(observed, full))
  }
  expect_identical(
    phase(fraction = 0.5, fraction_seed = 17L),
    phase(fraction = 0.5, fraction_seed = 17L)
  )
  expect_false(identical(phase(fraction = 0), full))

  cram <- rglimpse2_phase_bam(
    input_bam = file.path(data_root, "pairs.cram"),
    input_index = file.path(data_root, "pairs.cram.crai"),
    reference_fasta = file.path(data_root, "reference.fa"),
    reference_fasta_index = file.path(data_root, "reference.fa.fai"),
    reference_bin = split@outputs$reference_bin,
    output_bcf = file.path(root, "cram.bcf"),
    executable = executables@phase,
    seed = 8102L,
    sample_name = "target",
    burnin = 1L,
    main = 3L,
    pbwt_depth = 2L,
    k_init = 4L,
    k_pbwt = 4L,
    read_fraction = 0.5
  )
  expect_true(S7::S7_inherits(cram, RGlimpse2RunResult))
  expect_identical(
    bcf_payload(cram@outputs$output_bcf),
    phase("pairs-0-0.5")
  )

  base_arguments <- c(
    "--bam-file",
    file.path(data_root, "pairs.bam"),
    "--reference",
    split@outputs$reference_bin,
    "--output",
    file.path(root, "invalid.bcf")
  )
  for (fraction in c("-0.1", "1.1", "nan", "inf", "bad")) {
    run <- processx::run(
      executables@phase,
      c(
        base_arguments,
        "--read-fraction",
        fraction
      ),
      error_on_status = FALSE
    )
    expect_false(run$status == 0L)
    expect_false(file.exists(file.path(root, "invalid.bcf")))
  }
  for (seed in c("-1", "0.5", "2147483648", "bad")) {
    run <- processx::run(
      executables@phase,
      c(
        base_arguments,
        "--read-fraction-seed",
        seed
      ),
      error_on_status = FALSE
    )
    expect_false(run$status == 0L)
  }
  incompatible <- processx::run(
    executables@phase,
    c(
      "--input-gl",
      file.path(reference_root, "reference.bcf"),
      "--reference",
      split@outputs$reference_bin,
      "--output",
      file.path(root, "invalid.bcf"),
      "--read-fraction",
      "0.5"
    ),
    error_on_status = FALSE
  )
  expect_false(incompatible$status == 0L)
})
