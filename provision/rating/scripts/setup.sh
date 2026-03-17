#!/bin/bash
set -e

# Variables recibidas como ENV desde la laptop
: ${RDSHOST:?  "RDSHOST no está definido"}
: ${RDSUSER:?  "RDSUSER no está definido"}
: ${RDSPASS:?  "RDSPASS no está definido"}
: ${RDSDB:?    "RDSDB no está definido"}

echo "Instalando dependencias..."
sudo apt update -y
sudo apt install -y postgresql-client unzip curl

echo "Corriendo setup.sql en $RDSHOST..."
PGPASSWORD=$RDSPASS psql \
  --host=$RDSHOST \
  --port=5432 \
  --username=$RDSUSER \
  --dbname=$RDSDB \
  --file=setup.sql

echo "Descargando dataset de MovieLens..."
curl -L -# -o movielens.zip \
  https://files.grouplens.org/datasets/movielens/ml-latest-small.zip
unzip -o movielens.zip

echo "Cargando movies..."
PGPASSWORD=$RDSPASS psql \
  --host=$RDSHOST \
  --port=5432 \
  --username=$RDSUSER \
  --dbname=$RDSDB \
  --command="\copy movies(movie_id, title, genres) FROM 'ml-latest-small/movies.csv' DELIMITER ',' CSV HEADER"

echo "Setup completado."
