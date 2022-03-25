SOURCE_DB=${SOURCE_DB:-../rxnorm.db}
NAME=${NAME:-rxnorm}
VERSION=${VERSION:-03072022}
FILENAME="CodeSystem-${NAME}-${VERSION}.ndjson.gz"

# NDJSON_CID=$(ipfs add -q ${FILENAME})
# echo ".ndjzon CID $NDJSON_CID"

HOSTED_FILE_REF="https://raw.githubusercontent.com/jmandel/fhir-concept-publication-demo/main/${FILENAME}"
jq ". + {extension: [{url: \"https://tx.fhir.me/concepts-as-ndjson-gz\", valueUrl: \"${HOSTED_FILE_REF}\"}]}" \
<(zcat ${FILENAME}| head -n 1) \
> CodeSystem-${NAME}-${VERSION}-with-concept-link.json 

jq '. + {concepts: $inputs} | del(.extension)' \
--slurpfile inputs <(zcat ${FILENAME} | tail -n +2) \
<(zcat ${FILENAME} | head -n 1) |
gzip  > CodeSystem-${NAME}-${VERSION}.json.gz

# CID=$( ipfs add -q -r . | tail -n 1 )
# echo "Added ipfs://${CID}"
# echo "Browse at https://explore.ipld.io/#/explore/${CID}"
