#!/usr/bin/env Rscript

if (!requireNamespace("vcfppR", quietly = TRUE)) {
  stop("vcfppR is required to generate tiny imputation targets")
}
if (!requireNamespace("Rduckhts", quietly = TRUE)) {
  stop("Rduckhts is required to index tiny imputation targets")
}
if (!requireNamespace("DBI", quietly = TRUE)) {
  stop("DBI is required to close the Rduckhts generation connection")
}

arguments <- commandArgs(trailingOnly = FALSE)
script_argument <- grep("^--file=", arguments, value = TRUE)
if (length(script_argument) != 1L) stop("cannot determine script path")
script_path <- normalizePath(sub("^--file=", "", script_argument), mustWork = TRUE)
package_root <- dirname(dirname(script_path))
trailing <- commandArgs(trailingOnly = TRUE)
output_root <- if (length(trailing)) {
  normalizePath(trailing[[1L]], mustWork = FALSE)
} else {
  file.path(package_root, "inst", "tinytest", "tiny-imputation")
}

cases <- data.frame(
  id = c(
    "grch37_1", "grch38_chr1", "grch37_y", "grch38_chry",
    "grch37_m", "grch37_chrm", "grch38_mt", "grch38_chrmt"
  ),
  assembly = c(
    "GRCh37", "GRCh38", "GRCh37", "GRCh38",
    "GRCh37", "GRCh37", "GRCh38", "GRCh38"
  ),
  contig = c("1", "chr1", "Y", "chrY", "M", "chrM", "MT", "chrMT"),
  chromosome = c("1", "1", "Y", "Y", "MT", "MT", "MT", "MT"),
  ploidy = c(2L, 2L, 1L, 1L, 1L, 1L, 1L, 1L),
  contig_length = c(
    249250621L, 248956422L, 59373566L, 57227415L,
    16569L, 16569L, 16569L, 16569L
  ),
  start_bp = c(
    100000L, 100000L, 2650000L, 2782000L,
    500L, 500L, 500L, 500L
  ),
  step_bp = c(1000L, 1000L, 1000L, 1000L, 300L, 300L, 300L, 300L),
  stringsAsFactors = FALSE
)
cases$end_bp <- cases$start_bp + 49L * cases$step_bp
cases$input_region <- paste0(
  cases$contig,
  ":",
  cases$start_bp - 100L,
  "-",
  cases$end_bp + 100L
)
cases$output_region <- paste0(
  cases$contig,
  ":",
  cases$start_bp,
  "-",
  cases$end_bp
)
cases$reference <- file.path(cases$id, "reference.bcf")
cases$target <- file.path(cases$id, "target.bcf")
cases$sample_ploidy <- ifelse(
  cases$ploidy == 1L,
  file.path(cases$id, "sample-ploidy.txt"),
  "."
)

unlink(output_root, recursive = TRUE, force = TRUE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

write_reference <- function(path, case) {
  writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
  writer$addContig(case$contig)
  writer$addINFO("AC", "A", "Integer", "Alternate allele count")
  writer$addINFO("AN", "1", "Integer", "Total allele count")
  writer$addFORMAT("GT", "1", "String", "Phased reference genotype")
  samples <- paste0("R", seq_len(8L))
  for (sample in samples) writer$addSample(sample)

  for (index in 0:49) {
    position <- case$start_bp + index * case$step_bp
    if (case$ploidy == 1L) {
      genotypes <- as.character((index + seq_along(samples)) %% 2L)
      allele_count <- sum(as.integer(genotypes))
      allele_number <- length(samples)
    } else {
      patterns <- c("0|0", "0|1", "1|0", "1|1")
      genotypes <- patterns[(index + seq_along(samples) - 1L) %% 4L + 1L]
      allele_count <- sum(vapply(
        strsplit(genotypes, "|", fixed = TRUE),
        function(value) sum(as.integer(value)),
        integer(1L)
      ))
      allele_number <- 2L * length(samples)
    }
    writer$writeline(paste(
      case$contig,
      position,
      paste0("v", index + 1L),
      "A",
      "C",
      ".",
      "PASS",
      paste0("AC=", allele_count, ";AN=", allele_number),
      "GT",
      paste(genotypes, collapse = "\t"),
      sep = "\t"
    ))
  }
  writer$close()
}

write_target <- function(path, case) {
  writer <- vcfppR::vcfwriter$new(path, "VCFv4.2")
  writer$addContig(case$contig)
  writer$addFORMAT("PL", "G", "Integer", "Phred-scaled genotype likelihoods")
  writer$addSample("T1")
  writer$addSample("T2")

  for (index in 0:49) {
    position <- case$start_bp + index * case$step_bp
    likelihoods <- if (case$ploidy == 1L) {
      if (index %% 2L) "40,0" else "0,40"
    } else {
      c("0,20,80", "20,0,20", "80,20,0")[[index %% 3L + 1L]]
    }
    writer$writeline(paste(
      case$contig,
      position,
      paste0("v", index + 1L),
      "A",
      "C",
      ".",
      "PASS",
      ".",
      "PL",
      likelihoods,
      likelihoods,
      sep = "\t"
    ))
  }
  writer$close()
}

connection <- Rduckhts::rduckhts_connect()
on.exit(DBI::dbDisconnect(connection, shutdown = TRUE), add = TRUE)
for (index in seq_len(nrow(cases))) {
  case <- cases[index, , drop = FALSE]
  case_root <- file.path(output_root, case$id)
  dir.create(case_root, recursive = TRUE, showWarnings = FALSE)
  reference <- file.path(output_root, case$reference)
  target <- file.path(output_root, case$target)
  write_reference(reference, case)
  write_target(target, case)
  Rduckhts::rduckhts_bcf_index(connection, reference, threads = 1L)
  Rduckhts::rduckhts_bcf_index(connection, target, threads = 1L)
  if (case$ploidy == 1L) {
    writeLines(c("T1 1", "T2 1"), file.path(output_root, case$sample_ploidy))
  }
}

manifest <- cases[c(
  "id", "assembly", "contig", "chromosome", "ploidy", "start_bp", "end_bp",
  "input_region", "output_region", "reference", "target", "sample_ploidy"
)]
write.table(
  manifest,
  file.path(output_root, "manifest.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  na = ""
)
writeLines(
  c(
    "# Tiny real-executable imputation targets",
    "",
    "Generated by `tools/create-tiny-imputation-targets.R` with `vcfppR` and",
    "indexed through `Rduckhts`. Every case has 50 biallelic variants, eight",
    "phased reference samples, and two target samples with PL likelihoods.",
    "Y and mitochondrial cases are haploid. Cases cover 1/chr1, Y/chrY, and",
    "M/MT/chrM/chrMT labels across GRCh37 and GRCh38. The data are synthetic",
    "and contain no human observations. Tests run the packaged GLIMPSE2",
    "executables against all cases; no executable test doubles are used."
  ),
  file.path(output_root, "README.md")
)
message("Generated ", nrow(cases), " tiny imputation targets in ", output_root)
