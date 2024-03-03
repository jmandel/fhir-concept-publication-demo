#!/bin/bash

set -e

SOURCE_DB=${SOURCE_DB:-./snomed.db}
NAME=${NAME:-snomed}
VERSION=${VERSION:-20230901}
FILENAME="CodeSystem-${NAME}-${VERSION}.ndjson.gz"

echo "Create from $SOURCE_DB: Version=${VERSION} CodeSystem=${NAME}"

PROPERTY_CODES=$(sqlite3 "$SOURCE_DB" <<SQL
SELECT json_group_array(json_object('code', typeId, 'type', propertyType))
FROM (
    SELECT typeId, 'code' AS propertyType FROM Relationship
    UNION
    SELECT typeId, 'string' AS propertyType FROM ConcreteValue
    UNION
    SELECT 'inactive' AS typeId, 'boolean' AS propertyType
);
SQL
)

# Prepare property codes for insertion into JSON
PROPERTY_CODES_JSON=$(echo $PROPERTY_CODES | jq '.')

# Modify the first row output by jq to include the distinct set of properties
{
jq -c --argjson properties "$PROPERTY_CODES_JSON" '. + {property: $properties, version: "'$VERSION'"}' < templates/CodeSystem-${NAME}.json;

sqlite3 "$SOURCE_DB" <<SQL
WITH 
concept_base AS (
    SELECT
        c.id AS code,
        d.term as display
    FROM Concept c join Description d
      on c.id=d.conceptID
    where d.active=1 and d.typeId='900000000000003001'
),
designation AS (
    SELECT 
        Description.conceptId AS code, 
        json_object(
            'language', Description.languageCode, 
            'value', Description.term, 
            'use', json_object('system', 'http://snomed.info/sct', 'code', Description.typeId)
        ) AS element
    FROM Description where active=1
),
designations_aggregated AS (
    SELECT
        code,
        json_group_array(json(element)) AS designations
    FROM designation
    GROUP BY code
),
property AS (
    SELECT 
        Relationship.sourceId AS code,
        json_object(
            'code', Relationship.typeId,
            'valueCode', Relationship.destinationId
        ) AS element
    FROM Relationship where active=1
    UNION ALL
    SELECT 
        ConcreteValue.sourceId, 
        json_object(
            'code', ConcreteValue.typeId,
            'valueString', ConcreteValue.value
        ) as element
    FROM ConcreteValue where active=1
    UNION ALL
    SELECT 
        Concept.id AS code,
        json_object(
            'code', 'inactive',
            'valueBoolean', json(CASE WHEN Concept.active THEN 'false' ELSE 'true' END)
        ) AS element
    FROM Concept
),
properties_aggregated AS (
    SELECT
        code,
        json_group_array(json(element)) AS properties
    FROM property
    GROUP BY code
),
combined AS (
    SELECT
        cb.code,
        cb.display,
        COALESCE(da.designations, NULL) AS designations,
        COALESCE(pa.properties, NULL) AS properties
    FROM concept_base cb
    LEFT JOIN designations_aggregated da ON cb.code = da.code
    LEFT JOIN properties_aggregated pa ON cb.code = pa.code
)
SELECT
    json(
        '{' ||
        '"code": "' || code || '"' ||
        ',"display": "' || display || '"' ||
        (CASE WHEN json(designations) NOT NULL THEN ', "designation": ' || json(designations) ELSE '' END) ||
        (CASE WHEN json(properties) NOT NULL THEN ', "property": ' || json(properties) ELSE '' END) ||
        '}'
    ) AS json_result
FROM combined;
SQL
} | gzip > ${FILENAME}
