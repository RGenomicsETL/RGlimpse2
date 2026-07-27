#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% c(2L, 3L)) {
  stop("usage: write-make-config.R OUTPUT BACKEND [HTSLIB_VERSION_OUTPUT]")
}
output <- args[[1L]]
backend <- match.arg(args[[2L]], c("scalar", "avx2", "avx512", "neon"))
version_output <- if (length(args) == 3L) args[[3L]] else character()

r_config <- function(key, optional = FALSE) {
  command <- file.path(R.home("bin"), "R")
  value <- suppressWarnings(system2(
    command,
    c("CMD", "config", key),
    stdout = TRUE,
    stderr = if (optional) FALSE else TRUE
  ))
  status <- attr(value, "status")
  if (!is.null(status) && status != 0L) {
    if (optional) {
      return("")
    }
    stop("R CMD config failed for ", key)
  }
  paste(value, collapse = " ")
}

htslib <- Rduckhts::rduckhts_htslib_config(validate = TRUE)
simde_include <- file.path(
  normalizePath(dirname(output), mustWork = TRUE),
  "third_party",
  "simde"
)
if (!file.exists(file.path(simde_include, "simde", "x86", "avx2.h"))) {
  stop("the pinned GLIMPSE2 source archive did not provide SIMDe headers")
}

multiarch <- if (file.exists("/usr/bin/dpkg-architecture")) {
  system2(
    "/usr/bin/dpkg-architecture",
    "-qDEB_HOST_MULTIARCH",
    stdout = TRUE,
    stderr = FALSE
  )
} else {
  character()
}
local_soft <- r_config("LOCAL_SOFT", optional = TRUE)
if (!nzchar(local_soft) || !dir.exists(local_soft)) local_soft <- character()
lib_dirs <- unique(c(
  file.path(local_soft, "lib"),
  "/opt/homebrew/lib",
  "/usr/local/lib",
  if (length(multiarch) && nzchar(multiarch[[1L]])) {
    file.path("/usr/lib", multiarch[[1L]])
  },
  "/usr/lib64",
  "/usr/lib"
))
lib_dirs <- lib_dirs[dir.exists(lib_dirs)]
include_dirs <- unique(c(
  file.path(local_soft, "include"),
  "/opt/homebrew/include",
  "/usr/local/include",
  "/usr/include"
))
include_dirs <- include_dirs[dir.exists(include_dirs)]
boost_include <- include_dirs[
  file.exists(file.path(include_dirs, "boost", "version.hpp"))
][1L]
if (is.na(boost_include)) stop("Boost headers were not found")

boost_library <- function(name) {
  exact <- c(
    paste0("libboost_", name, ".a"),
    paste0("libboost_", name, "-mt-x64.a"),
    paste0("libboost_", name, "-mt-a64.a"),
    paste0("libboost_", name, ".so"),
    paste0("libboost_", name, ".dylib")
  )
  candidates <- unlist(lapply(
    lib_dirs,
    function(directory) {
      discovered <- list.files(
        directory,
        pattern = paste0("^libboost_", name, ".*\\.(a|so|dylib)$"),
        full.names = TRUE
      )
      c(file.path(directory, exact), sort(discovered))
    }
  ), use.names = FALSE)
  candidates <- unique(candidates[file.exists(candidates)])
  if (!length(candidates)) stop("Boost library was not found: ", name)
  normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
}

make_escape <- function(value) {
  value <- gsub("$", "$$", value, fixed = TRUE)
  gsub("#", paste0(intToUtf8(92L), "#"), value, fixed = TRUE)
}
shell_path <- function(path) {
  shQuote(normalizePath(path, winslash = "/", mustWork = TRUE))
}

machine <- tolower(R.version$arch)
windows <- identical(.Platform$OS.type, "windows")
backend_flags <- switch(backend,
  scalar = "-DSIMDE_NO_NATIVE",
  avx2 = {
    if (!grepl("^(x86_64|amd64)$", machine)) {
      stop("AVX2 backend is only built for x86_64 targets")
    }
    "-mavx2"
  },
  avx512 = {
    if (!grepl("^(x86_64|amd64)$", machine)) {
      stop("AVX-512 backend is only built for x86_64 targets")
    }
    "-mavx512f -mavx512bw -mavx512vl"
  },
  neon = {
    if (grepl("^(aarch64|arm64)$", machine)) {
      ""
    } else if (grepl("^arm", machine)) {
      "-mfpu=neon"
    } else {
      stop("NEON backend is only built for ARM targets")
    }
  }
)

cxx_flags <- paste(
  r_config("CXX17STD"),
  r_config("CXX17FLAGS"),
  r_config("CPPFLAGS", optional = TRUE),
  paste(
    "-fno-fast-math -ffp-contract=off",
    "-Wno-ignored-attributes -Wno-psabi -Wno-reorder",
    "-Wno-range-loop-construct -Wno-parentheses -Wno-uninitialized"
  ),
  "-D__COMMIT_ID__=\\\"8671138\\\"",
  "-D__COMMIT_DATE__=\\\"2026-07-20\\\"",
  backend_flags
)

values <- c(
  CXX = r_config("CXX17"),
  EXEEXT = if (windows) ".exe" else "",
  CXXFLAG = cxx_flags,
  LDFLAG = paste(r_config("LDFLAGS", optional = TRUE), "-s"),
  HTSLIB_CPPFLAGS = htslib$cppflags,
  HTSLIB_LIB = htslib$ldflags,
  BOOST_CPPFLAGS = paste0("-I", shell_path(boost_include)),
  SIMDE_CPPFLAGS = paste0("-I", shell_path(simde_include)),
  BOOST_LIB_IO = shell_path(boost_library("iostreams")),
  BOOST_LIB_PO = shell_path(boost_library("program_options")),
  BOOST_LIB_SE = shell_path(boost_library("serialization")),
  DYN_LIBS = "-lz -lbz2 -lpthread"
)
lines <- paste(names(values), "=", vapply(values, make_escape, character(1L)))
writeLines(lines, output, useBytes = TRUE)
if (length(version_output)) {
  writeLines(htslib$htslib_version, version_output, useBytes = TRUE)
}
cat(
  "RGlimpse2 configure: backend=", backend,
  " htslib=", htslib$htslib_version,
  " link=", htslib$link,
  "\n",
  sep = ""
)
