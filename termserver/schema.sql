create table CodeSystem (
    id integer primary key autoincrement,
    url string not null,
    version string not null,
    constraint unique_url_version unique (url, version)
);

create table CodeSystemProperty (
    id integer primary key autoincrement,
    codesystem integer not null,
    name string not null,
    type string not null,
    means_has_parent boolean,
    constraint unique_codesystem_prop_name unique(codesystem, name),
    foreign key(codesystem) references CodeSystem(id)
);

create table CodeSystemFilter (
    id integer primary key autoincrement,
    codesystem integer not null,
    name string not null,
    op string not null,
    constraint unique_codesystem_filter_name unique(codesystem, name, op),
    foreign key(codesystem) references CodeSystem(id)
);

create table Concept (
    id integer primary key autoincrement,
    codesystem integer not null,
    code string not null,
    constraint unique_concept_code unique(codesystem, code),
    foreign key(codesystem) references CodeSystem(id)
);

create table ConceptDesignation (
    id integer primary key autoincrement,
    concept integer not null,
    use string not null,
    value string not null,
    foreign key(concept) references Concept(id)
);

create table ConceptProperty(
    id integer primary key autoincrement,
    concept integer not null,
    property integer not null,
    value string not null,
    foreign key(concept) references Concept(id)
    foreign key(property) references CodeSystemProperty(id)
);


create index cs_id on CodeSystem(id);
create index csp_id on CodeSystemProperty(id);
create index csf_id on CodeSystemFilter(id);
create index c_id on Concept(id);
create index cp_cp on ConceptProperty(concept);
create index cp_id on ConceptProperty(id);
create index cp_prop_val on ConceptProperty(property, value);
