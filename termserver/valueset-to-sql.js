/*
echo '{"url": "http://www.nlm.nih.gov/research/umls/rxnorm", "version": "03072022", "compose": {"include": [{"filter": [{"property": "tty", "op": "in", "value": "SBD,SCD"}]}], "exclude": [{"filter": [{"property": "tty", "op": "=", "value": "mpSBD"}]}]}}' | 
node valueset-to-sql.js | sqlite3 db.sqlite
*/
const fs = require("fs");
const vs = JSON.parse(fs.readFileSync(0).toString());

let _suffix = 0;
const suffix = () => _suffix++;

const processVs = (v, tempTableId) => `
    ${tempTableId} AS ( select id from codesystem where url='${v.url}' and version='${v.version}')
`;

const processClusion = (c, { table, csTable }) => {
  let propertyFilters = c.filter.filter(f => f.property !== 'concept');
  let propertyFilterClauses = propertyFilters.map(
    (f, i) => `
        join ConceptProperty cp${i} on cp${i}.concept=c.id and ${
      f.op === "="
        ? `cp${i}.value = '${f.value}'`
        : `cp${i}.value IN (${f.value
            .split(",")
            .map((v) => `'${v}'`)
            .join(", ")})`
    }
        join CodeSystemProperty p${i} on p${i}.id=cp${i}.property and p${i}.name='${
      f.property
    }'
    `
  );

  let conceptFilters = c.filter.filter(f => f.property === 'concept');
  let conceptFilterClauses = conceptFilters.map( (f, i) =>  {
      const isA = `join ancestors a on a.child=c.id and a.adult IN (select id from Concept where code in (${f.value.split(',').map(v=>`'${v}'`).join(', ')}))`
      if (f.op === "is-a" ) {
          return isA 
      }
      if (f.op === "descendant-of" ) {
          return isA + `
          and c.id NOT in (select id from Concept where code in (${f.value.split(',').map(v=>`'${v}'`).join(', ')}))`
      }

      const generalizes = `join ancestors a on a.adult=c.id and a.child IN (select id from Concept where code in (${f.value.split(',').map(v=>`'${v}'`).join(', ')}))`
      if (f.op === "generalizes" ) {
          return generalizes 
      }


    }
  );

 
  return `${table} AS ( SELECT distinct c.id from Concept c join CodeSystem cs on c.codesystem=cs.id and cs.id=(select id from ${csTable})
        ${propertyFilterClauses.join("\n")}
        ${conceptFilterClauses.join("\n")}
        )`;
};

const processFilterClause = (f) => `
        c.id in (select cp.concept from ConceptProperty )
`;

const csTable = `cs${suffix()}`;
const csQuery = processVs(vs, csTable);

const includeQueries = (vs.compose.include || []).map((inclusion) => {
  const table = `include${suffix()}`;
  return [processClusion(inclusion, { table, csTable }), table];
});

const excludeQueries = (vs.compose.exclude || []).map((exclusion) => {
  const table = `exclude${suffix()}`;
  return [processClusion(exclusion, { table, csTable }), table];
});

console.log("WITH");
console.log(csQuery);
console.log(",");
includeQueries.length > 0 &&
  console.log(includeQueries.map((q) => q[0]).join(", \n"));
excludeQueries.length > 0 && console.log(",");
console.log(excludeQueries.map((q) => q[0]).join(", \n"));

includeQueries.length && console.log(`${includeQueries
  .map((q) => `select code from concept where id in (select * from ${q[1]}`)
  .join(" UNION ")}`);

excludeQueries.length && console.log(`
     EXCEPT ${excludeQueries
       .map((q) => `select * from ${q[1]}`)
       .join(" UNION ")}
)`);