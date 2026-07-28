#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (!length(script_arg)) stop("update-boost-source.R must be run with Rscript")
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]))
package_dir <- normalizePath(file.path(dirname(script), ".."))
tools_dir <- file.path(package_dir, "tools")
metadata_path <- file.path(tools_dir, "boost-source.json")
metadata <- paste(readLines(metadata_path, warn = FALSE), collapse = "\n")
metadata_value <- function(field) {
  pattern <- paste0('"', field, '"[[:space:]]*:[[:space:]]*"([^"]+)"')
  match <- regexec(pattern, metadata)
  value <- regmatches(metadata, match)[[1L]]
  if (length(value) != 2L) stop("missing Boost metadata field: ", field)
  value[[2L]]
}
metadata_array <- function(field) {
  pattern <- paste0('"', field, '"[[:space:]]*:[[:space:]]*\\[([^]]+)\\]')
  match <- regexec(pattern, metadata)
  value <- regmatches(metadata, match)[[1L]]
  if (length(value) != 2L) stop("missing Boost metadata array: ", field)
  quoted <- regmatches(value[[2L]], gregexpr('"[^"]+"', value[[2L]]))[[1L]]
  gsub('^"|"$', "", quoted)
}

bcp <- Sys.which("bcp")
if (!nzchar(bcp)) stop("bcp is required to update the Boost source closure")
bcp_version <- system2(bcp, "--version", stdout = TRUE, stderr = TRUE)
if (!any(grepl(metadata_value("bcp_version"), bcp_version, fixed = TRUE))) {
  stop("bcp version does not match boost-source.json")
}
source_archive <- tempfile(fileext = ".tar.gz")
work <- tempfile("rglimpse2-boost-update-")
dir.create(work)
on.exit(unlink(c(source_archive, work), recursive = TRUE, force = TRUE), add = TRUE)
cached_source <- Sys.getenv("RGLIMPSE2_BOOST_SOURCE_ARCHIVE", unset = "")
if (nzchar(cached_source)) {
  cached_source <- normalizePath(cached_source, mustWork = TRUE)
  if (!file.copy(cached_source, source_archive)) {
    stop("failed to copy RGLIMPSE2_BOOST_SOURCE_ARCHIVE")
  }
} else {
  utils::download.file(
    metadata_value("source_url"),
    source_archive,
    mode = "wb",
    quiet = FALSE
  )
}
observed_source_sha256 <- unname(tools::sha256sum(source_archive))
if (!identical(observed_source_sha256, metadata_value("source_sha256"))) {
  stop("downloaded Boost source SHA-256 does not match boost-source.json")
}
full <- file.path(work, "full")
bcp_output <- file.path(work, "bcp")
subset <- file.path(work, "subset")
dir.create(full)
dir.create(bcp_output)
dir.create(subset)
utils::untar(source_archive, exdir = full)
roots <- list.dirs(full, recursive = FALSE, full.names = TRUE)
if (length(roots) != 1L) stop("Boost source archive did not have one root directory")
status <- system2(
  bcp,
  c(
    paste0("--boost=", shQuote(roots[[1L]])),
    metadata_array("bcp_components"),
    shQuote(bcp_output)
  )
)
if (!identical(status, 0L)) stop("bcp failed with status ", status)
if (!dir.create(file.path(subset, "libs"))) stop("failed to create subset libs directory")
if (!file.copy(file.path(bcp_output, "boost"), subset, recursive = TRUE)) {
  stop("failed to copy bcp Boost header closure")
}
for (library in c("iostreams", "program_options", "serialization")) {
  destination <- file.path(subset, "libs", library)
  dir.create(destination)
  if (!file.copy(
    file.path(roots[[1L]], "libs", library, "src"),
    destination,
    recursive = TRUE
  )) {
    stop("failed to copy Boost ", library, " sources")
  }
}
if (!file.copy(file.path(roots[[1L]], "LICENSE_1_0.txt"), subset)) {
  stop("failed to copy Boost license")
}

files <- sort(
  list.files(subset, recursive = TRUE, full.names = FALSE),
  method = "radix"
)
files <- files[!dir.exists(file.path(subset, files))]
sha256 <- unname(tools::sha256sum(file.path(subset, files)))
writeLines(
  paste(sha256, paste0("./", files)),
  file.path(tools_dir, "boost-files.sha256"),
  useBytes = TRUE
)
archive <- file.path(tools_dir, "boost-source.tar.xz")
file_list <- file.path(work, "files.txt")
writeLines(paste0("./", files), file_list, useBytes = TRUE)
old <- setwd(subset)
on.exit(setwd(old), add = TRUE)
status <- system2(
  "tar",
  c(
    "--no-recursion",
    "--owner=0",
    "--group=0",
    "--numeric-owner",
    paste0("--mtime=", shQuote(metadata_value("archive_mtime"))),
    "-cJf",
    shQuote(archive),
    "-T",
    shQuote(file_list)
  )
)
if (!identical(status, 0L)) stop("tar failed with status ", status)
observed_archive_sha256 <- unname(tools::sha256sum(archive))
if (!identical(observed_archive_sha256, metadata_value("archive_sha256"))) {
  stop(
    "generated Boost archive SHA-256 differs from boost-source.json: ",
    observed_archive_sha256
  )
}
cat("Reproduced ", archive, " with ", length(files), " files.\n", sep = "")
