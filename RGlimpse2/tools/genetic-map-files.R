rglimpse2_zero_map_spec <- function() {
  data.frame(
    assembly = c("GRCh37", "GRCh37", "GRCh38", "GRCh38"),
    chromosome = c("Y", "MT", "Y", "MT"),
    region = c("nonpar", "full", "nonpar", "full"),
    start_bp = c(2649521L, 1L, 2781480L, 1L),
    end_bp = c(59034049L, 16569L, 56887902L, 16569L),
    file = c(
      "genetic_maps.b37/chrY.b37.gmap.gz",
      "genetic_maps.b37/chrMT.b37.gmap.gz",
      "genetic_maps.b38/chrY.b38.gmap.gz",
      "genetic_maps.b38/chrMT.b38.gmap.gz"
    ),
    stringsAsFactors = FALSE
  )
}

rglimpse2_upstream_map_spec <- function(repo_root) {
  source_root <- file.path(repo_root, "maps")
  paths <- sort(list.files(
    source_root,
    pattern = "^chr.*\\.gmap\\.gz$",
    recursive = TRUE,
    full.names = FALSE
  ))
  matches <- regexec(
    "^genetic_maps\\.b(37|38)/chr(.+)\\.b(37|38)\\.gmap\\.gz$",
    paths
  )
  fields <- regmatches(paths, matches)
  valid <- lengths(fields) == 4L & vapply(
    fields,
    function(value) identical(value[[2L]], value[[4L]]),
    logical(1L)
  )
  if (!length(paths) || !all(valid)) {
    stop("upstream genetic-map paths do not match the expected layout")
  }

  token <- vapply(fields, `[[`, character(1L), 3L)
  chromosome <- token
  chromosome[grepl("^X_", token)] <- "X"
  region <- rep("full", length(paths))
  region[token == "X"] <- "nonpar"
  region[token == "X_par1"] <- "par1"
  region[token == "X_par2"] <- "par2"

  data.frame(
    assembly = paste0("GRCh", vapply(fields, `[[`, character(1L), 2L)),
    chromosome = chromosome,
    region = region,
    file = paths,
    stringsAsFactors = FALSE
  )
}

rglimpse2_read_map_ends <- function(path) {
  connection <- gzfile(path, open = "rt")
  on.exit(close(connection), add = TRUE)
  header <- strsplit(readLines(connection, n = 1L, warn = FALSE), "[[:space:]]+")[[1L]]
  if (!identical(header, c("pos", "chr", "cM"))) {
    stop("unexpected genetic-map header: ", path)
  }

  first <- character()
  last <- character()
  count <- 0L
  repeat {
    lines <- readLines(connection, n = 100000L, warn = FALSE)
    if (!length(lines)) break
    if (!length(first)) first <- lines[[1L]]
    last <- lines[[length(lines)]]
    count <- count + length(lines)
  }
  if (count < 2L) stop("genetic map has fewer than two entries: ", path)

  parse_entry <- function(line) {
    fields <- strsplit(line, "[[:space:]]+")[[1L]]
    if (length(fields) != 3L) stop("invalid genetic-map entry: ", path)
    values <- suppressWarnings(as.double(fields[c(1L, 3L)]))
    if (anyNA(values) || any(!is.finite(values))) {
      stop("non-numeric genetic-map entry: ", path)
    }
    values
  }
  list(first = parse_entry(first), last = parse_entry(last), entries = count)
}

rglimpse2_manifest <- function(package_root, repo_root) {
  upstream <- rglimpse2_upstream_map_spec(repo_root)
  zero <- rglimpse2_zero_map_spec()
  specification <- rbind(
    transform(upstream, kind = "empirical", source = "GLIMPSE-pinned-upstream"),
    transform(
      zero[c("assembly", "chromosome", "region", "file")],
      kind = "zero-recombination",
      source = "RGlimpse2-derived"
    )
  )
  specification <- specification[order(
    specification$assembly,
    match(specification$chromosome, c(as.character(1:22), "X", "Y", "MT")),
    match(specification$region, c("full", "nonpar", "par1", "par2"))
  ), , drop = FALSE]

  map_root <- file.path(package_root, "inst", "genetic_maps")
  ends <- lapply(file.path(map_root, specification$file), rglimpse2_read_map_ends)
  specification$start_bp <- as.integer(vapply(ends, function(value) value$first[[1L]], double(1L)))
  specification$end_bp <- as.integer(vapply(ends, function(value) value$last[[1L]], double(1L)))
  specification$start_cm <- vapply(ends, function(value) value$first[[2L]], double(1L))
  specification$end_cm <- vapply(ends, function(value) value$last[[2L]], double(1L))
  specification$entries <- as.integer(vapply(ends, `[[`, integer(1L), "entries"))
  specification$md5 <- unname(tools::md5sum(file.path(map_root, specification$file)))
  rownames(specification) <- NULL
  specification[c(
    "assembly", "chromosome", "region", "kind", "start_bp", "end_bp",
    "start_cm", "end_cm", "entries", "file", "source", "md5"
  )]
}

rglimpse2_write_zero_map <- function(path, chromosome, start_bp, end_bp) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  connection <- gzfile(path, open = "wb", compression = 9L)
  on.exit(close(connection), add = TRUE)
  writeLines(
    c(
      "pos\tchr\tcM",
      paste(start_bp, chromosome, "0", sep = "\t"),
      paste(end_bp, chromosome, "0", sep = "\t")
    ),
    connection,
    sep = "\n",
    useBytes = TRUE
  )
}

rglimpse2_update_genetic_maps <- function(repo_root, package_root) {
  map_root <- file.path(package_root, "inst", "genetic_maps")
  upstream <- rglimpse2_upstream_map_spec(repo_root)
  expected_directories <- unique(dirname(upstream$file))
  for (directory in expected_directories) {
    dir.create(file.path(map_root, directory), recursive = TRUE, showWarnings = FALSE)
  }
  copied <- file.copy(
    file.path(repo_root, "maps", upstream$file),
    file.path(map_root, upstream$file),
    overwrite = TRUE,
    copy.mode = TRUE,
    copy.date = FALSE
  )
  if (!all(copied)) stop("failed to copy one or more pinned upstream maps")

  zero <- rglimpse2_zero_map_spec()
  for (index in seq_len(nrow(zero))) {
    rglimpse2_write_zero_map(
      file.path(map_root, zero$file[[index]]),
      zero$chromosome[[index]],
      zero$start_bp[[index]],
      zero$end_bp[[index]]
    )
  }

  manifest <- rglimpse2_manifest(package_root, repo_root)
  write.table(
    manifest,
    file.path(map_root, "manifest.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE,
    na = ""
  )
  invisible(manifest)
}

rglimpse2_check_genetic_maps <- function(repo_root, package_root) {
  map_root <- file.path(package_root, "inst", "genetic_maps")
  upstream <- rglimpse2_upstream_map_spec(repo_root)
  zero <- rglimpse2_zero_map_spec()
  expected <- sort(c(upstream$file, zero$file))
  observed <- sort(list.files(
    map_root,
    pattern = "\\.gmap\\.gz$",
    recursive = TRUE,
    full.names = FALSE
  ))
  if (!identical(observed, expected)) {
    stop("packaged genetic-map files do not match the expected inventory")
  }

  source_md5 <- unname(tools::md5sum(file.path(repo_root, "maps", upstream$file)))
  package_md5 <- unname(tools::md5sum(file.path(map_root, upstream$file)))
  if (!identical(source_md5, package_md5)) {
    stop("one or more packaged upstream maps differ from the pinned source")
  }

  for (index in seq_len(nrow(zero))) {
    connection <- gzfile(file.path(map_root, zero$file[[index]]), open = "rt")
    lines <- readLines(connection, warn = FALSE)
    close(connection)
    expected_lines <- c(
      "pos\tchr\tcM",
      paste(zero$start_bp[[index]], zero$chromosome[[index]], "0", sep = "\t"),
      paste(zero$end_bp[[index]], zero$chromosome[[index]], "0", sep = "\t")
    )
    if (!identical(lines, expected_lines)) {
      stop("derived zero-recombination map differs from its specification: ", zero$file[[index]])
    }
  }

  expected_manifest <- rglimpse2_manifest(package_root, repo_root)
  observed_manifest <- read.delim(
    file.path(map_root, "manifest.tsv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (!identical(observed_manifest, expected_manifest)) {
    stop("packaged genetic-map manifest is stale")
  }
  invisible(expected_manifest)
}
