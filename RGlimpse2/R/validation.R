.rgl_scalar_string <- S7::new_property(
  class = S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-missing, non-empty string"
    }
  }
)

.rgl_id <- S7::new_property(
  class = S7::class_character,
  validator = function(value) {
    if (
      length(value) != 1L || is.na(value) ||
        !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", value)
    ) {
      "must be one stable identifier"
    }
  }
)

.rgl_optional_id <- S7::new_property(
  class = S7::class_character,
  validator = function(value) {
    if (
      length(value) > 1L || anyNA(value) ||
        (length(value) == 1L &&
          !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", value))
    ) {
      "must be empty or one stable identifier"
    }
  }
)

.rgl_nonnegative_integer <- S7::new_property(
  class = S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) {
      "must be one non-negative integer"
    }
  }
)

.rgl_optional_integer <- S7::new_property(
  class = S7::class_integer,
  validator = function(value) {
    if (length(value) > 1L || anyNA(value)) {
      "must be empty or one non-missing integer"
    }
  }
)

.rgl_assert_scalar_character <- function(value, argument) {
  if (
    !is.character(value) || length(value) != 1L ||
      is.na(value) || !nzchar(value)
  ) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be one non-missing, non-empty string"),
      code = "invalid_scalar_string",
      details = list(argument = argument)
    )
  }
  value
}

.rgl_assert_flag <- function(value, argument) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be TRUE or FALSE"),
      code = "invalid_flag",
      details = list(argument = argument)
    )
  }
  value
}

.rgl_assert_integer <- function(value, argument, minimum = 0L, maximum = Inf) {
  valid <- is.numeric(value) && length(value) == 1L && !is.na(value) &&
    is.finite(value) && value == floor(value) &&
    value >= minimum && value <= maximum &&
    value >= -.Machine$integer.max && value <= .Machine$integer.max
  if (!valid) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be an integer in [", minimum, ", ", maximum, "]"),
      code = "invalid_integer",
      details = list(argument = argument, minimum = minimum, maximum = maximum)
    )
  }
  as.integer(value)
}

.rgl_assert_number <- function(
  value,
  argument,
  minimum = -Inf,
  maximum = Inf,
  minimum_open = FALSE
) {
  valid <- is.numeric(value) && length(value) == 1L && !is.na(value) &&
    is.finite(value)
  if (valid) {
    valid <- if (minimum_open) value > minimum else value >= minimum
    valid <- valid && value <= maximum
  }
  if (!valid) {
    .rgl_signal_contract_violation(
      paste0(argument, " has an invalid numeric value"),
      code = "invalid_number",
      details = list(argument = argument, minimum = minimum, maximum = maximum)
    )
  }
  as.double(value)
}

.rgl_is_absolute_path <- function(path) {
  grepl("^/", path) ||
    grepl("^[A-Za-z]:[/\\\\]", path) ||
    grepl("^\\\\\\\\", path)
}

.rgl_has_parent_traversal <- function(path) {
  any(strsplit(gsub("\\\\", "/", path), "/", fixed = TRUE)[[1L]] == "..")
}

.rgl_assert_absolute_path <- function(path, argument) {
  path <- .rgl_assert_scalar_character(path, argument)
  if (!.rgl_is_absolute_path(path) || .rgl_has_parent_traversal(path)) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be an absolute path without parent traversal"),
      code = "absolute_path_required",
      details = list(argument = argument, path = path)
    )
  }
  path
}

.rgl_validate_optional_path <- function(path, argument) {
  if (!is.character(path) || length(path) > 1L || anyNA(path)) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be empty or one path"),
      code = "invalid_optional_path",
      details = list(argument = argument)
    )
  }
  if (length(path)) .rgl_assert_absolute_path(path, argument)
  invisible(path)
}

.rgl_validate_optional_string <- function(value, argument) {
  if (!is.character(value) || length(value) > 1L || anyNA(value)) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be empty or one string"),
      code = "invalid_optional_string",
      details = list(argument = argument)
    )
  }
  if (length(value) && (!nzchar(value) || grepl("[\r\n\t]", value))) {
    .rgl_signal_contract_violation(
      paste0(argument, " must be non-empty and contain no tabs or newlines"),
      code = "invalid_optional_string",
      details = list(argument = argument)
    )
  }
  invisible(value)
}

.rgl_alignment_format <- function(path) {
  if (grepl("\\.bam$", path, ignore.case = TRUE)) return("bam")
  if (grepl("\\.cram$", path, ignore.case = TRUE)) return("cram")
  .rgl_signal_contract_violation(
    "input_bam must end in .bam or .cram",
    code = "unsupported_alignment_input",
    details = list(path = path)
  )
}

.rgl_validate_discoverable_alignment_index <- function(
  alignment,
  index,
  format
) {
  without_extension <- sub(
    paste0("\\.", format, "$"),
    "",
    alignment,
    ignore.case = TRUE
  )
  candidates <- if (identical(format, "bam")) {
    c(
      paste0(alignment, ".bai"),
      paste0(without_extension, ".bai"),
      paste0(alignment, ".csi"),
      paste0(without_extension, ".csi")
    )
  } else {
    c(
      paste0(alignment, ".crai"),
      paste0(without_extension, ".crai")
    )
  }
  if (!.rgl_path_key(index) %in% vapply(
    candidates,
    .rgl_path_key,
    character(1L)
  )) {
    .rgl_signal_contract_violation(
      "input_index is not an adjacent index path HTSlib will discover",
      code = "undiscoverable_alignment_index",
      details = list(
        alignment = alignment,
        index = index,
        accepted_paths = candidates
      )
    )
  }
  distinct_candidates <- candidates[
    !duplicated(vapply(candidates, .rgl_path_key, character(1L)))
  ]
  other_existing <- distinct_candidates[
    vapply(distinct_candidates, file.exists, logical(1L)) &
      vapply(distinct_candidates, .rgl_path_key, character(1L)) !=
        .rgl_path_key(index)
  ]
  if (length(other_existing)) {
    .rgl_signal_contract_violation(
      "another adjacent alignment index could be selected instead of input_index",
      code = "ambiguous_alignment_indexes",
      details = list(
        alignment = alignment,
        input_index = index,
        other_existing = other_existing
      )
    )
  }
  invisible(index)
}

.rgl_validate_alignment_reference <- function(
  format,
  reference_fasta,
  reference_fasta_index
) {
  if (xor(length(reference_fasta) == 1L, length(reference_fasta_index) == 1L)) {
    .rgl_signal_contract_violation(
      "reference_fasta and reference_fasta_index must be supplied together",
      code = "incomplete_alignment_reference"
    )
  }
  if (identical(format, "cram") && !length(reference_fasta)) {
    .rgl_signal_contract_violation(
      "CRAM input requires reference_fasta and reference_fasta_index",
      code = "cram_reference_required"
    )
  }
  if (
    length(reference_fasta) &&
      !identical(
        .rgl_path_key(reference_fasta_index),
        .rgl_path_key(paste0(reference_fasta, ".fai"))
      )
  ) {
    .rgl_signal_contract_violation(
      "reference_fasta_index must be reference_fasta with .fai appended",
      code = "undiscoverable_fasta_index",
      details = list(
        reference_fasta = reference_fasta,
        reference_fasta_index = reference_fasta_index,
        expected = paste0(reference_fasta, ".fai")
      )
    )
  }
  invisible(TRUE)
}

.rgl_require_input <- function(path, argument) {
  .rgl_assert_absolute_path(path, argument)
  if (!file.exists(path) || dir.exists(path)) {
    return(rglimpse2_error_value(
      message = paste0(argument, " does not exist: ", path),
      kind = "input",
      code = "input_file_missing",
      details = list(argument = argument, path = path)
    ))
  }
  invisible(TRUE)
}

.rgl_require_output <- function(path, argument) {
  .rgl_assert_absolute_path(path, argument)
  if (file.exists(path)) {
    return(rglimpse2_error_value(
      message = paste0(argument, " already exists: ", path),
      kind = "output",
      code = "output_exists",
      details = list(argument = argument, path = path)
    ))
  }
  parent <- dirname(path)
  if (!dir.exists(parent)) {
    return(rglimpse2_error_value(
      message = paste0("output directory does not exist: ", parent),
      kind = "output",
      code = "output_directory_missing",
      details = list(argument = argument, path = path, directory = parent)
    ))
  }
  invisible(TRUE)
}

.rgl_parse_region <- function(region, argument) {
  region <- .rgl_assert_scalar_character(region, argument)
  match <- regexec("^([^:]+):([0-9]+)-([0-9]+)$", region)
  fields <- regmatches(region, match)[[1L]]
  if (length(fields) != 4L) {
    .rgl_signal_contract_violation(
      paste0(argument, " must have form contig:start-end"),
      code = "invalid_region",
      details = list(argument = argument, region = region)
    )
  }
  start <- as.double(fields[[3L]])
  end <- as.double(fields[[4L]])
  if (
    !is.finite(start) || !is.finite(end) || start < 1 || start >= end ||
      end > .Machine$integer.max
  ) {
    .rgl_signal_contract_violation(
      paste0(
        argument,
        " must have integer coordinates in [1, ",
        .Machine$integer.max,
        "] with start less than end"
      ),
      code = "invalid_region",
      details = list(argument = argument, region = region)
    )
  }
  list(
    contig = fields[[2L]],
    start = as.integer(start),
    end = as.integer(end)
  )
}

.rgl_format_region <- function(region) {
  paste0(region$contig, ":", region$start, "-", region$end)
}

.rgl_path_key <- function(path) {
  key <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (identical(.Platform$OS.type, "windows")) tolower(key) else key
}

.rgl_optional_cli <- function(flag, value) {
  if (length(value)) c(flag, value) else character()
}

.rgl_cli_number <- function(value) {
  format(value, scientific = FALSE, trim = TRUE, digits = 15L)
}
