#' Create deterministic GLIMPSE2 imputation chunks
#'
#' Invokes `GLIMPSE2_chunk` once. All paths are explicit and the output file
#' must not already exist.
#'
#' @param input_sites Absolute VCF/BCF sites path.
#' @param region Contig or genomic interval to split.
#' @param output_chunks Absolute output chunk-table path.
#' @param executable Absolute `GLIMPSE2_chunk` path.
#' @param genetic_map Absolute genetic-map path, such as one returned by
#'   `rglimpse2_genetic_map()`.
#' @param seed Non-negative random seed.
#' @param threads Positive worker count.
#' @param algorithm Chunking algorithm.
#' @param window_cm,window_mb Positive minimum window sizes.
#' @param window_count Positive minimum window variant count.
#' @param buffer_cm,buffer_mb Positive minimum buffer sizes.
#' @param buffer_count Positive minimum buffer variant count.
#' @param sparse_maf Rare-variant threshold in `[0, 0.5)`.
#' @param log Empty or one absolute log output path.
#' @return `RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
#' @export
rglimpse2_chunk <- function(
  input_sites,
  region,
  output_chunks,
  executable,
  genetic_map,
  seed,
  threads = 1L,
  algorithm = c("sequential", "recursive"),
  window_cm = 2.5,
  window_mb = 2.0,
  window_count = 20000L,
  buffer_cm = 0.5,
  buffer_mb = 0.4,
  buffer_count = 2000L,
  sparse_maf = 0.001,
  log = character()
) {
  .rgl_contract_call(
    code = "invalid_chunk_request",
    details = list(api = "rglimpse2_chunk"),
    expression = {
      input_sites <- .rgl_assert_absolute_path(input_sites, "input_sites")
      genetic_map <- .rgl_assert_absolute_path(genetic_map, "genetic_map")
      output_chunks <- .rgl_assert_absolute_path(output_chunks, "output_chunks")
      executable <- .rgl_assert_absolute_path(executable, "executable")
      region <- .rgl_assert_scalar_character(region, "region")
      .rgl_validate_optional_path(log, "log")
      seed <- .rgl_assert_integer(seed, "seed", 0L, .Machine$integer.max)
      threads <- .rgl_assert_integer(threads, "threads", 1L, .Machine$integer.max)
      algorithm <- match.arg(algorithm)
      window_cm <- .rgl_assert_number(window_cm, "window_cm", 0, minimum_open = TRUE)
      window_mb <- .rgl_assert_number(window_mb, "window_mb", 0, minimum_open = TRUE)
      window_count <- .rgl_assert_integer(window_count, "window_count", 1L)
      buffer_cm <- .rgl_assert_number(buffer_cm, "buffer_cm", 0, minimum_open = TRUE)
      buffer_mb <- .rgl_assert_number(buffer_mb, "buffer_mb", 0, minimum_open = TRUE)
      buffer_count <- .rgl_assert_integer(buffer_count, "buffer_count", 1L)
      sparse_maf <- .rgl_assert_number(sparse_maf, "sparse_maf", 0, 0.5)
      if (sparse_maf == 0.5) {
        .rgl_signal_contract_violation(
          "sparse_maf must be less than 0.5",
          code = "invalid_sparse_maf"
        )
      }

      outputs <- c(list(chunks = output_chunks), if (length(log)) list(log = log))
      ready <- .rgl_preflight(
        "chunk",
        executable,
        inputs = list(input_sites = input_sites, genetic_map = genetic_map),
        outputs = outputs
      )
      if (rglimpse2_is_error(ready)) return(ready)

      arguments <- c(
        "--input", input_sites,
        "--map", genetic_map,
        "--region", region,
        paste0("--", algorithm),
        "--seed", as.character(seed),
        "--threads", as.character(threads),
        "--window-cm", .rgl_cli_number(window_cm),
        "--window-mb", .rgl_cli_number(window_mb),
        "--window-count", as.character(window_count),
        "--buffer-cm", .rgl_cli_number(buffer_cm),
        "--buffer-mb", .rgl_cli_number(buffer_mb),
        "--buffer-count", as.character(buffer_count),
        "--sparse-maf", .rgl_cli_number(sparse_maf),
        "--output", output_chunks,
        .rgl_optional_cli("--log", log)
      )
      .rgl_run_process("chunk", executable, arguments, outputs)
    }
  )
}
