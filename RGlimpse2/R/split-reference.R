#' Build one GLIMPSE2 binary reference chunk
#'
#' Invokes `GLIMPSE2_split_reference` once. `output_region` must be contained
#' within `input_region`; both regions must name the same contig. Before the
#' child process starts, RGlimpse2 scans the requested reference region and
#' rejects records whose allele count is not exactly two. Reference preparation
#' must split or otherwise resolve multiallelic records before this call.
#'
#' @param reference_bcf Absolute phased reference VCF/BCF path.
#' @param input_region Buffered region in `contig:start-end` form.
#' @param output_region Unbuffered region in `contig:start-end` form.
#' @param output_prefix Absolute output prefix. GLIMPSE2 appends the normalized
#'   input region and `.bin`.
#' @param executable Absolute `GLIMPSE2_split_reference` path.
#' @param genetic_map Absolute genetic-map path, such as one returned by
#'   `rglimpse2_genetic_map()`.
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

      reference_variants <- .rgl_require_biallelic_reference_region(
        reference_bcf,
        input_region
      )
      if (rglimpse2_is_error(reference_variants)) {
        return(reference_variants)
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

.rgl_require_biallelic_reference_region <- function(
  reference_bcf,
  input_region
) {
  connection <- NULL
  invalid <- tryCatch(
    {
      connection <- Rduckhts::rduckhts_connect()
      Rduckhts::rduckhts_bcf(
        con = connection,
        table_name = NULL,
        path = reference_bcf,
        region = input_region,
        scan_mode = "auto",
        decompression_threads = 0L,
        decode_error_policy = "error"
      )
      DBI::dbGetQuery(
        connection,
        paste(
          "WITH invalid AS (",
          "  SELECT CHROM AS chrom, POS AS pos, REF AS ref,",
          "    array_to_string(ALT, ',') AS alt",
          "  FROM bcf_data",
          "  WHERE ALT IS NULL OR coalesce(array_length(ALT), 0) <> 1",
          ")",
          "SELECT chrom, pos, ref, alt, count(*) OVER () AS invalid_count",
          "FROM invalid",
          "ORDER BY chrom, pos",
          "LIMIT 20"
        )
      )
    },
    error = identity
  )
  if (!is.null(connection)) {
    try(DBI::dbDisconnect(connection, shutdown = TRUE), silent = TRUE)
  }
  if (inherits(invalid, "error")) {
    return(rglimpse2_error_value(
      message = paste0(
        "could not inspect reference_bcf variants in ",
        input_region,
        ": ",
        conditionMessage(invalid)
      ),
      kind = "input",
      code = "reference_variant_scan_failed",
      details = list(
        argument = "reference_bcf",
        path = reference_bcf,
        input_region = input_region
      ),
      source = invalid
    ))
  }
  if (!nrow(invalid)) {
    return(invisible(TRUE))
  }

  invalid_count <- as.numeric(invalid$invalid_count[[1L]])
  rglimpse2_error_value(
    message = paste0(
      "reference_bcf contains ",
      invalid_count,
      " record(s) with n_allele != 2 in ",
      input_region
    ),
    kind = "input",
    code = "non_biallelic_reference",
    details = list(
      argument = "reference_bcf",
      path = reference_bcf,
      input_region = input_region,
      invalid_count = invalid_count,
      examples = invalid[c("chrom", "pos", "ref", "alt")]
    )
  )
}
