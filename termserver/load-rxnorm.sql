CREATE TEMP TABLE incoming(jsline string);
.mode csv
.separator \r
.import ../CodeSystem-rxnorm-03072022.ndjson incoming
select count(*) from incoming;

insert into CodeSystem(url, version) select jsline->>"url", jsline->>"version" from incoming where rowid=1;
create temporary table this_cs(id integer);
insert into this_cs values(last_insert_rowid());

insert into CodeSystemProperty(codesystem, name, type)
select 
    (select id from temp.this_cs),
    p.value->>'code',
    p.value->>'type'
    from incoming i
    join json_each(jsline->>'property') p
    where i.rowid=1;

insert into CodeSystemFilter(codesystem, name, op)
select 
    (select id from temp.this_cs),
    p.value->>'code',
    p.value->>'operator'
    from incoming i
    join json_each(jsline->>'filter') p
    where i.rowid=1;

update CodeSystemProperty set means_has_parent=true where name in (
    select e.value->>'valueCode' from
        incoming i
        join json_tree(i.jsline->>'filter') t
        join json_each(t.value) e
        where i.rowid=1 and
        t.key='extension' and
        e.value->>'url'='https://tx.fhir.me/concept-property-for-has-parent')
    and codesystem in (select id from temp.this_cs);

insert into concept (codesystem, code)
select (select id from temp.this_cs) codesystem, i.jsline->>'code' code
from incoming i where i.rowid > 1;

insert into ConceptDesignation (concept, use, value)
select
    (select id from concept where codesystem=(select id from temp.this_cs) and code=i.jsline->>'code') concept,
    d.value->>'use.code' use,
    d.value->>'value' designation
    from incoming i
    join json_each(i.jsline->'designation') d
    where i.rowid > 1;

insert into ConceptProperty (concept, property, value)
select
    (select id from concept where codesystem=(select id from temp.this_cs) and code=i.jsline->>'code') concept,
    (select id from CodeSystemProperty where codesystem=(select id from temp.this_cs) and name=p.value->>'code') property,
    coalesce(p.value->>'valueCode',p.value->>'valueString') value
    from incoming i
    join json_each(i.jsline->'property') p
    where i.rowid > 1;

create table has_parent as select c.id as c1, parent_concept.id as c2 from ConceptProperty cp join CodeSystemProperty p on cp.property=p.id join Concept c on cp.concept=c.id and p.means_has_parent=1 join concept parent_concept on cp.value=parent_concept.code;
create index has_parent_c1 on has_parent(c1, c2);

CREATE VIEW ancestors AS
    WITH RECURSIVE
    ancestors(child, adult) as (
        select c.id as child, c.id as adult from concept c
            UNION
        select a.child as child, p.c2 as adult from ancestors a join has_parent p on p.c1=a.adult
    )
    select * from ancestors;
