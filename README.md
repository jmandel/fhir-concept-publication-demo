# fhir-concept-publication-demo

Exploring publication formats for FHIR CodesSystems, using RxNorm Current Prescribable Drugs as an example.

The proposed publication pattern makes three files available for each CodeSystem, allowing for inclusion of designations, attributes, and relationships from source vocabularies.

* `CodeSystem.ndjson.gz` First line is a "shell" CodeSystem defining filters and properties; subsequent lines each encode a single Concept with `.designation` and `.property` array populated
  * Example: [CodeSystem-rxnorm-03072022.ndjson.gz](https://github.com/jmandel/fhir-concept-publication-demo/blob/main/CodeSystem-rxnorm-03072022.ndjson.gz )
* `CodeSystem-with-concept-link.json` "Shell" CodeSystem with an extension pointing to .ndjson.gz file from the previous bullet
  * Example: [CodeSystem-rxnorm-03072022-with-concept-link.json](https://github.com/jmandel/fhir-concept-publication-demo/blob/main/CodeSystem-rxnorm-03072022-with-concept-link.json)
* `CodeSystem.json.gz` Sinegle file with all concepts embedded in a bog-standard FHIR CodeSystem
  *  Example: [CodeSystem-rxnorm-03072022.json.gz](https://github.com/jmandel/fhir-concept-publication-demo/blob/main/CodeSystem-rxnorm-03072022.json.gz)
