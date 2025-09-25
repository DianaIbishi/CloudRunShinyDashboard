# Start from the rocker image with R + Shiny Server
FROM rocker/shiny-verse:latest

# System libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    build-essential git curl ca-certificates zstd p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# pak
RUN R -q -e 'install.packages("pak", repos="https://cloud.r-project.org")'

# R packages
RUN R -q -e 'pak::pkg_install(c( \
  "shiny","bslib","glue","here","shinycssloaders","shinyjs","shinychat","hover", \
  "DBI","duckdb", \
  "ellmer","ragnar" \
))'

# Shiny config + start script
COPY shiny-server.conf  /etc/shiny-server/shiny-server.conf
COPY shiny-server.sh    /usr/bin/shiny-server.sh
RUN chmod +x /usr/bin/shiny-server.sh

# **WICHTIG**: Sample-Apps entfernen und nur eigene App kopieren
RUN rm -rf /srv/shiny-server/*
COPY app /srv/shiny-server/app

# (Optional) Arbeitsverzeichnis setzen
WORKDIR /srv/shiny-server/app

# Port muss zu shiny-server.conf passen
EXPOSE 3838

# Als shiny laufen
USER shiny

# Start Shiny server
CMD ["/usr/bin/shiny-server.sh"]

