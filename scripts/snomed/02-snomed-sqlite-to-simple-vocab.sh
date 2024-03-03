#!/bin/bash

set -e

DB_FILE=vocab.db

sqlite3 "$DB_FILE" <<SQL
CREATE TABLE Concepts (
    ConceptID TEXT PRIMARY KEY,
    ActiveFlag BOOLEAN NOT NULL,
    PrimaryDesignation TEXT NOT NULL
);

CREATE TABLE Relationships (
    SourceConceptID TEXT NOT NULL,
    Property TEXT NOT NULL,
    TargetConceptID Text,
    TargetValue TEXT,
    FOREIGN KEY (SourceConceptID) REFERENCES Concepts(ConceptID),
    FOREIGN KEY (TargetConceptID) REFERENCES Concepts(ConceptID)
);

CREATE INDEX idx_relationships_source_property ON Relationships(SourceConceptID, Property);
CREATE INDEX idx_relationships_target ON Relationships(TargetConceptID);

-- Attach the SNOMED CT database to the current session
ATTACH DATABASE 'snomed.db' AS snomed;

INSERT INTO Concepts (ConceptID, ActiveFlag, PrimaryDesignation)
SELECT c.id, c.active, d.term
FROM snomed.Concept AS c
JOIN snomed.Description AS d ON c.id = d.conceptId
WHERE c.active = 1
AND d.active = 1
AND d.languageCode = 'en'
AND d.typeId = '900000000000003001'; -- Selecting fully specified names

INSERT INTO Relationships (SourceConceptID, Property, TargetConceptID)
SELECT r.sourceId, r.typeId, r.destinationId
FROM snomed.Relationship AS r
WHERE r.active = 1;

-- Insert relationships with a concrete value
INSERT INTO Relationships (SourceConceptID, Property, TargetValue)
SELECT cv.sourceId, cv.typeId, cv.value
FROM snomed.ConcreteValue AS cv
WHERE cv.active = 1;

-- Detach the SNOMED CT database
DETACH DATABASE snomed;

CREATE VIEW Hierarchy AS
WITH RECURSIVE TransitiveClosure(Ancestor, Descendant) AS (
    SELECT TargetConceptID, SourceConceptID
    FROM Relationships
    WHERE Property = '116680003'
    UNION
    SELECT tc.Ancestor, r.SourceConceptID
    FROM TransitiveClosure tc
    JOIN Relationships r ON tc.Descendant = r.TargetConceptID
    WHERE r.Property = '116680003'
)
SELECT DISTINCT Ancestor, Descendant FROM TransitiveClosure
/* Hierarchy(Ancestor,Descendant) */;


-- Create a materialized view (as a table)
CREATE TABLE MaterializedHierarchy AS
SELECT * FROM Hierarchy;
CREATE INDEX idx_materialized_ancestor ON MaterializedHierarchy(Ancestor);
CREATE INDEX idx_materialized_descendant ON MaterializedHierarchy(Descendant);

VACUUM;
SQL
echo "Created $DB_FILE"

sqlite3 $DB_FILE  <<SQL | gzip > $DB_FILE.dump.gz
BEGIN;
DROP TABLE MaterializedHierarchy;
.dump
ROLLBACK;
SQL
