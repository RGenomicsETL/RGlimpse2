local({
  maps <- rglimpse2_genetic_maps()
  expect_true(is.data.frame(maps))
  expect_identical(nrow(maps), 54L)
  expect_identical(sum(maps$kind == "empirical"), 50L)
  expect_identical(sum(maps$kind == "zero-recombination"), 4L)
  expect_identical(sort(unique(maps$assembly)), c("GRCh37", "GRCh38"))
  expect_true(all(file.exists(maps$path)))
  expect_true(all(grepl("^(/|[A-Za-z]:[/\\\\])", maps$path)))
  expect_identical(length(unique(maps$path)), 54L)

  chr22 <- rglimpse2_genetic_map("GRCh38", "chr22")
  expect_identical(basename(chr22), "chr22.b38.gmap.gz")
  expect_identical(
    basename(rglimpse2_genetic_map("grch37", "X")),
    "chrX.b37.gmap.gz"
  )
  expect_identical(
    basename(rglimpse2_genetic_map("GRCh38", "X", "PAR-1")),
    "chrX_par1.b38.gmap.gz"
  )
  expect_identical(
    basename(rglimpse2_genetic_map("GRCh38", "X", "par_2")),
    "chrX_par2.b38.gmap.gz"
  )
  expect_identical(
    basename(rglimpse2_genetic_map("GRCh37", "Y")),
    "chrY_nonpar.b37.gmap.gz"
  )
  expect_identical(
    basename(rglimpse2_genetic_map("GRCh38", "Y")),
    "chrY_nonpar.b38.gmap.gz"
  )
  mt_aliases <- c("M", "MT", "chrM", "chrMT")
  expect_identical(
    unique(vapply(
      mt_aliases,
      function(alias) rglimpse2_genetic_map("GRCh37", alias),
      character(1L)
    )),
    rglimpse2_genetic_map("GRCh37", "MT")
  )
  expect_identical(
    basename(rglimpse2_genetic_map("GRCh38", "chrM")),
    "chrMT.b38.gmap.gz"
  )

  read_map <- function(path) {
    connection <- gzfile(path, open = "rt")
    on.exit(close(connection), add = TRUE)
    read.delim(connection, check.names = FALSE)
  }
  y37 <- read_map(rglimpse2_genetic_map("GRCh37", "Y"))
  expect_identical(y37$pos, c(2649521L, 59034049L))
  expect_identical(y37$cM, c(0L, 0L))
  y38 <- read_map(rglimpse2_genetic_map("GRCh38", "Y"))
  expect_identical(y38$pos, c(2781480L, 56887902L))
  expect_identical(y38$cM, c(0L, 0L))
  mt <- read_map(rglimpse2_genetic_map("GRCh38", "MT"))
  expect_identical(mt$pos, c(1L, 16569L))
  expect_identical(mt$cM, c(0L, 0L))

  capture_contract <- function(expression) {
    tryCatch(
      force(expression),
      rglimpse2_contract_violation = identity
    )
  }
  assembly_error <- capture_contract(rglimpse2_genetic_map("hg19", "1"))
  expect_identical(assembly_error$code, "unsupported_genetic_map_assembly")
  chromosome_error <- capture_contract(rglimpse2_genetic_map("GRCh38", "23"))
  expect_identical(
    chromosome_error$code,
    "unsupported_genetic_map_chromosome"
  )
  region_error <- capture_contract(rglimpse2_genetic_map("GRCh38", "X", "p"))
  expect_identical(region_error$code, "invalid_genetic_map_region")
  missing_error <- capture_contract(
    rglimpse2_genetic_map("GRCh38", "Y", "par1")
  )
  expect_identical(missing_error$code, "genetic_map_not_found")
  expect_identical(missing_error$details$available_regions, "nonpar")
})
