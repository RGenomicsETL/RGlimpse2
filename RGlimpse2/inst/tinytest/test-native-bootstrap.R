bin <- system.file("glimpse2", "bin", package = "RGlimpse2")
expect_true(dir.exists(bin))

native_suffix <- if (identical(.Platform$OS.type, "windows")) ".exe" else ""
native_names <- paste0(c(
  "GLIMPSE2_chunk",
  "GLIMPSE2_split_reference",
  "GLIMPSE2_phase",
  "GLIMPSE2_ligate"
), native_suffix)
native_paths <- file.path(bin, native_names)
expect_true(all(file.exists(native_paths)))
expect_true(all(file.access(native_paths, 1L) == 0L))

run_capture <- function(executable, arguments = character()) {
  stdout <- tempfile("rglimpse2-native-stdout-")
  stderr <- tempfile("rglimpse2-native-stderr-")
  on.exit(unlink(c(stdout, stderr), force = TRUE), add = TRUE)
  process <- processx::run(
    command = executable,
    args = arguments,
    error_on_status = FALSE,
    echo = FALSE,
    stdout = stdout,
    stderr = stderr,
    cleanup_tree = TRUE,
    windows_hide_window = TRUE
  )
  list(
    status = as.integer(process$status),
    stdout = readLines(stdout, warn = FALSE),
    stderr = readLines(stderr, warn = FALSE)
  )
}

help_markers <- stats::setNames(
  c("--sequential", "--input-region", "--input-gl", "--input"),
  native_names
)
for (name in names(help_markers)) {
  result <- run_capture(file.path(bin, name), "--help")
  expect_identical(result$status, 0L)
  expect_true(any(grepl(
    help_markers[[name]],
    c(result$stdout, result$stderr),
    fixed = TRUE
  )))
}

htslib <- Rduckhts::rduckhts_htslib_config(validate = TRUE)
expect_identical(htslib$runtime_version, htslib$htslib_version)
packaged_htslib_version <- readLines(
  system.file("glimpse2", "htslib-version", package = "RGlimpse2"),
  warn = FALSE
)
expect_identical(packaged_htslib_version, htslib$htslib_version)

if (identical(Sys.info()[["sysname"]], "Linux") && file.exists("/usr/bin/ldd")) {
  expected_library <- normalizePath(htslib$library_file)
  phase_paths <- file.path(bin, paste0(c(
    "GLIMPSE2_phase",
    "GLIMPSE2_phase_avx2",
    "GLIMPSE2_phase_avx512",
    "GLIMPSE2_phase_neon"
  ), native_suffix))
  phase_paths <- phase_paths[file.exists(phase_paths)]
  for (phase_path in phase_paths) {
    linked <- run_capture("/usr/bin/ldd", phase_path)
    expect_identical(linked$status, 0L)
    expect_true(any(grepl(expected_library, linked$stdout, fixed = TRUE)))
  }
}
