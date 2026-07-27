#' A completed RGlimpse2 child-process operation
#'
#' @param operation Stable operation identifier.
#' @param outputs Named output paths produced by the operation.
#' @param status Child-process exit status.
#' @param stdout Captured standard output.
#' @param stderr Captured standard error.
#' @export
RGlimpse2RunResult <- S7::new_class(
  "RGlimpse2RunResult",
  package = "RGlimpse2",
  properties = list(
    operation = .rgl_id,
    outputs = S7::class_list,
    status = .rgl_nonnegative_integer,
    stdout = S7::class_character,
    stderr = S7::class_character
  )
)
