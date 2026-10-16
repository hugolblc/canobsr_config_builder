if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("Install testthat before running the tests.", call. = FALSE)
}

testthat::test_dir("scripts/tests/testthat")
