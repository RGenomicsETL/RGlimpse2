rglimpse2_source_files <- function(repo_root) {
  source_directories <- c(
    "common/src",
    "chunk/src",
    "split_reference/src",
    "phase/src",
    "ligate/src",
    "third_party/simde/simde"
  )
  directory_files <- unlist(lapply(
    source_directories,
    function(path) {
      files <- list.files(
        file.path(repo_root, path),
        recursive = TRUE,
        full.names = FALSE,
        include.dirs = FALSE
      )
      file.path(path, files)
    }
  ), use.names = FALSE)
  sort(c(
    "common.mk",
    "LICENSE",
    "versions/versions.h",
    directory_files,
    "third_party/simde/COPYING",
    file.path(c("chunk", "split_reference", "phase", "ligate"), "makefile")
  ))
}
