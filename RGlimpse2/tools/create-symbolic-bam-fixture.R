#!/usr/bin/env Rscript

if (!requireNamespace("vcfppR", quietly = TRUE)) {
  stop("vcfppR is required to generate the symbolic BAM fixture")
}
if (!requireNamespace("Rduckhts", quietly = TRUE)) {
  stop("Rduckhts is required to index the symbolic reference")
}
if (!requireNamespace("DBI", quietly = TRUE)) {
  stop("DBI is required to close the Rduckhts generation connection")
}
if (!requireNamespace("processx", quietly = TRUE)) {
  stop("processx is required to invoke samtools")
}

arguments <- commandArgs(trailingOnly = FALSE)
script_argument <- grep("^--file=", arguments, value = TRUE)
if (length(script_argument) != 1L) stop("cannot determine script path")
script_path <- normalizePath(sub("^--file=", "", script_argument), mustWork = TRUE)
package_root <- dirname(dirname(script_path))
trailing <- commandArgs(trailingOnly = TRUE)
if (length(trailing) < 1L || length(trailing) > 2L) {
  stop("usage: create-symbolic-bam-fixture.R /absolute/samtools [output_dir]")
}
samtools <- normalizePath(trailing[[1L]], mustWork = TRUE)
if (dir.exists(samtools) || file.access(samtools, mode = 1L) != 0L) {
  stop("samtools must be an executable file")
}
output_root <- if (length(trailing) == 2L) {
  normalizePath(trailing[[2L]], mustWork = FALSE)
} else {
  file.path(package_root, "inst", "tinytest", "tiny-symbolic-bam")
}

unlink(output_root, recursive = TRUE, force = TRUE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

reference <- file.path(output_root, "reference.bcf")
writer <- vcfppR::vcfwriter$new(reference, "VCFv4.2")
writer$addContig("chr11")
writer$addINFO("AC", "A", "Integer", "Alternate allele count")
writer$addINFO("AN", "1", "Integer", "Total allele count")
writer$addINFO("SVTYPE", "1", "String", "Structural variant type")
writer$addFORMAT("GT", "1", "String", "Phased reference genotype")
samples <- paste0("R", seq_len(8L))
for (sample in samples) writer$addSample(sample)
patterns <- c("0|0", "0|1", "1|0", "1|1")
for (index in 0:49) {
  position <- 1000L + index * 10L
  genotypes <- patterns[(index + seq_along(samples) - 1L) %% 4L + 1L]
  allele_count <- sum(vapply(
    strsplit(genotypes, "|", fixed = TRUE),
    function(value) sum(as.integer(value)),
    integer(1L)
  ))
  symbolic <- index == 24L
  writer$writeline(paste(
    "chr11",
    position,
    if (symbolic) "symbolic" else paste0("v", index + 1L),
    "A",
    if (symbolic) "<DEL>" else "C",
    ".",
    "PASS",
    paste0(
      "AC=",
      allele_count,
      ";AN=16",
      if (symbolic) ";SVTYPE=DEL" else ""
    ),
    "GT",
    paste(genotypes, collapse = "\t"),
    sep = "\t"
  ))
}
writer$close()

connection <- Rduckhts::rduckhts_connect()
Rduckhts::rduckhts_bcf_index(connection, reference, threads = 1L)
DBI::dbDisconnect(connection, shutdown = TRUE)

writeLines(
  c("pos chr cM", "900 chr11 0", "1600 chr11 0.01"),
  file.path(output_root, "genetic-map.txt"),
  useBytes = TRUE
)

write_alignment <- function(stem, symbolic_base) {
  sequence <- rep("A", 100L)
  sequence[[50L]] <- symbolic_base
  sequence <- paste(sequence, collapse = "")
  sam <- file.path(output_root, paste0(stem, ".sam"))
  bam <- file.path(output_root, paste0(stem, ".bam"))
  records <- vapply(
    seq_len(8L),
    function(index) paste(
      paste0(stem, "-", index),
      0L,
      "chr11",
      1191L,
      60L,
      "100M",
      "*",
      0L,
      0L,
      sequence,
      paste(rep("I", 100L), collapse = ""),
      sep = "\t"
    ),
    character(1L)
  )
  writeLines(
    c(
      "@HD\tVN:1.6\tSO:coordinate",
      "@SQ\tSN:chr11\tLN:10000",
      records
    ),
    sam,
    useBytes = TRUE
  )
  converted <- processx::run(
    samtools,
    c("view", "-b", "-o", bam, sam),
    error_on_status = FALSE,
    echo = FALSE
  )
  if (converted$status != 0L) {
    stop("samtools view failed: ", paste(converted$stderr, collapse = "\n"))
  }
  indexed <- processx::run(
    samtools,
    c("index", bam, paste0(bam, ".bai")),
    error_on_status = FALSE,
    echo = FALSE
  )
  if (indexed$status != 0L) {
    stop("samtools index failed: ", paste(indexed$stderr, collapse = "\n"))
  }
  unlink(sam)
}

write_alignment("symbolic-ref-read", "A")
write_alignment("symbolic-alt-read", "C")

writeLines(
  c(
    "# Direct-BAM symbolic-reference conformance fixture",
    "",
    "This synthetic fixture contains 50 phased biallelic reference records.",
    "Record `symbolic` has ALT `<DEL>` and is surrounded by ordinary SNPs.",
    "The two indexed BAMs are identical except for their bases at the symbolic",
    "record. A fixed-seed direct-BAM phase run must retain that record and return",
    "the same imputed result from both BAMs because read likelihoods at",
    "non-observable symbolic alleles are flat.",
    "",
    "Regenerate with:",
    "",
    "```sh",
    "Rscript tools/create-symbolic-bam-fixture.R /absolute/path/to/samtools",
    "```"
  ),
  file.path(output_root, "README.md"),
  useBytes = TRUE
)

message("Generated symbolic direct-BAM fixture in ", output_root)
