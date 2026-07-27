#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = FALSE)
script_argument <- grep("^--file=", arguments, value = TRUE)
if (length(script_argument) != 1L) stop("cannot determine script path")
script_path <- normalizePath(sub("^--file=", "", script_argument), mustWork = TRUE)
package_root <- dirname(dirname(script_path))
expected_root <- file.path(package_root, "inst", "tinytest", "tiny-imputation")
generator <- file.path(package_root, "tools", "create-tiny-imputation-targets.R")
generated_root <- tempfile("rglimpse2-tiny-imputation-")
on.exit(unlink(generated_root, recursive = TRUE, force = TRUE), add = TRUE)

status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(shQuote(generator), shQuote(generated_root)),
  stdout = TRUE,
  stderr = TRUE
)
if (!is.null(attr(status, "status")) && attr(status, "status") != 0L) {
  stop("tiny imputation target generation failed:\n", paste(status, collapse = "\n"))
}

relative_files <- function(root) {
  sort(list.files(root, recursive = TRUE, full.names = FALSE, include.dirs = FALSE))
}
expected_files <- relative_files(expected_root)
generated_files <- relative_files(generated_root)
if (!identical(expected_files, generated_files)) {
  stop("committed and regenerated tiny imputation file inventories differ")
}
expected_md5 <- unname(tools::md5sum(file.path(expected_root, expected_files)))
generated_md5 <- unname(tools::md5sum(file.path(generated_root, generated_files)))
if (!identical(expected_md5, generated_md5)) {
  different <- expected_files[expected_md5 != generated_md5]
  stop("tiny imputation target drift: ", paste(different, collapse = ", "))
}
message("Tiny imputation targets reproduce exactly (", length(expected_files), " files).")
