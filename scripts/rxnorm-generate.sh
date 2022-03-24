SOURCE_DB=${SOURCE_DB:-../rxnorm.db}
NAME=${NAME:-rxnorm}
VERSION=${VERSION:-03072022}
FILENAME="CodeSystem-${NAME}-${VERSION}.ndjson.gz"

echo "Create from $SOURCE_DB: Version=${VERSION} CodeSystem=${NAME}"

{
jq -c ". +  {version: \"$VERSION\"}" < templates/CodeSystem-${NAME}.json; 

sqlite3 $SOURCE_DB "
with
by_designation as (
    select rxcui, json_object('use', json_object('code', tty), 'value', str) designation, (case
        when tty = 'PSN' then 1
        when tty in ('SY', 'TMSY', 'DF', 'ET', 'DFG') then -1
        else 0
        end) priority
    from rxnconso where SAB='RXNORM' order by priority desc),
by_attr as (
    select rxcui, json_object('code', atn, 'valueString', atv) attribute
    from rxnsat where sab='RXNORM'),
by_rela as (
    select rxcui2 as rxcui, json_object('code', rela, 'valueCode', rxcui1) relation
    from rxnrel where sab='RXNORM' and stype1='CUI'),
by_prop as (
    select rxcui, json_object('code', 'tty', 'valueString', designation->>'use.code') as property from by_designation
    UNION
    select rxcui, attribute as property from by_attr
    UNION
    select rxcui, relation as property from by_rela
),
output_pass_1 as (
    select json_object(
        'code', c.rxcui,
        'display', c.designation->>'value',
        'designation', json_group_array(json(c.designation))) as concept
    from by_designation c
    group by c.rxcui),
output_pass_2 as (
    select json_object(
        'code', prev.concept->>'code',
        'display', prev.concept->'display',
        'designation', prev.concept->'designation',
        'property', json_group_array(json(by_prop.property))) as concept
    from output_pass_1 prev
    left join by_prop on prev.concept->>'code' = by_prop.rxcui
    group by prev.concept->>'code'
    )
select * from output_pass_2";
} | gzip > ${FILENAME}

