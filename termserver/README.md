## Example invocation

```
$ ./prepare.sh

$ echo '{"url": "http://www.nlm.nih.gov/research/umls/rxnorm", "version": "03072022", "compose": {"include": [{"filter": [{"property": "tty", "op": "in", "value": "SBD,SCD,SCDG"}, {"property": "concept", "op": "is-a", "value": "1155862"}]}], "exclude": [{"filter": [{"property": "tty", "op": "=", "value": "SCDG"}]}]}}' | \

node valueset-to-sql.js


WITH
    cs0 AS ( select id from codesystem where url='http://www.nlm.nih.gov/research/umls/rxnorm' and version='03072022')
,
include1 AS ( SELECT distinct c.id from Concept c join CodeSystem cs on c.codesystem=cs.id and cs.id=(select id from cs0)
        join ConceptProperty cp0 on cp0.concept=c.id and cp0.value IN ('SBD', 'SCD', 'SCDG')
        join CodeSystemProperty p0 on p0.id=cp0.property and p0.name='tty'
        join ancestors a on a.child=c.id and a.adult IN (select id from Concept where code in ('1155862'))
        )
,
exclude2 AS ( SELECT distinct c.id from Concept c join CodeSystem cs on c.codesystem=cs.id and cs.id=(select id from cs0)
        join ConceptProperty cp0 on cp0.concept=c.id and cp0.value = 'SCDG'
        join CodeSystemProperty p0 on p0.id=cp0.property and p0.name='tty'
        )
select code from concept where id in (select * from include1
     EXCEPT select * from exclude2
)
```


Or, pipe the command above into `sqlite3 ./db.sqlite`:

```
197589
197590
197591
```
