# Use the Rocker image with R version
FROM rocker/shiny-verse:latest

# Install required Linux packages for rSharp
RUN apt-get update -qq && apt-get install -y \
  dotnet-runtime-8.0 libcurl4-openssl-dev libssl-dev libxml2-dev \
  libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
  libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev

# Install all the required CRAN packages
RUN R -e "install.packages(c('remotes', 'pak', 'shiny', 'bslib', 'DT', 'tidyverse', 'plotly'))"
# Install the OSPSuite echosystem
RUN R -e "pak::pak('Open-Systems-Pharmacology/rSharp')"
RUN R -e "remotes::install_github('Open-Systems-Pharmacology/OSPSuite-R@v12.1.0.9007')"

# Make a directory in the container
RUN mkdir /home/shiny-app


# Copy the Shiny app code
COPY shiny-ospsuite/app.R /home/shiny-app/app.R

# Expose the application port
EXPOSE 8180

# Run the R Shiny app
CMD Rscript /home/shiny-app/app.R
