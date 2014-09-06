CREATE TABLE tblProgramTemplatesConfig (
    intProgramTemplatesConfigID  INT NOT NULL AUTO_INCREMENT,
    intProgramTemplateID         INT NOT NULL,
    strField       VARCHAR(55) NOT NULL,
    intReadonly    INT NOT NULL DEFAULT 0,
    intCompulsory  INT NOT NULL DEFAULT 0,
    intHidden      INT NOT NULL DEFAULT 0,

    PRIMARY KEY (intProgramTemplatesConfigID),
    KEY index_program_template (intProgramTemplateID)

);
