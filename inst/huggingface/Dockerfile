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

RUN Rscript -e "remotes::install_github('PrigasG/explodemap@fbd647ff5a53a22cd7cec277e7f82a991898b4df', upgrade = 'never', force = TRUE)"

WORKDIR /app
ENV APP_DATA_DIR=/app/data

COPY app.R prep_data.R /app/

EXPOSE 7860
CMD ["R", "-q", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 7860)"]
