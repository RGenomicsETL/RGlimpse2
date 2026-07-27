#' A typed RGlimpse2 operational error value
#'
#' Invalid calls signal `rglimpse2_contract_violation()` conditions. Expected missing
#' inputs, occupied outputs, unavailable executables, and child-process failures
#' are returned as values so callers can branch without parsing messages.
#'
#' @param message Human-readable description.
#' @param code Stable machine-readable code.
#' @param details Structured error details.
#' @param source Optional source condition or backend value.
#' @export
RGlimpse2ErrorValue <- S7::new_class(
  "RGlimpse2ErrorValue",
  package = "RGlimpse2",
  abstract = TRUE,
  properties = list(
    message = .rgl_scalar_string,
    code = .rgl_id,
    details = S7::class_list,
    source = S7::class_any
  )
)

#' @rdname RGlimpse2ErrorValue
#' @export
RGlimpse2InputErrorValue <- S7::new_class(
  "RGlimpse2InputErrorValue",
  package = "RGlimpse2",
  parent = RGlimpse2ErrorValue
)

#' @rdname RGlimpse2ErrorValue
#' @export
RGlimpse2OutputErrorValue <- S7::new_class(
  "RGlimpse2OutputErrorValue",
  package = "RGlimpse2",
  parent = RGlimpse2ErrorValue
)

#' @rdname RGlimpse2ErrorValue
#' @param operation Stable child-process operation identifier.
#' @param status Child-process exit status when available.
#' @export
RGlimpse2ProcessErrorValue <- S7::new_class(
  "RGlimpse2ProcessErrorValue",
  package = "RGlimpse2",
  parent = RGlimpse2ErrorValue,
  properties = list(
    operation = .rgl_id,
    status = .rgl_optional_integer
  )
)

#' Construct a typed RGlimpse2 operational error
#'
#' @inheritParams RGlimpse2ErrorValue
#' @param kind Operational error category.
#' @param operation Child-process operation for process errors.
#' @param status Child-process exit status when available.
#' @return An `RGlimpse2ErrorValue` subclass.
#' @export
rglimpse2_error_value <- function(
  message,
  kind = c("input", "output", "process"),
  code,
  details = list(),
  source = NULL,
  operation = character(),
  status = integer()
) {
  .rgl_contract_call(
    code = "invalid_error_value",
    details = list(api = "rglimpse2_error_value"),
    expression = {
      kind <- match.arg(kind)
      common <- list(
        message = message,
        code = code,
        details = details,
        source = source
      )
      switch(kind,
        input = do.call(RGlimpse2InputErrorValue, common),
        output = do.call(RGlimpse2OutputErrorValue, common),
        process = {
          .rgl_assert_scalar_character(operation, "operation")
          if (length(status)) {
            status <- .rgl_assert_integer(status, "status", minimum = 0L)
          }
          do.call(
            RGlimpse2ProcessErrorValue,
            c(common, list(operation = operation, status = status))
          )
        }
      )
    }
  )
}

#' Test whether a value is an RGlimpse2 operational error
#'
#' @param value Any R value.
#' @return A logical scalar.
#' @export
rglimpse2_is_error <- function(value) {
  isTRUE(tryCatch(
    S7::S7_inherits(value, RGlimpse2ErrorValue),
    error = function(condition) FALSE
  ))
}

#' Construct a typed RGlimpse2 contract condition
#'
#' @param message Human-readable description.
#' @param call Call associated with the violation.
#' @param code Stable machine-readable code.
#' @param details Structured condition details.
#' @return An `rglimpse2_contract_violation` condition.
#' @export
rglimpse2_contract_violation <- function(
  message,
  call = NULL,
  code = "invalid_contract",
  details = list()
) {
  invalid <- if (
    !is.character(message) || length(message) != 1L ||
      is.na(message) || !nzchar(message)
  ) {
    "message"
  } else if (!is.null(call) && !is.call(call)) {
    "call"
  } else if (
    !is.character(code) || length(code) != 1L || is.na(code) ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", code)
  ) {
    "code"
  } else if (!is.list(details)) {
    "details"
  } else {
    character()
  }
  if (length(invalid)) {
    base::stop(structure(
      list(
        message = paste0(invalid, " has an invalid type or shape"),
        call = sys.call(),
        code = "invalid_contract_condition",
        details = list(argument = invalid)
      ),
      class = c("rglimpse2_contract_violation", "error", "condition")
    ))
  }
  structure(
    list(message = message, call = call, code = code, details = details),
    class = c("rglimpse2_contract_violation", "error", "condition")
  )
}

.rgl_signal_contract_violation <- function(
  message,
  call = sys.call(-1L),
  code = "invalid_contract",
  details = list()
) {
  base::stop(rglimpse2_contract_violation(message, call, code, details))
}

.rgl_contract_call <- function(code, details, expression) {
  caller_call <- sys.call(-1L)
  tryCatch(
    force(expression),
    error = function(condition) {
      if (inherits(condition, "rglimpse2_contract_violation")) {
        base::stop(condition)
      }
      .rgl_signal_contract_violation(
        message = conditionMessage(condition),
        call = caller_call,
        code = code,
        details = c(details, list(source_class = class(condition)))
      )
    }
  )
}
