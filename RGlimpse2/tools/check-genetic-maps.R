#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = FALSE)
script_argument <- grep("^--file=", arguments, value = TRUE)
if (length(script_argument) != 1L) stop("cannot determine script path")
script_path <- normalizePath(sub("^--file=", "", script_argument), mustWork = TRUE)
package_root <- dirname(dirname(script_path))
repo_root <- dirname(package_root)

source(file.path(package_root, "tools", "genetic-map-files.R"), local = TRUE)
manifest <- rglimpse2_check_genetic_maps(repo_root, package_root)
message("Packaged genetic-map inventory matches ", nrow(manifest), " declared maps.")
