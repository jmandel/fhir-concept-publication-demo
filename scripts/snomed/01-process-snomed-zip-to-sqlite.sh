#!/bin/bash

# Exit on any error
set -e

# Define variables
SNOMED_LANGUAGE="en"
SNOMED_RELEASE="SnomedCT_ManagedServiceUS_PRODUCTION_US1000124_20230901T120000Z"
SNOMED_ZIP=~/Downloads/$SNOMED_RELEASE.zip
SNOMED_DIR=Snapshot
DB_FILE=snomed.db

# Extract the date part from the SNOMED release
RELEASE_DATE=$(echo $SNOMED_RELEASE | grep -oP '\d{8}')

# Extract the country code part from the SNOMED release
COUNTRY_CODE=$(echo $SNOMED_RELEASE | grep -oP 'US\d+')

# Filenames for the SNOMED CT RF2 files
CONCEPT_FILE="sct2_Concept_Snapshot_${COUNTRY_CODE}_${RELEASE_DATE}.txt"
RELATIONSHIP_FILE="sct2_Relationship_Snapshot_${COUNTRY_CODE}_${RELEASE_DATE}.txt"
DESCRIPTION_FILE="sct2_Description_Snapshot-${SNOMED_LANGUAGE}_${COUNTRY_CODE}_${RELEASE_DATE}.txt"
CONCRETE_VALUE_FILE="sct2_RelationshipConcreteValues_Snapshot_${COUNTRY_CODE}_${RELEASE_DATE}.txt"

# Create a directory for the Snapshot if it doesn't exist
mkdir -p "$SNOMED_DIR"

# Unzip only the needed files from the SNOMED CT release
unzip -l "$SNOMED_ZIP" "$SNOMED_RELEASE/$SNOMED_DIR/*" | grep 'sct2_.*\.txt' | awk '{print $4}' | while read -r file; do
    unzip -o -j "$SNOMED_ZIP" "$file" -d "$SNOMED_DIR"
done

# Pre-process the description file to escape double quotes
sed -i 's/"/\\"/g' "$SNOMED_DIR/$DESCRIPTION_FILE"

# Start SQLite3 and run the SQL commands
sqlite3 "$DB_FILE" <<SQL
-- Create tables
CREATE TABLE Concept (
    id TEXT,
    effectiveTime TEXT,
    active INTEGER,
    moduleId TEXT,
    definitionStatusId TEXT,
    PRIMARY KEY (id, effectiveTime)
);

CREATE TABLE Relationship (
    id TEXT,
    effectiveTime TEXT,
    active INTEGER,
    moduleId TEXT,
    sourceId TEXT,
    destinationId TEXT,
    relationshipGroup INTEGER,
    typeId TEXT,
    characteristicTypeId TEXT,
    modifierId TEXT,
    PRIMARY KEY (id, effectiveTime)
);

CREATE TABLE Description (
    id TEXT,
    effectiveTime TEXT,
    active INTEGER,
    moduleId TEXT,
    conceptId TEXT,
    languageCode TEXT,
    typeId TEXT,
    term TEXT,
    caseSignificanceId TEXT,
    PRIMARY KEY (id, effectiveTime)
);

-- New table for Concrete Values
CREATE TABLE ConcreteValue (
    id TEXT,
    effectiveTime TEXT,
    active INTEGER,
    moduleId TEXT,
    sourceId TEXT,
    value TEXT,
    relationshipGroup INTEGER,
    typeId TEXT,
    characteristicTypeId TEXT,
    modifierId TEXT,
    PRIMARY KEY (id, effectiveTime)
);

-- Import data into SQLite
.mode tabs
.import --skip 1 "$SNOMED_DIR/$CONCEPT_FILE" Concept
.import --skip 1 "$SNOMED_DIR/$RELATIONSHIP_FILE" Relationship
.import --skip 1 "$SNOMED_DIR/$DESCRIPTION_FILE" Description
.import --skip 1 "$SNOMED_DIR/$CONCRETE_VALUE_FILE" ConcreteValue
VACUUM;
SQL

echo ".dump" | sqlite3 $DB_FILE | gzip > $DB_FILE.dump.gz
echo "SNOMED data, including Concrete Values, has been successfully imported into snomed.sqlite";

