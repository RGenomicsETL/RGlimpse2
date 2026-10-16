if (grepl("wasm|emscripten", R.version$platform, ignore.case = TRUE)) {
  exit_file("GLIMPSE2 child processes are unavailable on WebAssembly")
}
if (!requireNamespace("vcfppR", quietly = TRUE)) {
  exit_file("vcfppR is required for native haplotype sample validation")
}

local({
  root <- tempfile("rglimpse2-haplotype-samples-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  data <- system.file("tinytest", "tiny-imputation", package = "RGlimpse2")
  manifest <- utils::read.delim(file.path(data, "manifest.tsv"))
  case <- manifest[manifest$id == "grch38_chr1", , drop = FALSE]
  expect_identical(nrow(case), 1L)
  executables <- rglimpse2_executables(phase_backend = "scalar")
  reference <- rglimpse2_split_reference(
    reference_bcf = file.path(data, case$reference),
    input_region = case$input_region,
    output_region = case$output_region,
    output_prefix = file.path(root, "reference"),
    executable = executables@split_reference,
    genetic_map = rglimpse2_genetic_map(case$assembly, case$contig),
    seed = 701L
  )
  expect_true(S7::S7_inherits(reference, RGlimpse2RunResult))

  read_output <- function(path) {
    reader <- vcfppR::vcfreader$new(path)
    records <- character()
    while (reader$variant()) records <- c(records, reader$line())
    list(header = paste(reader$header(), collapse = "\n"), records = records)
  }
  phase <- function(path, main, ploidy, enabled, executable = executables@phase) {
    rglimpse2_phase(
      input_gl = file.path(data, case$target),
      reference_bin = reference@outputs$reference_bin,
      output_bcf = path,
      executable = executable,
      seed = 702L,
      sample_ploidy = ploidy,
      burnin = 2L,
      main = main,
      pbwt_depth = 2L,
      k_init = 4L,
      k_pbwt = 4L,
      haplotype_samples = enabled
    )
  }
  mixed <- file.path(root, "mixed.txt")
  haploid <- file.path(root, "haploid.txt")
  writeLines(c("T1 1", "T2 2"), mixed)
  writeLines(c("T1 1", "T2 1"), haploid)
  for (ploidy in list(character(), mixed, haploid)) {
    for (main in c(1L, 15L)) {
      output <- tempfile(tmpdir = root, fileext = ".bcf")
      ordinary <- tempfile(tmpdir = root, fileext = ".bcf")
      expect_true(S7::S7_inherits(phase(output, main, ploidy, TRUE), RGlimpse2RunResult))
      expect_true(S7::S7_inherits(phase(ordinary, main, ploidy, FALSE), RGlimpse2RunResult))
      sampled <- read_output(output)
      baseline <- read_output(ordinary)
      expect_true(grepl("##FORMAT=<ID=HS,Number=1,Type=Integer", sampled$header, fixed = TRUE))
      expect_true(grepl(paste0("##NMAIN=", main), sampled$header, fixed = TRUE))
      expect_false(grepl("##FORMAT=<ID=HS", baseline$header, fixed = TRUE))
      expect_identical(length(sampled$records), length(baseline$records))
      packed <- matrix(0L, length(sampled$records), 2L)
      positions <- integer(length(sampled$records))
      scopes <- character(length(sampled$records))
      for (site in seq_along(sampled$records)) {
        fields <- strsplit(sampled$records[site], "\t", fixed = TRUE)[[1L]]
        expected <- strsplit(baseline$records[site], "\t", fixed = TRUE)[[1L]]
        expect_identical(fields[1:7], expected[1:7])
        expect_identical(sub(";HSC=[^;]+", "", fields[8L]), expected[8L])
        expect_identical(fields[9L], "GT:DS:GP:HS")
        positions[site] <- as.integer(fields[2L])
        scopes[site] <- sub(".*HSC=([^;]+).*", "\\1", fields[8L])
        for (sample in 1:2) {
          values <- strsplit(fields[9L + sample], ":", fixed = TRUE)[[1L]]
          expect_identical(paste(values[1:3], collapse = ":"), expected[9L + sample])
          packed[site, sample] <- as.integer(values[4L])
        }
      }
      expect_true(all(packed >= 0L & packed < 4^main))
      expect_identical(length(unique(scopes)), 1L)
      expect_true(grepl(paste0(case$input_region, ":"), scopes[1L], fixed = TRUE))
      # Consumer-facing list of actual 0/1 alleles on one ordered site axis.
      draws <- lapply(seq_len(main), function(draw) {
        state <- packed[, 1L] %/% 4^(draw - 1L) %% 4
        data.frame(position = positions, haplotype_1 = state %% 2, haplotype_2 = state %/% 2)
      })
      expect_identical(length(draws), main)
      expect_true(all(vapply(draws, function(draw) identical(draw$position, positions), logical(1L))))
      expect_true(all(unlist(lapply(draws, function(draw) draw[-1L])) %in% 0:1))
      if (length(ploidy) > 0L) {
        expect_true(all(vapply(draws, function(draw) all(draw$haplotype_2 == 0), logical(1L))))
      }
      if (identical(ploidy, haploid)) {
        expect_true(all(bitwAnd(packed[, 2L], 715827882L) == 0L))
      }
      input_list <- tempfile(tmpdir = root)
      writeLines(output, input_list)
      ligated <- tempfile(tmpdir = root, fileext = ".bcf")
      expect_true(S7::S7_inherits(rglimpse2_ligate(
        input_list, ligated, executables@ligate, seed = 703L
      ), RGlimpse2RunResult))
      expect_identical(read_output(ligated)$records, sampled$records)
    }
  }

  # SIMD uses the same actual draws, not only the same marginal GP.
  scalar <- tempfile(tmpdir = root, fileext = ".bcf")
  phase(scalar, 15L, character(), TRUE)
  for (backend in setdiff(rglimpse2_simd_info()@available_backends, "scalar")) {
    output <- tempfile(tmpdir = root, fileext = ".bcf")
    result <- phase(output, 15L, character(), TRUE, rglimpse2_executables(phase_backend = backend)@phase)
    expect_true(S7::S7_inherits(result, RGlimpse2RunResult))
    expect_identical(read_output(output)$records, read_output(scalar)$records)
  }

  # Unsupported export/checkpoint combinations fail before opening inputs.
  # The default checkpoint path still resumes the same scientific chain.
  checkpoint <- file.path(root, "default-checkpoint.bin")
  full <- file.path(root, "full.bcf")
  partial <- file.path(root, "partial.bcf")
  resumed <- file.path(root, "resumed.bcf")
  common <- c(
    "--input-gl", file.path(data, case$target),
    "--reference", reference@outputs$reference_bin,
    "--seed", "702", "--threads", "1", "--burnin", "2",
    "--pbwt-depth", "2", "--Kinit", "4", "--Kpbwt", "4"
  )
  processx::run(executables@phase, c(common, "--main", "4", "--output", full))
  processx::run(executables@phase, c(common, "--main", "3", "--output", partial, "--checkpoint-file-out", checkpoint))
  processx::run(executables@phase, c(common, "--main", "4", "--output", resumed, "--checkpoint-file-in", checkpoint))
  expect_identical(read_output(resumed)$records, read_output(full)$records)

  for (flag in c("--checkpoint-file-in", "--checkpoint-file-out")) {
    rejected <- processx::run(executables@phase, c(
      "--input-gl", "/absent/input.bcf", "--reference", "/absent/ref.bin",
      "--output", file.path(root, "rejected.bcf"), "--haplotype-samples",
      flag, file.path(root, "checkpoint.bin")
    ), error_on_status = FALSE)
    expect_true(rejected$status != 0L)
    expect_true(grepl("does not support checkpoint", paste(rejected$stdout, rejected$stderr), fixed = TRUE))
  }
  for (main in c(0L, 16L)) {
    rejected <- processx::run(executables@phase, c(
      "--input-gl", "/absent/input.bcf", "--reference", "/absent/ref.bin",
      "--output", file.path(root, "rejected.bcf"), "--haplotype-samples", "--main", as.character(main)
    ), error_on_status = FALSE)
    expect_true(rejected$status != 0L)
  }
  rejected <- processx::run(executables@phase, c(
    "--input-gl", "/absent/input.bcf", "--reference", "/absent/ref.bin",
    "--output", file.path(root, "rejected.bgen"), "--haplotype-samples"
  ), error_on_status = FALSE)
  expect_true(rejected$status != 0L)
  expect_true(grepl("requires VCF/BCF", paste(rejected$stdout, rejected$stderr), fixed = TRUE))
})
