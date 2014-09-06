DROP TABLE IF EXISTS tblPaymentSplitRule;

CREATE TABLE tblPaymentSplitRule LIKE tblBankSplit;

INSERT INTO tblPaymentSplitRule SELECT * from tblBankSplit;

alter table tblPaymentSplitRule
    change intSplitID intRuleId int NOT NULL auto_increment,
    change strSplitName strRuleName varchar(100) default '',
    change strFILE_Header_FinInst strFinInst varchar(10) default '',
    change strFILE_Header_UserName strUserName varchar(30) default '',
    change strFILE_Header_UserNumber strUserNo varchar(30) default '',
    change strFILE_Header_Desc strFileDesc varchar(30) default '',
    change strFILE_Footer_BSB strBSB varchar(10) default '',
    change strFILE_Footer_AccountNum strAccountNo varchar(10) default '',
    change strFILE_Footer_Remitter strRemitter varchar(20) default '',
    change strFILE_Footer_RefPrefix strRefPrefix varchar(10) default '',
    add strTransCode char(3) NOT NULL default '';

update tblPaymentSplitRule
    set strTransCode = '50';
