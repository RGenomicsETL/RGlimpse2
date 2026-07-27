local({
  fixture_data <- system.file(
    "tinytest",
    "fixtures",
    "data",
    package = "RGlimpse2"
  )
  expect_true(dir.exists(fixture_data))

  reference_bcf <- file.path(fixture_data, "reference.bcf")
  target_bcf <- file.path(fixture_data, "target.bcf")
  genetic_map <- file.path(fixture_data, "map.txt")
  expect_true(all(file.exists(c(
    reference_bcf,
    paste0(reference_bcf, ".csi"),
    target_bcf,
    paste0(target_bcf, ".csi"),
    genetic_map
  ))))

  root <- tempfile("rglimpse2-native-e2e-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  scalar_executables <- rglimpse2_executables(phase_backend = "scalar")
  expect_true(S7::S7_inherits(scalar_executables, RGlimpse2Executables))

  chunks <- file.path(root, "chunks.txt")
  chunk_result <- rglimpse2_chunk(
    input_sites = reference_bcf,
    region = "chr1:1-60000",
    output_chunks = chunks,
    executable = scalar_executables@chunk,
    genetic_map = genetic_map,
    seed = 19L,
    window_cm = 1,
    window_mb = 0.001,
    window_count = 10L,
    buffer_cm = 0.1,
    buffer_mb = 0.001,
    buffer_count = 2L
  )
  expect_true(S7::S7_inherits(chunk_result, RGlimpse2RunResult))
  chunk_fields <- strsplit(readLines(chunks, warn = FALSE), "[[:space:]]+")[[1L]]
  expect_identical(chunk_fields[1:4], c(
    "0",
    "chr1",
    "chr1:1000-50000",
    "chr1:1000-50000"
  ))

  reference_prefix <- file.path(root, "reference")
  split_result <- rglimpse2_split_reference(
    reference_bcf = reference_bcf,
    input_region = "chr1:1-51000",
    output_region = "chr1:1000-50000",
    output_prefix = reference_prefix,
    executable = scalar_executables@split_reference,
    genetic_map = genetic_map,
    seed = 19L
  )
  expect_true(S7::S7_inherits(split_result, RGlimpse2RunResult))
  reference_bin <- split_result@outputs$reference_bin
  expect_true(file.info(reference_bin)$size > 0)

  invalid_input <- file.path(root, "invalid-input.bcf")
  file.create(invalid_input)
  failed_phase <- rglimpse2_phase(
    input_gl = invalid_input,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "failed-phase.bcf"),
    executable = scalar_executables@phase,
    seed = 21L,
    burnin = 1L,
    main = 1L,
    pbwt_depth = 2L,
    k_init = 4L,
    k_pbwt = 4L
  )
  expect_true(S7::S7_inherits(failed_phase, RGlimpse2ProcessErrorValue))
  expect_identical(failed_phase@code, "phase_failed")
  expect_true(length(failed_phase@status) == 1L && failed_phase@status != 0L)

  simd <- rglimpse2_simd_info()
  expect_true(S7::S7_inherits(simd, RGlimpse2SimdInfo))
  expect_true("scalar" %in% simd@available_backends)
  phase_outputs <- list()
  for (backend in simd@available_backends) {
    executables <- rglimpse2_executables(phase_backend = backend)
    expect_true(S7::S7_inherits(executables, RGlimpse2Executables))
    expect_identical(executables@phase_backend, backend)
    output <- file.path(root, paste0("phase-", backend, ".bcf"))
    phase_result <- rglimpse2_phase(
      input_gl = target_bcf,
      reference_bin = reference_bin,
      output_bcf = output,
      executable = executables@phase,
      seed = 23L,
      burnin = 1L,
      main = 1L,
      pbwt_depth = 2L,
      k_init = 4L,
      k_pbwt = 4L
    )
    expect_true(S7::S7_inherits(phase_result, RGlimpse2RunResult))
    expect_true(file.info(output)$size > 0)
    phase_outputs[[backend]] <- output
  }

  scalar_bytes <- readBin(
    phase_outputs$scalar,
    what = "raw",
    n = as.integer(file.info(phase_outputs$scalar)$size)
  )
  for (backend in setdiff(names(phase_outputs), "scalar")) {
    backend_bytes <- readBin(
      phase_outputs[[backend]],
      what = "raw",
      n = as.integer(file.info(phase_outputs[[backend]])$size)
    )
    expect_identical(backend_bytes, scalar_bytes, info = paste(
      "phase output differs between scalar and",
      backend
    ))
  }

  input_list <- file.path(root, "ligate-input.txt")
  writeLines(phase_outputs$scalar, input_list, useBytes = TRUE)
  ligated <- file.path(root, "ligated.bcf")
  ligate_result <- rglimpse2_ligate(
    input_list = input_list,
    output_bcf = ligated,
    executable = scalar_executables@ligate,
    seed = 29L
  )
  expect_true(S7::S7_inherits(ligate_result, RGlimpse2RunResult))
  expect_true(file.info(ligated)$size > 0)
})
