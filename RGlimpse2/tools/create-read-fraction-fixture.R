#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("usage: create-read-fraction-fixture.R /absolute/path/to/samtools")
}
samtools <- normalizePath(arguments[[1L]], mustWork = TRUE)
script <- grep("^--file=", commandArgs(), value = TRUE)
package_root <- dirname(dirname(normalizePath(sub("^--file=", "", script))))
output_root <- file.path(package_root, "inst", "tinytest", "tiny-read-fraction")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

records <- unlist(
  lapply(seq_len(8L), function(index) {
    position <- 1000L + (index - 1L) * 60L
    c(
      paste(
        paste0("pair", index),
        99L,
        "chr11",
        position,
        60L,
        "10M",
        "=",
        position + 20L,
        30L,
        "AAAAAAAAAA",
        "IIIIIIIIII",
        sep = "\t"
      ),
      paste(
        paste0("pair", index),
        147L,
        "chr11",
        position + 20L,
        60L,
        "10M",
        "=",
        position,
        -30L,
        "CCCCCCCCCC",
        "IIIIIIIIII",
        sep = "\t"
      )
    )
  }),
  use.names = FALSE
)
sam <- tempfile(fileext = ".sam")
writeLines(
  c(
    "@HD\tVN:1.6\tSO:coordinate",
    "@SQ\tSN:chr11\tLN:10000",
    records
  ),
  sam,
  useBytes = TRUE
)
full <- file.path(output_root, "pairs.bam")
processx::run(samtools, c("view", "--no-PG", "-b", "-o", full, sam))
processx::run(samtools, c("index", full))

for (fraction in c(0.25, 0.5, 0.75)) {
  bam <- file.path(output_root, paste0("pairs-0-", fraction, ".bam"))
  processx::run(
    samtools,
    c(
      "view",
      "--no-PG",
      "-b",
      "--subsample",
      as.character(fraction),
      "--subsample-seed",
      "0",
      "-o",
      bam,
      full
    )
  )
  processx::run(samtools, c("index", bam))
  selected <- processx::run(samtools, c("view", bam))$stdout
  message(
    basename(bam),
    ": ",
    paste(
      unique(sub("\t.*", "", strsplit(selected, "\n")[[1L]])),
      collapse = ", "
    )
  )
}

fasta <- file.path(output_root, "reference.fa")
writeLines(
  c(
    ">chr11",
    rep(paste(rep("A", 100L), collapse = ""), 100L)
  ),
  fasta,
  useBytes = TRUE
)
processx::run(samtools, c("faidx", fasta))
processx::run(
  samtools,
  c(
    "view",
    "--no-PG",
    "-C",
    "-T",
    fasta,
    "--output-fmt-option",
    "no_ref=1",
    "-o",
    file.path(output_root, "pairs.cram"),
    full
  )
)
processx::run(samtools, c("index", file.path(output_root, "pairs.cram")))
unlink(sam)
