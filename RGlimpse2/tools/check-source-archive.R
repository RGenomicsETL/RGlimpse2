#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (!length(script_arg)) stop("check-source-archive.R must be run with Rscript")
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]))
package_dir <- normalizePath(file.path(dirname(script), ".."))
repo_root <- normalizePath(file.path(package_dir, ".."))
archive <- file.path(package_dir, "tools", "glimpse2-source.tar.xz")
source(file.path(package_dir, "tools", "source-files.R"), local = TRUE)

if (!file.exists(archive)) stop("missing source archive: ", archive)
expected <- rglimpse2_source_files(repo_root)
extracted <- tempfile("rglimpse2-source-audit-")
dir.create(extracted)
on.exit(unlink(extracted, recursive = TRUE, force = TRUE), add = TRUE)
utils::untar(archive, exdir = extracted)
observed <- sort(list.files(
  extracted,
  recursive = TRUE,
  full.names = FALSE,
  include.dirs = FALSE
))

missing <- setdiff(expected, observed)
extra <- setdiff(observed, expected)
if (length(missing) || length(extra)) {
  stop(
    "source archive file-set drift; missing=[",
    paste(missing, collapse = ", "),
    "], extra=[",
    paste(extra, collapse = ", "),
    "]"
  )
}

read_raw <- function(path) {
  size <- file.info(path)$size
  readBin(path, what = "raw", n = as.integer(size))
}
different <- expected[!vapply(
  expected,
  function(path) {
    identical(
      read_raw(file.path(repo_root, path)),
      read_raw(file.path(extracted, path))
    )
  },
  logical(1L)
)]
if (length(different)) {
  stop("source archive content drift: ", paste(different, collapse = ", "))
}
cat("Pinned GLIMPSE2 source archive matches ", length(expected), " files.\n", sep = "")
