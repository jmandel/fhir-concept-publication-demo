#!/bin/bash

set -e

SOURCE_DB=${SOURCE_DB:-./loinc.db}
OUTPUT_DB=${OUTPUT_DB:-./loinc-fhir.db}
NAME=${NAME:-loinc}
VERSION=${VERSION:-2.77}
FILENAME="CodeSystem-${NAME}-${VERSION}.ndjson.gz"

echo "Create from $SOURCE_DB: Version=${VERSION} CodeSystem=${NAME}"

# Create the output database if it doesn't exist
sqlite3 "$OUTPUT_DB" "CREATE TABLE IF NOT EXISTS concepts (
    code TEXT PRIMARY KEY,
    display TEXT,
    designations TEXT,
    properties TEXT
);"

sqlite3 "$SOURCE_DB" <<SQL
ATTACH DATABASE "$OUTPUT_DB" AS outputdb;
INSERT INTO outputdb.concepts WITH
concepts AS (
    SELECT
        LOINC_NUM AS code,
        LONG_COMMON_NAME AS display
    FROM Loinc
    UNION
    SELECT
        PartNumber AS code,
        PartDisplayName AS display
    FROM Part
    UNION
    SELECT
        CODE AS code,
        CODE_TEXT AS display
    FROM ComponentHierarchy h where h.CODE not in (SELECT PartNumber from Part union SELECT LOINC_NUM from Loinc)
    UNION
    SELECT
        AnswerListId AS code,
        AnswerListName AS display
    FROM AnswerList
    GROUP BY AnswerListId
    UNION
    SELECT
        AnswerStringId AS code,
        DisplayText AS display
    FROM AnswerList
    WHERE AnswerStringId != ''
    GROUP BY AnswerStringId
),
properties AS (select code, json_group_array(json(property)) as properties from (
    SELECT
        code,
        json_object(
            'code', propName,
            'valueString', '' || propValue
        ) AS property
    FROM (
        SELECT
            LOINC_NUM AS code,
            'CLASS' AS propName,
            CLASS AS propValue
        FROM Loinc
        UNION
        SELECT
            LOINC_NUM,
            'STATUS',
            STATUS
        FROM Loinc
        UNION
        SELECT
            LOINC_NUM,
            'CLASSTYPE',
            CLASSTYPE
        FROM Loinc
        UNION
        SELECT
            LOINC_NUM,
            'ORDER_OBS',
            ORDER_OBS
        FROM Loinc
    )
    WHERE propValue != ''
    UNION
    SELECT
        Loinc.LOINC_NUM AS code,
        json_object(
            'code', CASE
                WHEN LoincPartLink.PartTypeName = 'SCALE' THEN 'SCALE_TYP'
                WHEN LoincPartLink.PartTypeName = 'TIME' THEN 'TIME_ASPCT'
                WHEN LoincPartLink.PartTypeName = 'METHOD' THEN 'METHOD_TYP'
                ELSE LoincPartLink.PartTypeName
            END,
            'valueCode', LoincPartLink.PartNumber
        ) AS property
    FROM Loinc
    INNER JOIN LoincPartLink ON Loinc.LOINC_NUM = LoincPartLink.LoincNumber
    UNION
    SELECT DISTINCT
        Loinc.LOINC_NUM AS code,
        json_object(
            'code', 'ANSWER_LIST',
            'valueCode', LoincAnswerListLink.AnswerListId
        ) AS property
    FROM Loinc
    INNER JOIN LoincAnswerListLink ON Loinc.LOINC_NUM = LoincAnswerListLink.LoincNumber
    UNION
    select
        ComponentHierarchy.CODE as code,
        json_object(
            'code', 'parent',
            'valueCode', ComponentHierarchy.IMMEDIATE_PARENT
        ) AS property FROM ComponentHierarchy
        WHERE ComponentHierarchy.IMMEDIATE_PARENT IS NOT NULL AND
        ComponentHierarchy.IMMEDIATE_PARENT != ''
    UNION
    select
        ch.CODE as code,
        json_object(
            'code', 'ancestor',
            'valueCode', ancestors.value
        ) AS property from ComponentHierarchy ch
        cross join json_each('["' || replace(PATH_TO_ROOT, '.', '","') || '"]') as ancestors
    UNION
    SELECT
        Part.PartNumber AS code,
        json_object(
            'code', 'parent',
            'valueCode', ComponentHierarchy.IMMEDIATE_PARENT
        ) AS property
    FROM Part
    INNER JOIN ComponentHierarchy ON Part.PartNumber = ComponentHierarchy.CODE
    WHERE ComponentHierarchy.IMMEDIATE_PARENT IS NOT NULL
        AND ComponentHierarchy.IMMEDIATE_PARENT != ''
    UNION
    SELECT
        AnswerListId AS code,
        json_object('code', 'ANSWER', 'valueCode', AnswerStringID) AS property
    FROM AnswerList
) group by code),
designations AS (
    SELECT
        code,
        json_group_array(json(designation)) AS designations
    FROM (
        SELECT
            LOINC_NUM AS code,
            json_object('use', json_object('display', 'CONSUMER_NAME'), 'value', CONSUMER_NAME) AS designation
        FROM Loinc
        WHERE CONSUMER_NAME != ''
        UNION
        SELECT
            LOINC_NUM AS code,
            json_object('use', json_object('display', 'SHORTNAME'), 'value', SHORTNAME) AS designation
        FROM Loinc
        WHERE SHORTNAME != ''
    )
    GROUP BY code
),
final_combined AS (
    SELECT
        c.code,
        c.display,
        json(COALESCE(d.designations, '[]')) AS designations,
        json(COALESCE(p.properties, '[]')) AS properties
    FROM concepts c
    LEFT JOIN designations d ON d.code = c.code
    LEFT JOIN properties p ON p.code = c.code
    GROUP BY c.code, c.display, d.designations
)
SELECT
    code,
    display,
    json(COALESCE(designations, '[]')),
    json(COALESCE(properties, '[]'))
FROM final_combined;
DETACH DATABASE outputdb;
SQL

PROPERTY_CODES_JSON=$(sqlite3 "$OUTPUT_DB" "
WITH properties_unnested AS (
        SELECT json_extract(p.value, '$.code') AS code,
               json_extract(p.value, '$.valueString') AS valueString,
               json_extract(p.value, '$.valueCode') AS valueCode
        FROM concepts, json_each(concepts.properties) p
    )
    SELECT json_object('code', code, 'type', CASE
        WHEN valueString IS NOT NULL THEN 'string'
        ELSE 'code'
    END)
    FROM properties_unnested
    where code not null GROUP BY code 
" | jq -s)


echo "All Properties: " "$PROPERTY_CODES_JSON"

{

jq -c --argjson properties "$PROPERTY_CODES_JSON" '. + {property: $properties, version: "'$VERSION'"}' < templates/CodeSystem-${NAME}.json;

sqlite3 "$OUTPUT_DB" "
    SELECT json_object(
        'code', code,
        'display', display,
        'designation', json(designations),
        'property', json(properties))
    FROM concepts";
} | gzip > ${FILENAME}

# Generate the CodeSystem JSON
jq '. + {concept: $inputs} | del(.extension)' \
--slurpfile inputs <(zcat ${FILENAME} | tail -n +2) \
<(zcat ${FILENAME} | head -n 1) |
gzip  > CodeSystem-${NAME}-${VERSION}.json.gz

rm "$OUTPUT_DB"
