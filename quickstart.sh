#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

OSRM_DIR="$HOME/osrm"
EXTRACT_FILENAME="addis-ababa.osm.pbf"
BBOX="38.65,8.95,38.85,9.15"
BASE="addis-ababa"
OSRM_BASE="${BASE}.osrm"
OSRM_IMAGE="osrm/osrm-backend:latest"

# Ensure the extract exists
if [ ! -f "$EXTRACT_FILENAME" ]; then
  echo "❌ Missing $EXTRACT_FILENAME. Please extract it first with:"
  echo "    osmium extract -b $BBOX -o $EXTRACT_FILENAME ethiopia-latest.osm.pbf"
  exit 1
fi

# Use area from CLI or fallback
if [ $# -eq 0 ]; then
  export area=addis-ababa
else
  export area=$1
fi

echo "Using Addis Ababa OSM extract: $EXTRACT_FILENAME"
echo "Area: $area"

# Optional: skip Docker image refresh, data downloads, and use local files
echo "Skipping image pulls and full planet/country downloads for bbox usage"

# Generate MBTiles setup
MBTILES_FILE="addis-ababa.mbtiles"
export MBTILES_FILE

echo " "
echo "====> : Remove old MBTiles file if exists ( ./data/$MBTILES_FILE ) "
rm -f "./data/$MBTILES_FILE"

echo " "
echo "====> : Clean previous build"
make clean

echo " "
echo "====> : Initialize directories"
make init-dirs

echo " "
echo "====> : Generate SQL, mappings, etc."
make all

echo " "
echo "====> : Start PostgreSQL (empty DB)"
make start-db
make import-data

echo " "
echo "====> : Import OSM PBF into PostGIS (Addis Ababa)"
make import-osm EXTRA_IMPORT_ARGS="--read-pbf $EXTRACT_FILENAME"

echo " "
echo "====> : Import Wikidata"
make import-wikidata

echo " "
echo "====> : Import SQL"
make import-sql

echo " "
echo "====> : Analyze DB"
make analyze-db

echo " "
echo "====> : Generate Tiles"
make generate-tiles-pg

echo " "
echo "====> : Done! MBTiles ready: ./data/$MBTILES_FILE"
