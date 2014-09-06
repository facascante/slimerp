ALTER TABLE tblMember_Seasons_2
    ADD COLUMN intOfficialStatus          TINYINT DEFAULT 0 AFTER intUmpireFinancialStatus,
    ADD COLUMN intOfficialFinancialStatus TINYINT DEFAULT 0 AFTER intOfficialStatus,
    ADD COLUMN dtInOfficial               DATE              AFTER dtOutUmpire,
    ADD COLUMN dtOutOfficial              DATE              AFTER dtInOfficial
;
