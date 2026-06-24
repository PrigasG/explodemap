FROM rocker/geospatial:4.4.2

RUN install2.r --error --skipinstalled \
      shiny \
      bslib \
      dplyr \
      ggplot2 \
      htmlwidgets \
      purrr \
      rlang \
      sf \
      tigris \
      remotes \
      ggiraph \
 && rm -rf /tmp/downloaded_packages

RUN Rscript -e "options(repos = c(CRAN = 'https://cloud.r-project.org')); remotes::install_url('https://github.com/PrigasG/explodemap/archive/b9098103cc1f4e39b7bfba8a9f67b4f7453cfb7f.tar.gz', upgrade = 'never', force = TRUE); stopifnot(requireNamespace('explodemap', quietly = TRUE)); packageVersion('explodemap')"

WORKDIR /app
ENV APP_DATA_DIR=/app/data

COPY app.R prep_data.R /app/
COPY data/ /app/data/

EXPOSE 7860
CMD ["R", "-q", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 7860)"]
