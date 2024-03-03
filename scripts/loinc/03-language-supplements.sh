#!/bin/bash

SOURCE_DIR=${SOURCE_DIR:-./AccessoryFiles/LinguisticVariants}
OUTPUT_DIR=${OUTPUT_DIR:-./loinc}
NAME=${NAME:-loinc}
VERSION=${VERSION:-2.77}

mkdir -p "$OUTPUT_DIR"

# List all LinguisticVariant.csv files in the SOURCE_DIR
FILES=$(find "$SOURCE_DIR" -type f -name "*LinguisticVariant.csv")

for FILE in $FILES; do
   # Extract language code and country code from the file name
   FILENAME=$(basename "$FILE")
   LANG=${FILENAME:0:5}
   ISO_LANGUAGE=${LANG:0:2}
   ISO_COUNTRY=${LANG:2:2}

   OUTPUT_FILENAME="CodeSystem-${NAME}-${VERSION}-${ISO_LANGUAGE}-${ISO_COUNTRY}"
   OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILENAME"

   echo "Generating $OUTPUT_PATH for language $ISO_LANGUAGE, country $ISO_COUNTRY"

   # Create an in-memory SQLite database
   {

    jq -c '. + {version: "'$VERSION'", content: "supplement"}' < templates/CodeSystem-${NAME}.json;

   sqlite3 :memory: <<SQL
.mode csv
.import "${FILE}" LinguisticVariants
.mode list

ATTACH 'loinc.db' AS loinc;
CREATE TABLE candidate_designations (
    part_number TEXT,
    candidate_designation TEXT,
    part_type_name TEXT
);

-- COMPONENT
INSERT INTO candidate_designations (part_number, candidate_designation, part_type_name)
SELECT lp.PartNumber, lv.COMPONENT, lp.PartTypeName
FROM loinc.LoincPartLink lp
JOIN LinguisticVariants lv ON lp.LoincNumber = lv.LOINC_NUM
WHERE lp.PartTypeName = 'COMPONENT';

-- PROPERTY
INSERT INTO candidate_designations (part_number, candidate_designation, part_type_name)
SELECT lp.PartNumber, lv.PROPERTY, lp.PartTypeName
FROM loinc.LoincPartLink lp
JOIN LinguisticVariants lv ON lp.LoincNumber = lv.LOINC_NUM
WHERE lp.PartTypeName = 'PROPERTY';

-- TIME
INSERT INTO candidate_designations (part_number, candidate_designation, part_type_name)
SELECT lp.PartNumber, lv.TIME_ASPCT, lp.PartTypeName
FROM loinc.LoincPartLink lp
JOIN LinguisticVariants lv ON lp.LoincNumber = lv.LOINC_NUM
WHERE lp.PartTypeName = 'TIME';

-- SYSTEM
INSERT INTO candidate_designations (part_number, candidate_designation, part_type_name)
SELECT lp.PartNumber, lv.SYSTEM, lp.PartTypeName
FROM loinc.LoincPartLink lp
JOIN LinguisticVariants lv ON lp.LoincNumber = lv.LOINC_NUM
WHERE lp.PartTypeName = 'SYSTEM';

-- SCALE
INSERT INTO candidate_designations (part_number, candidate_designation, part_type_name)
SELECT lp.PartNumber, lv.SCALE_TYP, lp.PartTypeName
FROM loinc.LoincPartLink lp
JOIN LinguisticVariants lv ON lp.LoincNumber = lv.LOINC_NUM
WHERE lp.PartTypeName = 'SCALE';

-- METHOD
INSERT INTO candidate_designations (part_number, candidate_designation, part_type_name)
SELECT lp.PartNumber, lv.METHOD_TYP, lp.PartTypeName
FROM loinc.LoincPartLink lp
JOIN LinguisticVariants lv ON lp.LoincNumber = lv.LOINC_NUM
WHERE lp.PartTypeName = 'METHOD';

DETACH DATABASE loinc;

SELECT
   json_object(
        'code', code,
        'language', '$ISO_LANGUAGE' || '-' || '$ISO_COUNTRY',
        'value',   value)
FROM (
    SELECT LOINC_NUM as code, 
        CASE
                WHEN LENGTH(TRIM(LinguisticVariantDisplayName)) > 0 THEN LinguisticVariantDisplayName
                WHEN LENGTH(TRIM(SHORTNAME)) > 0 THEN SHORTNAME
                ELSE LONG_COMMON_NAME
        END as VALUE
    FROM LinguisticVariants
    where value != ''
UNION
    SELECT
    part_number as CODE,
    candidate_designation as VALUE
    FROM candidate_designations
    where candidate_designation != ''
    GROUP BY part_number
);


SQL
    } | gzip > "${OUTPUT_PATH}.ndjson.gz"

    jq '. + {concept: $inputs} | del(.extension)' \
    --slurpfile inputs <(zcat "${OUTPUT_PATH}.ndjson.gz" | tail -n +2) \
    <(zcat "${OUTPUT_PATH}.ndjson.gz" | head -n 1) |
    gzip  > "${OUTPUT_PATH}.json.gz"

   echo "Successfully generated $OUTPUT_PATH"
done
