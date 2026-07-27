.rgl_read_process_text <- function(path) {
  if (!file.exists(path)) {
    return(character())
  }
  readLines(path, warn = FALSE, encoding = "UTF-8")
}

.rgl_run_process <- function(operation, executable, arguments, outputs) {
  stdout_path <- tempfile("rglimpse2-stdout-")
  stderr_path <- tempfile("rglimpse2-stderr-")
  on.exit(unlink(c(stdout_path, stderr_path), force = TRUE), add = TRUE)

  process <- tryCatch(
    processx::run(
      command = executable,
      args = unname(arguments),
      error_on_status = FALSE,
      echo_cmd = FALSE,
      echo = FALSE,
      stdout = stdout_path,
      stderr = stderr_path,
      cleanup_tree = TRUE,
      windows_hide_window = TRUE
    ),
    error = identity
  )
  stdout <- .rgl_read_process_text(stdout_path)
  stderr <- .rgl_read_process_text(stderr_path)
  if (inherits(process, "error")) {
    return(rglimpse2_error_value(
      message = conditionMessage(process),
      kind = "process",
      code = "process_launch_failed",
      details = list(
        executable = executable,
        arguments = arguments,
        stdout = stdout,
        stderr = stderr
      ),
      source = process,
      operation = operation
    ))
  }
  status <- as.integer(process$status)
  if (length(status) != 1L || is.na(status) || status != 0L) {
    return(rglimpse2_error_value(
      message = paste0(operation, " exited with status ", status),
      kind = "process",
      code = paste0(operation, "_failed"),
      details = list(
        executable = executable,
        arguments = arguments,
        stdout = stdout,
        stderr = stderr
      ),
      operation = operation,
      status = status
    ))
  }

  missing <- names(outputs)[
    !vapply(
      outputs,
      function(path) file.exists(path) && !dir.exists(path),
      logical(1L)
    )
  ]
  if (length(missing)) {
    return(rglimpse2_error_value(
      message = paste0(
        operation,
        " completed without producing required output: ",
        paste(missing, collapse = ", ")
      ),
      kind = "output",
      code = "required_output_missing",
      details = list(
        operation = operation,
        missing = missing,
        outputs = outputs,
        stdout = stdout,
        stderr = stderr
      )
    ))
  }

  RGlimpse2RunResult(
    operation = operation,
    outputs = outputs,
    status = status,
    stdout = stdout,
    stderr = stderr
  )
}

.rgl_preflight <- function(
  operation,
  executable,
  inputs,
  outputs
) {
  executable_ok <- .rgl_require_executable(executable, operation)
  if (rglimpse2_is_error(executable_ok)) {
    return(executable_ok)
  }

  output_keys <- vapply(outputs, .rgl_path_key, character(1L))
  duplicated_outputs <- names(outputs)[
    duplicated(output_keys) | duplicated(output_keys, fromLast = TRUE)
  ]
  if (length(duplicated_outputs)) {
    .rgl_signal_contract_violation(
      "output paths must be distinct",
      code = "duplicate_output_paths",
      details = list(
        operation = operation,
        outputs = outputs,
        duplicated = duplicated_outputs
      )
    )
  }

  for (name in names(inputs)) {
    input_ok <- .rgl_require_input(inputs[[name]], name)
    if (rglimpse2_is_error(input_ok)) {
      return(input_ok)
    }
  }
  for (name in names(outputs)) {
    output_ok <- .rgl_require_output(outputs[[name]], name)
    if (rglimpse2_is_error(output_ok)) {
      return(output_ok)
    }
  }
  invisible(TRUE)
}
