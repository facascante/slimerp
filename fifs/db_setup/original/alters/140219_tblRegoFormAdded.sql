ALTER TABLE tblRegoFormAdded 
    ADD COLUMN ynPlayer        CHAR(1),
    ADD COLUMN ynCoach         CHAR(1),
    ADD COLUMN ynMatchOfficial CHAR(1),
    ADD COLUMN ynOfficial      CHAR(1),
    ADD COLUMN ynMisc          CHAR(1),
    ADD COLUMN ynVolunteer     CHAR(1),
    ADD COLUMN intAllowMultipleAdult TINYINT UNSIGNED DEFAULT 0,
    ADD COLUMN intAllowMultipleChild TINYINT UNSIGNED DEFAULT 0,
    ADD COLUMN intNewRegosAllowed    TINYINT UNSIGNED DEFAULT 0
;
