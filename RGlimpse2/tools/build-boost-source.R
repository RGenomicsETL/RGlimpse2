#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("usage: build-boost-source.R ARCHIVE BUILD_DIRECTORY")
}
archive <- normalizePath(args[[1L]], mustWork = TRUE)
build_dir <- normalizePath(args[[2L]], mustWork = FALSE)

r_config <- function(key, optional = FALSE) {
  value <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "config", key),
    stdout = TRUE,
    stderr = if (optional) FALSE else TRUE
  ))
  status <- attr(value, "status")
  if (!is.null(status) && status != 0L) {
    if (optional) return("")
    stop("R CMD config failed for ", key)
  }
  trimws(paste(value, collapse = " "))
}

split_command <- function(value, name) {
  fields <- strsplit(trimws(value), "[[:space:]]+")[[1L]]
  fields <- fields[nzchar(fields)]
  if (!length(fields)) stop(name, " is empty")
  list(command = fields[[1L]], arguments = fields[-1L])
}
split_flags <- function(value) {
  if (!nzchar(trimws(value))) return(character())
  strsplit(trimws(value), "[[:space:]]+")[[1L]]
}
run <- function(tool, arguments, description) {
  status <- system2(
    tool$command,
    c(tool$arguments, vapply(arguments, shQuote, character(1L))),
    stdout = "",
    stderr = ""
  )
  if (!identical(status, 0L)) stop(description, " failed with status ", status)
}

unlink(build_dir, recursive = TRUE, force = TRUE)
dir.create(build_dir, recursive = TRUE)
source_dir <- file.path(build_dir, "source")
dir.create(source_dir)
utils::untar(archive, exdir = source_dir)
if (!file.exists(file.path(source_dir, "boost", "version.hpp"))) {
  stop("Boost source archive did not provide boost/version.hpp")
}

cxx <- split_command(r_config("CXX17"), "CXX17")
ar <- split_command(r_config("AR"), "AR")
ranlib <- split_command(r_config("RANLIB"), "RANLIB")
compile_flags <- c(
  split_flags(r_config("CXX17STD")),
  split_flags(r_config("CXX17FLAGS")),
  split_flags(r_config("CPPFLAGS", optional = TRUE)),
  if (.Platform$OS.type != "windows") "-fPIC",
  "-DBOOST_ALL_NO_LIB=1",
  "-DBOOST_PROGRAM_OPTIONS_NO_LIB=1",
  "-DBOOST_IOSTREAMS_NO_LIB=1",
  "-DBOOST_IOSTREAMS_USE_DEPRECATED=1",
  paste0("-I", source_dir)
)

libraries <- c("iostreams", "program_options", "serialization")
lib_dir <- file.path(build_dir, "lib")
dir.create(lib_dir)
for (library in libraries) {
  library_source <- file.path(source_dir, "libs", library, "src")
  sources <- sort(list.files(
    library_source,
    pattern = "\\.cpp$",
    full.names = TRUE
  ))
  if (identical(library, "iostreams")) {
    required <- c("bzip2", "file_descriptor", "gzip", "mapped_file", "zlib")
    sources <- sources[
      tools::file_path_sans_ext(basename(sources)) %in% required
    ]
    if (!setequal(tools::file_path_sans_ext(basename(sources)), required)) {
      stop("pinned Boost iostreams sources are incomplete")
    }
  }
  if (!length(sources)) stop("no Boost source files found for ", library)
  object_dir <- file.path(build_dir, "obj", library)
  dir.create(object_dir, recursive = TRUE)
  objects <- file.path(
    object_dir,
    paste0(tools::file_path_sans_ext(basename(sources)), ".o")
  )
  for (index in seq_along(sources)) {
    run(
      cxx,
      c(compile_flags, "-c", sources[[index]], "-o", objects[[index]]),
      paste("compiling Boost", library, basename(sources[[index]]))
    )
  }
  output <- file.path(lib_dir, paste0("libboost_", library, ".a"))
  run(ar, c("rcs", output, objects), paste("archiving Boost", library))
  run(ranlib, output, paste("indexing Boost", library))
}

receipt <- c(
  "version=1.90.0",
  paste0("archive_sha256=", unname(tools::sha256sum(archive))),
  paste0("target_platform=", R.version$platform),
  paste0("target_arch=", R.version$arch)
)
writeLines(receipt, file.path(build_dir, "receipt.txt"), useBytes = TRUE)
cat("Built pinned Boost 1.90.0 static libraries for ", R.version$platform, ".\n", sep = "")
