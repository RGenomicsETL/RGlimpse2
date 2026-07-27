if (identical(.Platform$OS.type, "windows")) {
  exit_file("POSIX executable fixtures are tested on Unix")
}

local({
  fixture_bin <- system.file(
    "tinytest",
    "fixtures",
    "executables",
    package = "RGlimpse2"
  )
  expect_true(dir.exists(fixture_bin))
  fixture_program <- function(name) file.path(fixture_bin, name)

  executables <- rglimpse2_executables(directory = fixture_bin)
  expect_true(S7::S7_inherits(executables, RGlimpse2Executables))
  expect_identical(executables@phase, fixture_program("GLIMPSE2_phase"))
  expect_identical(executables@phase_backend, "external")

  packaged <- rglimpse2_executables(phase_backend = "auto")
  expect_true(S7::S7_inherits(packaged, RGlimpse2Executables))
  simd <- rglimpse2_simd_info()
  expect_true(S7::S7_inherits(simd, RGlimpse2SimdInfo))
  expect_identical(packaged@phase, simd@phase_executable)
  expect_true(simd@selected_backend %in% simd@available_backends)
  expect_true("scalar" %in% simd@available_backends)

  missing_executables <- rglimpse2_executables(
    directory = file.path(tempdir(), "does-not-exist")
  )
  expect_true(rglimpse2_is_error(missing_executables))
  expect_true(S7::S7_inherits(missing_executables, RGlimpse2InputErrorValue))
  expect_identical(missing_executables@code, "executable_directory_missing")

  relative_condition <- tryCatch(
    rglimpse2_executables(directory = "bin"),
    rglimpse2_contract_violation = identity
  )
  expect_true(inherits(relative_condition, "rglimpse2_contract_violation"))
  expect_identical(relative_condition$code, "absolute_path_required")

  root <- tempfile("rglimpse2 test;literal ")
  dir.create(root, recursive = TRUE)
  input_sites <- file.path(root, "reference.sites.bcf")
  reference_bcf <- file.path(root, "reference.bcf")
  genetic_map <- file.path(root, "chr1.map.gz")
  input_gl <- file.path(root, "sample.gl.bcf")
  sample_ploidy <- file.path(root, "sample.ploidy.txt")
  file.create(input_sites, reference_bcf, genetic_map, input_gl, sample_ploidy)
  writeLines("sample 2", sample_ploidy)

  chunk_output <- file.path(root, "chunks.txt")
  chunk_log <- file.path(root, "chunk.log")
  chunk_result <- rglimpse2_chunk(
    input_sites = input_sites,
    region = "chr1",
    output_chunks = chunk_output,
    executable = executables@chunk,
    genetic_map = genetic_map,
    seed = 7L,
    log = chunk_log
  )
  expect_true(S7::S7_inherits(chunk_result, RGlimpse2RunResult))
  expect_identical(readLines(chunk_output), "0 chr1 chr1:1-200 chr1:50-150")
  expect_true(file.exists(chunk_log))

  occupied <- rglimpse2_chunk(
    input_sites = input_sites,
    region = "chr1",
    output_chunks = chunk_output,
    executable = executables@chunk,
    genetic_map = genetic_map,
    seed = 7L
  )
  expect_true(S7::S7_inherits(occupied, RGlimpse2OutputErrorValue))
  expect_identical(occupied@code, "output_exists")

  split_prefix <- file.path(root, "reference-split")
  split_result <- rglimpse2_split_reference(
    reference_bcf = reference_bcf,
    input_region = "chr1:1-200",
    output_region = "chr1:50-150",
    output_prefix = split_prefix,
    executable = executables@split_reference,
    genetic_map = genetic_map,
    seed = 11L
  )
  expect_true(S7::S7_inherits(split_result, RGlimpse2RunResult))
  expected_reference_bin <- file.path(root, "reference-split_chr1_1_200.bin")
  expect_identical(split_result@outputs$reference_bin, expected_reference_bin)
  expect_true(file.exists(expected_reference_bin))

  bad_region <- tryCatch(
    rglimpse2_split_reference(
      reference_bcf = reference_bcf,
      input_region = "chr1:50-100",
      output_region = "chr1:1-200",
      output_prefix = file.path(root, "invalid-split"),
      executable = executables@split_reference,
      genetic_map = genetic_map,
      seed = 11L
    ),
    rglimpse2_contract_violation = identity
  )
  expect_true(inherits(bad_region, "rglimpse2_contract_violation"))
  expect_identical(bad_region$code, "incompatible_regions")

  phase_output <- file.path(root, "phase.bcf")
  phase_result <- rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = expected_reference_bin,
    output_bcf = phase_output,
    executable = executables@phase,
    seed = 13L,
    sample_ploidy = sample_ploidy,
    input_field = "PL"
  )
  expect_true(S7::S7_inherits(phase_result, RGlimpse2RunResult))
  expect_identical(readLines(phase_output), "phased:reference-split_chr1_1_200.bin")

  thread_condition <- tryCatch(
    rglimpse2_phase(
      input_gl = input_gl,
      reference_bin = expected_reference_bin,
      output_bcf = file.path(root, "threads.bcf"),
      executable = executables@phase,
      seed = 13L,
      threads = 2L
    ),
    rglimpse2_contract_violation = identity
  )
  expect_true(inherits(thread_condition, "rglimpse2_contract_violation"))
  expect_identical(thread_condition$code, "phase_threads_must_be_one")

  missing_input <- rglimpse2_phase(
    input_gl = file.path(root, "missing.bcf"),
    reference_bin = expected_reference_bin,
    output_bcf = file.path(root, "missing-input.bcf"),
    executable = executables@phase,
    seed = 13L
  )
  expect_true(S7::S7_inherits(missing_input, RGlimpse2InputErrorValue))
  expect_identical(missing_input@code, "input_file_missing")

  failed_phase <- rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = expected_reference_bin,
    output_bcf = file.path(root, "failed-phase.bcf"),
    executable = fixture_program("GLIMPSE2_phase_fail"),
    seed = 13L
  )
  expect_true(S7::S7_inherits(failed_phase, RGlimpse2ProcessErrorValue))
  expect_identical(failed_phase@code, "phase_failed")
  expect_identical(failed_phase@status, 7L)
  expect_true(any(grepl(
    "deliberate phase fixture failure",
    failed_phase@details$stderr,
    fixed = TRUE
  )))

  chunk_1 <- file.path(root, "chunk-1.bcf")
  chunk_2 <- file.path(root, "chunk-2.bcf")
  writeLines("chunk 1", chunk_1)
  writeLines("chunk 2", chunk_2)
  input_list <- file.path(root, "ligate-input.txt")
  writeLines(c(chunk_1, chunk_2), input_list)
  ligated_bcf <- file.path(root, "ligated.bcf")
  ligate_result <- rglimpse2_ligate(
    input_list = input_list,
    output_bcf = ligated_bcf,
    executable = executables@ligate,
    seed = 17L
  )
  expect_true(S7::S7_inherits(ligate_result, RGlimpse2RunResult))
  expect_identical(readLines(ligated_bcf), c("chunk 1", "chunk 2"))
})
