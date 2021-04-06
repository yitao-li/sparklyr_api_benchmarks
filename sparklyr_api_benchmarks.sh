# === PREPARE SCRIPTS ===============================================
set -e

## Benchmarking script ----------------------------------------------
echo "
# options(sparklyr.dbplyr.edition = 1L)
# options(sparklyr.log.invoke = 'cat')
options(width = 150)
library(dplyr, warn.conflicts = FALSE, quietly = TRUE)
library(dbplyr, warn.conflicts = FALSE, quietly = TRUE)
library(sparklyr, warn.conflicts = FALSE, quietly = TRUE)
config <- spark_config()
# config[['sparklyr.dbplyr.edition']] = 1L
sc <- spark_connect('local', config = config)
flights <- copy_to(sc, df = nycflights13::flights, name = 'flights')
versions <- toString(invisible(lapply(
  sessionInfo()[['otherPkgs']],
  function(x) paste(x[['Package']], x[['Version']])
)))

message(paste('Microbenchmark for:', versions))

mb <- microbenchmark::microbenchmark(
  unit = 'ms',
  times = 20,
  sdf_register = {
    res <- flights %>%
      mutate(z = 26) %>%
      sdf_register()
  },
  spark_dataframe = {
    res <- flights %>%
      mutate(y = 25) %>%
      spark_dataframe()
  },
  mutate_one = {
    res <- flights %>%
      mutate(a = 1)
  },
  mutate_three = {
    res <- flights %>%
      mutate(a = 1) %>%
      mutate(b = 2) %>%
      mutate(c = 3)
  },
  mutate_seven = {
    res <- flights %>%
      mutate(a = 1) %>%
      mutate(b = 2) %>%
      mutate(c = 3) %>%
      mutate(d = 4) %>%
      mutate(e = 5) %>%
      mutate(f = 6) %>%
      mutate(g = 7)
  },
  filter = {
    res <- flights %>%
      dplyr::filter(year == 2013) %>%
      dplyr::filter(month == 1)
  },
  join = {
    res <- flights %>%
      select(-flight) %>%
      left_join(flights, by = 'origin') %>%
      left_join(flights, by = 'origin')
  },
  select = {
   res <- flights %>%
     select(flight, distance, arr_time, origin, dest) %>%
     select(flight, origin, dest) %>%
     select(dest)
 }
)
print(mb, signif = 3)
" > ./bench.R


## Install Latest package versions ----------------------------------
echo "
rp <- 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'
options(repos = rp, Ncpus = parallel::detectCores())
pkgs <- c(
  'remotes',
  'dplyr',
  'dbplyr',
  'tidyr',
  'sparklyr',
  'DBI',
  'nycflights13'
)
message('Installing packages: ', toString(pkgs))
install.packages(pkgs, quiet = TRUE)
" > ./upgrade.R


## Install Current DEV version of sparklyr from GitHub --------------
echo "
options(download.file.method = 'libcurl')
message('Installing sparklyr from GitHub')
remotes::install_github('sparklyr/sparklyr', quiet = TRUE)
" > ./devsparklyr.R


# === BENCHMARKS RUN ================================================

## Old versions -----------------------------------------------------
echo "\n\n===== Legacy package versions ====="
docker run --rm \
  -v $(pwd)/bench.R:/bench.R \
  jozefhajnala/jozefio \
  /bin/bash -c "set -e; Rscript /bench.R"

## Current CRAN -----------------------------------------------------
echo "\n\n===== Current CRAN package versions ====="
docker run --rm \
  -v $(pwd)/bench.R:/bench.R \
  -v $(pwd)/upgrade.R:/upgrade.R \
  jozefhajnala/jozefio \
  /bin/bash -c "set -e; Rscript /upgrade.R; Rscript /bench.R"

## Current CRAN + DEV sparklyr --------------------------------------
echo "\n\n===== Current CRAN package versions + DEV sparklyr ====="
docker run --rm \
  -v $(pwd)/bench.R:/bench.R \
  -v $(pwd)/upgrade.R:/upgrade.R \
  -v $(pwd)/devsparklyr.R:/devsparklyr.R \
  jozefhajnala/jozefio \
  /bin/bash -c "set -e; Rscript /upgrade.R; Rscript /devsparklyr.R; Rscript /bench.R"


# === CLEANUP =======================================================
rm ./bench.R
rm ./upgrade.R
rm ./devsparklyr.R
