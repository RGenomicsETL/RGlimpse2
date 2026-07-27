if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for real BCF output validation")
}

local({
  data_root <- system.file(
    "tinytest",
    "tiny-imputation",
    package = "RGlimpse2"
  )
  expect_true(dir.exists(data_root))
  cases <- utils::read.delim(
    file.path(data_root, "manifest.tsv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_identical(nrow(cases), 8L)
  expect_identical(
    cases$contig,
    c("1", "chr1", "Y", "chrY", "M", "chrM", "MT", "chrMT")
  )

  root <- tempfile("rglimpse2-native;literal ")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  scalar_executables <- rglimpse2_executables(phase_backend = "scalar")
  expect_true(S7::S7_inherits(scalar_executables, RGlimpse2Executables))

  inspect_bcf <- function(path) {
    reader <- vcfppR::vcfreader$new(path)
    contigs <- character()
    records <- character()
    count <- 0L
    while (reader$variant()) {
      count <- count + 1L
      contigs <- c(contigs, reader$chr())
      records <- c(records, reader$line())
    }
    list(
      count = count,
      contigs = unique(contigs),
      samples = reader$samples(),
      records = records
    )
  }

  reference_bins <- list()
  phase_records <- list()
  for (index in seq_len(nrow(cases))) {
    case <- cases[index, , drop = FALSE]
    case_output <- file.path(root, case$id)
    dir.create(case_output)
    reference_bcf <- file.path(data_root, case$reference)
    target_bcf <- file.path(data_root, case$target)
    expect_true(all(file.exists(c(
      reference_bcf,
      paste0(reference_bcf, ".csi"),
      target_bcf,
      paste0(target_bcf, ".csi")
    ))))

    genetic_map <- rglimpse2_genetic_map(case$assembly, case$contig)
    map_row <- rglimpse2_genetic_maps()
    map_row <- map_row[map_row$path == genetic_map, , drop = FALSE]
    expect_identical(nrow(map_row), 1L)
    expect_identical(map_row$chromosome, case$chromosome)

    chunks_path <- file.path(case_output, "chunks.txt")
    chunk_result <- rglimpse2_chunk(
      input_sites = reference_bcf,
      region = case$input_region,
      output_chunks = chunks_path,
      executable = scalar_executables@chunk,
      genetic_map = genetic_map,
      seed = 100L + index,
      algorithm = "recursive",
      window_cm = 0.01,
      window_mb = 0.005,
      window_count = 10L,
      buffer_cm = 0.01,
      buffer_mb = 0.002,
      buffer_count = 2L
    )
    expect_true(
      S7::S7_inherits(chunk_result, RGlimpse2RunResult),
      info = case$id
    )
    chunk_lines <- readLines(chunks_path, warn = FALSE)
    chunk_contigs <- vapply(
      strsplit(chunk_lines, "[[:space:]]+"),
      `[[`,
      character(1L),
      2L
    )
    expect_true(length(chunk_contigs) >= 1L, info = case$id)
    expect_true(all(chunk_contigs == case$contig), info = case$id)

    reference_prefix <- file.path(case_output, "reference")
    split_result <- rglimpse2_split_reference(
      reference_bcf = reference_bcf,
      input_region = case$input_region,
      output_region = case$output_region,
      output_prefix = reference_prefix,
      executable = scalar_executables@split_reference,
      genetic_map = genetic_map,
      seed = 200L + index
    )
    expect_true(
      S7::S7_inherits(split_result, RGlimpse2RunResult),
      info = case$id
    )
    reference_bin <- split_result@outputs$reference_bin
    expect_true(file.info(reference_bin)$size > 0, info = case$id)
    reference_bins[[case$id]] <- reference_bin

    sample_ploidy <- if (!identical(case$sample_ploidy, ".")) {
      file.path(data_root, case$sample_ploidy)
    } else {
      character()
    }
    phase_output <- file.path(case_output, "phase.bcf")
    phase_result <- rglimpse2_phase(
      input_gl = target_bcf,
      reference_bin = reference_bin,
      output_bcf = phase_output,
      executable = scalar_executables@phase,
      seed = 300L + index,
      sample_ploidy = sample_ploidy,
      burnin = 1L,
      main = 1L,
      pbwt_depth = 2L,
      k_init = 4L,
      k_pbwt = 4L
    )
    expect_true(
      S7::S7_inherits(phase_result, RGlimpse2RunResult),
      info = case$id
    )
    observed <- inspect_bcf(phase_output)
    expect_true(observed$count > 0L, info = case$id)
    expect_identical(observed$contigs, case$contig, info = case$id)
    expect_identical(observed$samples, c("T1", "T2"), info = case$id)
    phase_records[[case$id]] <- observed$records

    input_list <- file.path(case_output, "ligate-input.txt")
    writeLines(phase_output, input_list, useBytes = TRUE)
    ligated <- file.path(case_output, "ligated.bcf")
    ligate_result <- rglimpse2_ligate(
      input_list = input_list,
      output_bcf = ligated,
      executable = scalar_executables@ligate,
      seed = 400L + index
    )
    expect_true(
      S7::S7_inherits(ligate_result, RGlimpse2RunResult),
      info = case$id
    )
    ligated_bcf <- inspect_bcf(ligated)
    expect_identical(ligated_bcf$contigs, case$contig, info = case$id)
    expect_identical(ligated_bcf$count, observed$count, info = case$id)
  }

  # Use one diploid target as the scalar oracle for every installed SIMD phase
  # executable. The complete alias matrix above always runs the real scalar
  # executable.
  oracle_case <- cases[cases$id == "grch37_1", , drop = FALSE]
  oracle_records <- phase_records[[oracle_case$id]]
  simd <- rglimpse2_simd_info()
  expect_true(S7::S7_inherits(simd, RGlimpse2SimdInfo))
  expect_true("scalar" %in% simd@available_backends)
  for (backend in setdiff(simd@available_backends, "scalar")) {
    executables <- rglimpse2_executables(phase_backend = backend)
    output <- file.path(root, paste0("phase-", backend, ".bcf"))
    result <- rglimpse2_phase(
      input_gl = file.path(data_root, oracle_case$target),
      reference_bin = reference_bins[[oracle_case$id]],
      output_bcf = output,
      executable = executables@phase,
      seed = 301L,
      burnin = 1L,
      main = 1L,
      pbwt_depth = 2L,
      k_init = 4L,
      k_pbwt = 4L
    )
    expect_true(S7::S7_inherits(result, RGlimpse2RunResult))
    backend_records <- inspect_bcf(output)$records
    expect_identical(
      backend_records,
      oracle_records,
      info = paste("phase records differ between scalar and", backend)
    )
  }

  invalid_input <- file.path(root, "invalid-input.bcf")
  file.create(invalid_input)
  failed_phase <- rglimpse2_phase(
    input_gl = invalid_input,
    reference_bin = reference_bins[[oracle_case$id]],
    output_bcf = file.path(root, "failed-phase.bcf"),
    executable = scalar_executables@phase,
    seed = 999L,
    burnin = 1L,
    main = 1L,
    pbwt_depth = 2L,
    k_init = 4L,
    k_pbwt = 4L
  )
  expect_true(S7::S7_inherits(failed_phase, RGlimpse2ProcessErrorValue))
  expect_identical(failed_phase@code, "phase_failed")
  expect_true(length(failed_phase@status) == 1L && failed_phase@status != 0L)
})
