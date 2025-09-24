# Start from the rocker image with R + Shiny Server
FROM rocker/shiny-verse:latest

# Install system libraries needed for R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    build-essential git curl ca-certificates zstd p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# Install pak (modern R package manager)
RUN R -q -e 'install.packages("pak", repos="https://cloud.r-project.org")'

# Install your R package dependencies
RUN R -q -e 'pak::pkg_install(c( \
  "shiny","bslib","glue","here","shinycssloaders","shinyjs","shinychat","hover", \
  "DBI","duckdb", \
  "ellmer","ragnar" \
))'

# Copy Shiny server config and startup script
COPY shiny-server.conf  /etc/shiny-server/shiny-server.conf
COPY shiny-server.sh    /usr/bin/shiny-server.sh
RUN chmod +x /usr/bin/shiny-server.sh

# Copy your app (app_hf.R + df_law_fin.duckdb) into the image
COPY app /srv/shiny-server/

# Optional: decompress DB if you uploaded a compressed version instead
RUN if [ -f /srv/shiny-server/df_law_fin.duckdb.gz ]; then \
      gunzip -f /srv/shiny-server/df_law_fin.duckdb.gz; \
    fi

# Expose port 5000 (matches shiny-server.conf)
EXPOSE 5000

# Run as the shiny user (predefined in base image)
USER shiny

# Start Shiny server
CMD ["/usr/bin/shiny-server.sh"]

