FROM rocker/geospatial:4.4.2

RUN install2.r --error --skipinstalled \
      shiny \
      bslib \
      tigris \
      remotes \
      ggiraph \
 && rm -rf /tmp/downloaded_packages

ARG EXPLODEMAP_REF=fbd647f
RUN Rscript -e "remotes::install_github('PrigasG/explodemap@${EXPLODEMAP_REF}', upgrade = 'never', force = TRUE)"
RUN Rscript -e "library(explodemap); packageVersion('explodemap')"

WORKDIR /app
ENV APP_DATA_DIR=/app/data

COPY app.R prep_data.R /app/

RUN Rscript /app/prep_data.R

EXPOSE 7860
CMD ["R", "-q", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 7860)"]
