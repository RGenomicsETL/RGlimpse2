local({
  executables <- rglimpse2_executables(phase_backend = "scalar")
  expect_true(S7::S7_inherits(executables, RGlimpse2Executables))

  capture_contract <- function(expression) {
    tryCatch(
      force(expression),
      rglimpse2_contract_violation = identity
    )
  }

  incomplete <- capture_contract(rglimpse2_executables(
    chunk = executables@chunk
  ))
  expect_true(inherits(incomplete, "rglimpse2_contract_violation"))
  expect_identical(incomplete$code, "incomplete_executable_set")

  external_backend <- capture_contract(rglimpse2_executables(
    directory = dirname(executables@chunk),
    phase_backend = "scalar"
  ))
  expect_true(inherits(external_backend, "rglimpse2_contract_violation"))
  expect_identical(external_backend$code, "backend_with_external_executables")

  bad_backend <- capture_contract(rglimpse2_simd_info("fastest"))
  expect_true(inherits(bad_backend, "rglimpse2_contract_violation"))
  expect_identical(bad_backend$code, "invalid_phase_backend")

  bad_error <- capture_contract(rglimpse2_error_value(
    message = 1,
    kind = "input",
    code = "bad"
  ))
  expect_true(inherits(bad_error, "rglimpse2_contract_violation"))
  expect_identical(bad_error$code, "invalid_error_value")

  signaled_process <- rglimpse2_error_value(
    message = "child terminated by signal",
    kind = "process",
    code = "child_signaled",
    operation = "phase",
    status = -11L
  )
  expect_true(S7::S7_inherits(signaled_process, RGlimpse2ProcessErrorValue))
  expect_identical(signaled_process@status, -11L)

  root <- tempfile("rglimpse2-contracts-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  input_gl <- file.path(root, "input.bcf")
  reference_bin <- file.path(root, "reference.bin")
  file.create(input_gl, reference_bin)

  bad_integer <- capture_contract(rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "overflow.bcf"),
    executable = executables@phase,
    seed = .Machine$integer.max + 1
  ))
  expect_true(inherits(bad_integer, "rglimpse2_contract_violation"))
  expect_identical(bad_integer$code, "invalid_integer")

  bad_number <- capture_contract(rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "number.bcf"),
    executable = executables@phase,
    seed = 1L,
    pbwt_modulo_cm = "0.1"
  ))
  expect_true(inherits(bad_number, "rglimpse2_contract_violation"))
  expect_identical(bad_number$code, "invalid_number")

  bad_threads <- capture_contract(rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "threads.bcf"),
    executable = executables@phase,
    seed = 1L,
    threads = 2L
  ))
  expect_true(inherits(bad_threads, "rglimpse2_contract_violation"))
  expect_identical(bad_threads$code, "phase_threads_must_be_one")

  bad_extension <- capture_contract(rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "phase.txt"),
    executable = executables@phase,
    seed = 1L
  ))
  expect_true(inherits(bad_extension, "rglimpse2_contract_violation"))
  expect_identical(bad_extension$code, "unsupported_phase_output")

  duplicate_output <- file.path(root, "duplicate-output.bcf")
  duplicate_output_condition <- capture_contract(rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = reference_bin,
    output_bcf = duplicate_output,
    executable = executables@phase,
    seed = 1L,
    log = duplicate_output
  ))
  expect_true(inherits(
    duplicate_output_condition,
    "rglimpse2_contract_violation"
  ))
  expect_identical(
    duplicate_output_condition$code,
    "duplicate_output_paths"
  )
  expect_identical(
    duplicate_output_condition$details$duplicated,
    c("output_bcf", "log")
  )

  missing_directory <- rglimpse2_phase(
    input_gl = input_gl,
    reference_bin = reference_bin,
    output_bcf = file.path(root, "missing", "phase.bcf"),
    executable = executables@phase,
    seed = 1L
  )
  expect_true(S7::S7_inherits(missing_directory, RGlimpse2OutputErrorValue))
  expect_identical(missing_directory@code, "output_directory_missing")

  split_prefix <- file.path(root, "canonical")
  canonical_bin <- paste0(split_prefix, "_chr1_1_200.bin")
  file.create(canonical_bin)
  canonical_occupied <- rglimpse2_split_reference(
    reference_bcf = input_gl,
    input_region = "chr1:0001-0200",
    output_region = "chr1:0050-0150",
    output_prefix = split_prefix,
    executable = executables@split_reference,
    genetic_map = reference_bin,
    seed = 1L
  )
  expect_true(S7::S7_inherits(
    canonical_occupied,
    RGlimpse2OutputErrorValue
  ))
  expect_identical(canonical_occupied@code, "output_exists")
  expect_identical(canonical_occupied@details$path, canonical_bin)

  unlink(canonical_bin)

  overflowing_region <- capture_contract(rglimpse2_split_reference(
    reference_bcf = input_gl,
    input_region = "chr1:1-2147483648",
    output_region = "chr1:1-200",
    output_prefix = file.path(root, "overflowing-region"),
    executable = executables@split_reference,
    genetic_map = reference_bin,
    seed = 1L
  ))
  expect_true(inherits(overflowing_region, "rglimpse2_contract_violation"))
  expect_identical(overflowing_region$code, "invalid_region")

  chunk <- file.path(root, "chunk.bcf")
  writeLines("chunk", chunk)
  list_path <- file.path(root, "duplicate.list")
  writeLines(c(chunk, chunk), list_path)
  duplicate_chunks <- rglimpse2_ligate(
    input_list = list_path,
    output_bcf = file.path(root, "duplicate.bcf"),
    executable = executables@ligate,
    seed = 1L
  )
  expect_true(S7::S7_inherits(duplicate_chunks, RGlimpse2InputErrorValue))
  expect_identical(duplicate_chunks@code, "invalid_ligate_input_list")
  expect_identical(duplicate_chunks@details$duplicated, chunk)

  malformed_list <- file.path(root, "malformed.list")
  writeLines(c(chunk, "", paste0(" ", chunk)), malformed_list)
  malformed_chunks <- rglimpse2_ligate(
    input_list = malformed_list,
    output_bcf = file.path(root, "malformed.bcf"),
    executable = executables@ligate,
    seed = 1L
  )
  expect_true(S7::S7_inherits(malformed_chunks, RGlimpse2InputErrorValue))
  expect_identical(malformed_chunks@code, "invalid_ligate_input_list")
  expect_identical(malformed_chunks@details$malformed, c("", paste0(
    " ",
    chunk
  )))
})
