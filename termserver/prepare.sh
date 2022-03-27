#!/bin/sh
gunzip -k ../CodeSystem-rxnorm-03072022.ndjson.gz
cat schema.sql  | sqlite3 db.sqlite;
cat load-rxnorm.sql  | sqlite3 db.sqlite
