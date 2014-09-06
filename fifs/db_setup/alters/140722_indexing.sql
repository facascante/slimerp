ALTER TABLE tblEntity ADD INDEX `index_strFIFAID` (`strFIFAID`);
/*ALTER TABLE tblEntityRegistrationAllowed ADD INDEX `index_intRealmID` (`intRealmID`), ADD INDEX `index_intSubRealmID` (`intSubRealmID`);*/

ALTER TABLE tblWFRule ADD INDEX index_intRealmID (intRealmID, intSubRealmID);
ALTER TABLE tblWFTask ADD INDEX index_WFRule (intWFRuleID), ADD INDEX index_intRealmID (intRealmID, intSubRealmID);
ALTER TABLE tblWFTaskPreReq ADD INDEX index_WFRule (intWFRuleID);
