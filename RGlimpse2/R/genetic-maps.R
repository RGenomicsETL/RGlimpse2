#' Resolve packaged GRCh37 or GRCh38 genetic maps
#'
#' `rglimpse2_genetic_map()` resolves one absolute installed map path.
#' `rglimpse2_genetic_maps()` returns the complete packaged inventory. The
#' autosomal and chromosome X files are byte-identical copies from the pinned
#' GLIMPSE source tree. The Y non-PAR and mitochondrial files are derived
#' two-anchor, zero-recombination coordinate maps, not empirical maps.
#'
#' @param assembly Reference assembly, either `"GRCh37"` or `"GRCh38"`.
#' @param chromosome One autosome named `"1"` through `"22"`, `"X"`, `"Y"`, or
#'   `"MT"`. A leading `"chr"` is accepted; `"M"` is normalized to `"MT"`.
#' @param region Empty to select the chromosome default, or one of `"full"`,
#'   `"nonpar"`, `"par1"`, or `"par2"`. The default is `"nonpar"` for X and
#'   Y and `"full"` otherwise.
#' @return `rglimpse2_genetic_map()` returns one absolute file path.
#'   `rglimpse2_genetic_maps()` returns a data frame describing every map and
#'   its absolute installed path.
#' @examples
#' rglimpse2_genetic_map("GRCh38", "22")
#' rglimpse2_genetic_map("GRCh37", "Y")
#' rglimpse2_genetic_map("GRCh38", "MT")
#' head(rglimpse2_genetic_maps())
#' @name rglimpse2_genetic_maps
NULL

.rgl_genetic_map_manifest <- function() {
  manifest_path <- system.file(
    "genetic_maps",
    "manifest.tsv",
    package = "RGlimpse2"
  )
  if (!nzchar(manifest_path) || !file.exists(manifest_path)) {
    stop("the installed RGlimpse2 genetic-map manifest is missing", call. = FALSE)
  }
  manifest <- utils::read.delim(
    manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest$path <- normalizePath(
    file.path(dirname(manifest_path), manifest$file),
    winslash = "/",
    mustWork = TRUE
  )
  rownames(manifest) <- NULL
  manifest
}

.rgl_normalize_map_assembly <- function(assembly) {
  assembly <- .rgl_assert_scalar_character(assembly, "assembly")
  key <- toupper(assembly)
  if (identical(key, "GRCH37")) return("GRCh37")
  if (identical(key, "GRCH38")) return("GRCh38")
  .rgl_signal_contract_violation(
    "assembly must be GRCh37 or GRCh38",
    code = "unsupported_genetic_map_assembly",
    details = list(assembly = assembly)
  )
}

.rgl_normalize_map_chromosome <- function(chromosome) {
  chromosome <- .rgl_assert_scalar_character(chromosome, "chromosome")
  chromosome <- toupper(sub("^CHR", "", chromosome, ignore.case = TRUE))
  if (identical(chromosome, "M")) chromosome <- "MT"
  valid <- c(as.character(seq_len(22L)), "X", "Y", "MT")
  if (!chromosome %in% valid) {
    .rgl_signal_contract_violation(
      "chromosome must be 1-22, X, Y, or MT",
      code = "unsupported_genetic_map_chromosome",
      details = list(chromosome = chromosome)
    )
  }
  chromosome
}

.rgl_normalize_map_region <- function(region, chromosome) {
  if (!is.character(region) || length(region) > 1L || anyNA(region)) {
    .rgl_signal_contract_violation(
      "region must be empty or one non-missing string",
      code = "invalid_genetic_map_region",
      details = list(region = region)
    )
  }
  if (!length(region)) {
    return(if (chromosome %in% c("X", "Y")) "nonpar" else "full")
  }
  if (!nzchar(region)) {
    .rgl_signal_contract_violation(
      "region must not be an empty string",
      code = "invalid_genetic_map_region"
    )
  }
  normalized <- tolower(gsub("[-_]", "", region))
  valid <- c("full", "nonpar", "par1", "par2")
  if (!normalized %in% valid) {
    .rgl_signal_contract_violation(
      "region must be full, nonpar, par1, or par2",
      code = "invalid_genetic_map_region",
      details = list(region = region)
    )
  }
  normalized
}

#' @rdname rglimpse2_genetic_maps
#' @export
rglimpse2_genetic_maps <- function() {
  .rgl_genetic_map_manifest()
}

#' @rdname rglimpse2_genetic_maps
#' @export
rglimpse2_genetic_map <- function(
  assembly = "GRCh38",
  chromosome,
  region = character()
) {
  assembly <- .rgl_normalize_map_assembly(assembly)
  chromosome <- .rgl_normalize_map_chromosome(chromosome)
  region <- .rgl_normalize_map_region(region, chromosome)
  manifest <- .rgl_genetic_map_manifest()
  selected <- manifest$assembly == assembly &
    manifest$chromosome == chromosome &
    manifest$region == region
  if (sum(selected) != 1L) {
    available <- unique(manifest$region[
      manifest$assembly == assembly & manifest$chromosome == chromosome
    ])
    .rgl_signal_contract_violation(
      paste0(
        "no packaged ", assembly, " map for chromosome ", chromosome,
        " and region ", region
      ),
      code = "genetic_map_not_found",
      details = list(
        assembly = assembly,
        chromosome = chromosome,
        region = region,
        available_regions = available
      )
    )
  }
  manifest$path[[which(selected)]]
}
