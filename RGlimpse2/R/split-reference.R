#' Build one GLIMPSE2 binary reference chunk
#'
#' Invokes `GLIMPSE2_split_reference` once. `output_region` must be contained
#' within `input_region`; both regions must name the same contig.
#'
#' @param reference_bcf Absolute phased reference VCF/BCF path.
#' @param input_region Buffered region in `contig:start-end` form.
#' @param output_region Unbuffered region in `contig:start-end` form.
#' @param output_prefix Absolute output prefix. GLIMPSE2 appends the normalized
#'   input region and `.bin`.
#' @param executable Absolute `GLIMPSE2_split_reference` path.
#' @param genetic_map Absolute genetic-map path.
#' @param seed Non-negative random seed.
#' @param threads Positive worker count.
#' @param sparse_maf Rare-variant threshold in `[0, 0.5)`.
#' @param keep_monomorphic_ref_sites Whether to retain monomorphic reference
#'   records.
#' @param log Empty or one absolute log output path.
#' @return `RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
#' @export
rglimpse2_split_reference <- function(
  reference_bcf,
  input_region,
  output_region,
  output_prefix,
  executable,
  genetic_map,
  seed,
  threads = 1L,
  sparse_maf = 0.001,
  keep_monomorphic_ref_sites = FALSE,
  log = character()
) {
  .rgl_contract_call(
    code = "invalid_split_reference_request",
    details = list(api = "rglimpse2_split_reference"),
    expression = {
      reference_bcf <- .rgl_assert_absolute_path(reference_bcf, "reference_bcf")
      genetic_map <- .rgl_assert_absolute_path(genetic_map, "genetic_map")
      output_prefix <- .rgl_assert_absolute_path(output_prefix, "output_prefix")
      executable <- .rgl_assert_absolute_path(executable, "executable")
      input <- .rgl_parse_region(input_region, "input_region")
      output <- .rgl_parse_region(output_region, "output_region")
      input_region <- .rgl_format_region(input)
      output_region <- .rgl_format_region(output)
      if (
        !identical(input$contig, output$contig) ||
          input$start > output$start || input$end < output$end
      ) {
        .rgl_signal_contract_violation(
          "output_region must be contained within input_region on one contig",
          code = "incompatible_regions",
          details = list(input_region = input_region, output_region = output_region)
        )
      }
      .rgl_validate_optional_path(log, "log")
      seed <- .rgl_assert_integer(seed, "seed", 0L, .Machine$integer.max)
      threads <- .rgl_assert_integer(threads, "threads", 1L, .Machine$integer.max)
      sparse_maf <- .rgl_assert_number(sparse_maf, "sparse_maf", 0, 0.5)
      if (sparse_maf == 0.5) {
        .rgl_signal_contract_violation(
          "sparse_maf must be less than 0.5",
          code = "invalid_sparse_maf"
        )
      }
      keep_monomorphic_ref_sites <- .rgl_assert_flag(
        keep_monomorphic_ref_sites,
        "keep_monomorphic_ref_sites"
      )

      region_token <- chartr(":-", "__", input_region)
      reference_bin <- paste0(output_prefix, "_", region_token, ".bin")
      outputs <- c(
        list(reference_bin = reference_bin),
        if (length(log)) list(log = log)
      )
      ready <- .rgl_preflight(
        "split_reference",
        executable,
        inputs = list(reference_bcf = reference_bcf, genetic_map = genetic_map),
        outputs = outputs
      )
      if (rglimpse2_is_error(ready)) {
        return(ready)
      }

      arguments <- c(
        "--reference", reference_bcf,
        "--map", genetic_map,
        "--input-region", input_region,
        "--output-region", output_region,
        "--output", output_prefix,
        "--seed", as.character(seed),
        "--threads", as.character(threads),
        "--sparse-maf", .rgl_cli_number(sparse_maf),
        if (keep_monomorphic_ref_sites) "--keep-monomorphic-ref-sites",
        .rgl_optional_cli("--log", log)
      )
      .rgl_run_process("split_reference", executable, arguments, outputs)
    }
  )
}
