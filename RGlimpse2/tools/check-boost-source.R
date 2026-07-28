#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (!length(script_arg)) stop("check-boost-source.R must be run with Rscript")
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]))
package_dir <- normalizePath(file.path(dirname(script), ".."))
archive <- file.path(package_dir, "tools", "boost-source.tar.xz")
manifest_path <- file.path(package_dir, "tools", "boost-files.sha256")
metadata_path <- file.path(package_dir, "tools", "boost-source.json")

if (!file.exists(archive)) stop("missing Boost source archive: ", archive)
if (!file.exists(manifest_path)) stop("missing Boost file manifest: ", manifest_path)
if (!file.exists(metadata_path)) stop("missing Boost source metadata: ", metadata_path)

metadata <- paste(readLines(metadata_path, warn = FALSE), collapse = "\n")
metadata_value <- function(field) {
  pattern <- paste0('"', field, '"[[:space:]]*:[[:space:]]*"([^"]+)"')
  match <- regexec(pattern, metadata)
  value <- regmatches(metadata, match)[[1L]]
  if (length(value) != 2L) stop("missing Boost metadata field: ", field)
  value[[2L]]
}
expected_archive_sha256 <- metadata_value("archive_sha256")
observed_archive_sha256 <- unname(tools::sha256sum(archive))
if (!identical(observed_archive_sha256, expected_archive_sha256)) {
  stop(
    "Boost source archive SHA-256 mismatch: expected ",
    expected_archive_sha256,
    ", observed ",
    observed_archive_sha256
  )
}

manifest_lines <- readLines(manifest_path, warn = FALSE)
parts <- regmatches(
  manifest_lines,
  regexec("^([0-9a-f]{64})[[:space:]]+\\./(.+)$", manifest_lines)
)
if (!length(parts) || any(lengths(parts) != 3L)) {
  stop("malformed Boost file manifest")
}
expected_sha256 <- vapply(parts, `[[`, character(1L), 2L)
expected_files <- vapply(parts, `[[`, character(1L), 3L)
if (anyDuplicated(expected_files)) stop("duplicate path in Boost file manifest")

extracted <- tempfile("rglimpse2-boost-audit-")
dir.create(extracted)
on.exit(unlink(extracted, recursive = TRUE, force = TRUE), add = TRUE)
utils::untar(archive, exdir = extracted)
observed_files <- sort(list.files(
  extracted,
  recursive = TRUE,
  full.names = FALSE,
  include.dirs = FALSE
))
if (!identical(sort(expected_files), observed_files)) {
  stop(
    "Boost source archive file-set drift; missing=[",
    paste(setdiff(expected_files, observed_files), collapse = ", "),
    "], extra=[",
    paste(setdiff(observed_files, expected_files), collapse = ", "),
    "]"
  )
}

observed_sha256 <- unname(tools::sha256sum(file.path(extracted, expected_files)))
different <- expected_files[observed_sha256 != expected_sha256]
if (length(different)) {
  stop("Boost source archive content drift: ", paste(different, collapse = ", "))
}
version_header <- readLines(
  file.path(extracted, "boost", "version.hpp"),
  warn = FALSE
)
if (!any(grepl('^#define BOOST_VERSION 109000$', version_header))) {
  stop("Boost source archive is not the declared 1.90.0 header set")
}
cat(
  "Pinned Boost 1.90.0 source archive matches ",
  length(expected_files),
  " files.\n",
  sep = ""
)
