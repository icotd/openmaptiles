#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# === Config ===
OSM_URL="https://download.geofabrik.de/africa/ethiopia-latest.osm.pbf"
DATA_DIR="data"
OSM_FILENAME="$DATA_DIR/$(basename "$OSM_URL")"     # data/ethiopia-latest.osm.pbf
EXTRACT_FILENAME="$DATA_DIR/addis-ababa.osm.pbf"
BBOX="38.65,8.95,38.85,9.15"
AREA="addis-ababa"
MBTILES_FILE="$AREA.mbtiles"

export MBTILES_FILE

# === Ensure data directory exists ===
mkdir -p "$DATA_DIR"

# === Download Ethiopia PBF if needed ===
if [ ! -f "$OSM_FILENAME" ]; then
  echo "📥 Downloading Ethiopia PBF to $OSM_FILENAME..."
  curl -L -o "$OSM_FILENAME" "$OSM_URL"
else
  echo "✅ Ethiopia PBF exists: $OSM_FILENAME"
fi

# === Extract Addis Ababa if not already ===
if [ ! -f "$EXTRACT_FILENAME" ]; then
  echo "🔍 Extracting Addis Ababa bbox to $EXTRACT_FILENAME"
  osmium extract -b "$BBOX" -o "$EXTRACT_FILENAME" "$OSM_FILENAME"
else
  echo "✅ Addis Ababa extract already exists: $EXTRACT_FILENAME"
fi

# === OpenMapTiles build steps ===
echo "🧹 Cleaning previous build"
make clean

echo "📁 Initializing directories"
make init-dirs

echo "⚙️ Generating config and SQL"
make all

echo "🐘 Starting PostgreSQL"
make start-db
make import-data

echo "🗺️ Importing Addis Ababa PBF"
make import-osm EXTRA_IMPORT_ARGS="--read-pbf $EXTRACT_FILENAME"

echo "📚 Importing Wikidata"
make import-wikidata

echo "🧠 Running SQL post-processing"
make import-sql

echo "📊 Analyzing DB"
make analyze-db

echo "🧱 Generating vector tiles (MBTiles)"
rm -f "./data/$MBTILES_FILE"
make generate-tiles-pg

echo "✅ Done! Vector tiles saved to ./data/$MBTILES_FILE"
