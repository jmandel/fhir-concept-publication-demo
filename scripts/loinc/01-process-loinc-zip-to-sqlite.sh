#!/bin/bash

# Exit on any error
set -e

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <LOINC Zip Version> <LOINC Zip File Path>"
    exit 1
fi

# Assign command line arguments to variables
LOINC_VERSION="$1"
LOINC_ZIP_DIR="$2"
LOINC_DIR="Loinc_${LOINC_VERSION}"
DB_FILE="loinc.db"

# Define file paths
LOINC_CSV="$LOINC_DIR/LoincTable/Loinc.csv"
PART_CSV="$LOINC_DIR/AccessoryFiles/PartFile/Part.csv"
LOINC_PART_LINK_CSV="$LOINC_DIR/AccessoryFiles/PartFile/LoincPartLink_Primary.csv"
LOINC_ANSWER_LIST_LINK_CSV="$LOINC_DIR/AccessoryFiles/PanelsAndForms/LoincAnswerListLink.csv"
ANSWER_LIST_CSV="$LOINC_DIR/AccessoryFiles/PanelsAndForms/AnswerList.csv"
COMPONENT_HIERARCHY_CSV="$LOINC_DIR/AccessoryFiles/ComponentHierarchyBySystem/ComponentHierarchyBySystem.csv"
PANELS_AND_FORMS_CSV="$LOINC_DIR/AccessoryFiles/PanelsAndForms/PanelsAndForms.csv"

# Create a directory for the LOINC files if it doesn't exist
mkdir -p "$LOINC_DIR"

# Unzip the LOINC files
unzip -o "${LOINC_ZIP_DIR}/Loinc_${LOINC_VERSION}.zip" "LoincTable/Loinc.csv" "AccessoryFiles/PartFile/Part.csv" "AccessoryFiles/PartFile/LoincPartLink_Primary.csv" "AccessoryFiles/PanelsAndForms/AnswerList.csv" "AccessoryFiles/PanelsAndForms/LoincAnswerListLink.csv" "AccessoryFiles/ComponentHierarchyBySystem/ComponentHierarchyBySystem.csv" "AccessoryFiles/PanelsAndForms/PanelsAndForms.csv" -d "$LOINC_DIR"

sqlite3 "$DB_FILE" <<SQL
-- Create tables
CREATE TABLE Loinc (
    LOINC_NUM TEXT PRIMARY KEY,
    COMPONENT TEXT,
    PROPERTY TEXT,
    TIME_ASPCT TEXT,
    SYSTEM TEXT,
    SCALE_TYP TEXT,
    METHOD_TYP TEXT,
    CLASS TEXT,
    VersionLastChanged TEXT,
    CHNG_TYPE TEXT,
    DefinitionDescription TEXT,
    STATUS TEXT,
    CONSUMER_NAME TEXT,
    CLASSTYPE INTEGER,
    FORMULA TEXT,
    EXMPL_ANSWERS TEXT,
    SURVEY_QUEST_TEXT TEXT,
    SURVEY_QUEST_SRC TEXT,
    UNITSREQUIRED TEXT,
    RELATEDNAMES2 TEXT,
    SHORTNAME TEXT,
    ORDER_OBS TEXT,
    HL7_FIELD_SUBFIELD_ID TEXT,
    EXTERNAL_COPYRIGHT_NOTICE TEXT,
    EXAMPLE_UNITS TEXT,
    LONG_COMMON_NAME TEXT,
    EXAMPLE_UCUM_UNITS TEXT,
    STATUS_REASON TEXT,
    STATUS_TEXT TEXT,
    CHANGE_REASON_PUBLIC TEXT,
    COMMON_TEST_RANK INTEGER,
    COMMON_ORDER_RANK INTEGER,
    HL7_ATTACHMENT_STRUCTURE TEXT,
    EXTERNAL_COPYRIGHT_LINK TEXT,
    PanelType TEXT,
    AskAtOrderEntry TEXT,
    AssociatedObservations TEXT,
    VersionFirstReleased TEXT,
    ValidHL7AttachmentRequest TEXT,
    DisplayName TEXT
);

CREATE TABLE Part (
    PartNumber TEXT PRIMARY KEY,
    PartTypeName TEXT,
    PartName TEXT,
    PartDisplayName TEXT,
    Status TEXT
);

CREATE TABLE LoincAnswerListLink (
    LoincNumber TEXT,
    LongCommonName TEXT,
    AnswerListId TEXT,
    AnswerListName TEXT,
    AnswerListLinkType TEXT,
    ApplicableContext TEXT,
    PRIMARY KEY (LoincNumber, AnswerListId, ApplicableContext)
);

CREATE TABLE AnswerList (
    AnswerListId TEXT,
    AnswerListName TEXT,
    AnswerListOID TEXT,
    ExtDefinedYN TEXT,
    ExtDefinedAnswerListCodeSystem TEXT,
    ExtDefinedAnswerListLink TEXT,
    AnswerStringId TEXT,
    LocalAnswerCode TEXT,
    LocalAnswerCodeSystem TEXT,
    SequenceNumber TEXT,
    DisplayText TEXT,
    ExtCodeId TEXT,
    ExtCodeDisplayName TEXT,
    ExtCodeSystem TEXT,
    ExtCodeSystemVersion TEXT,
    ExtCodeSystemCopyrightNotice TEXT,
    SubsequentTextPrompt TEXT,
    Description TEXT,
    Score TEXT
);

CREATE TABLE LoincPartLink (
    LoincNumber TEXT,
    LongCommonName TEXT,
    PartNumber TEXT,
    PartName TEXT,
    PartCodeSystem TEXT,
    PartTypeName TEXT,
    LinkTypeName TEXT,
    Property TEXT,
    PRIMARY KEY (LoincNumber, PartNumber)
);

CREATE TABLE ComponentHierarchy (
    PATH_TO_ROOT TEXT,
    SEQUENCE INTEGER,
    IMMEDIATE_PARENT TEXT,
    CODE TEXT,
    CODE_TEXT TEXT
);

CREATE TABLE PanelsAndForms (
    ParentId TEXT,
    ParentLoinc TEXT,
    ParentName TEXT,
    ID TEXT,
    SEQUENCE INTEGER,
    Loinc TEXT,
    LoincName TEXT,
    DisplayNameForForm TEXT,
    ObservationRequiredInPanel TEXT,
    ObservationIdInForm TEXT,
    SkipLogicHelpText TEXT,
    DefaultValue TEXT,
    EntryType TEXT,
    DataTypeInForm TEXT,
    DataTypeSource TEXT,
    AnswerSequenceOverride TEXT,
    ConditionForInclusion TEXT,
    AllowableAlternative TEXT,
    ObservationCategory TEXT,
    Context TEXT,
    ConsistencyChecks TEXT,
    RelevanceEquation TEXT,
    CodingInstructions TEXT,
    QuestionCardinality TEXT,
    AnswerCardinality TEXT,
    AnswerListIdOverride TEXT,
    AnswerListTypeOverride TEXT,
    EXTERNAL_COPYRIGHT_NOTICE TEXT,
    AdditionalCopyright TEXT,
    PRIMARY KEY (ID, SEQUENCE)
);

-- Import data into SQLite
.mode csv
.import --skip 1 "$LOINC_CSV" Loinc
.import --skip 1 "$PART_CSV" Part
.import --skip 1 "$LOINC_PART_LINK_CSV" LoincPartLink
.import --skip 1 "$ANSWER_LIST_CSV" AnswerList
.import --skip 1 "$LOINC_ANSWER_LIST_LINK_CSV" LoincAnswerListLink
.import --skip 1 "$COMPONENT_HIERARCHY_CSV" ComponentHierarchy
.import --skip 1 "$PANELS_AND_FORMS_CSV" PanelsAndForms
VACUUM;
SQL

echo "LOINC data has been successfully imported into $DB_FILE";
