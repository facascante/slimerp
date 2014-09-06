ALTER TABLE tblRegoFormRulesAdded 
    ADD COLUMN ynVolunteer CHAR(1) NOT NULL DEFAULT 'N' AFTER ynMisc,
    DROP COLUMN intAssocID,
    DROP COLUMN intClubID
;
