drop table tblAssoc;

# Table               : tblAssoc
# Description         : Association 
#----------------
# intAssocID          : Association Identifier 
# strName             : Full Name of Association
# strContact          : Primary Contact Person 
# strManager          : Manager's name 
# strSecretary        : Secretary's name 
# strPresident        : President's name 
# strAddress1         : Address 1 
# strAddress2         : Address 2 
# strAddress3         : Address 3 
# strSuburb           : Suburb
# strState            : State 
# strPostalCode       : Postcode 
# strPhone            : Phone Number 
# strFax              : Fax Number 
# strEmail            : Email address 
# dtRegistered        : Date Registered
#

CREATE TABLE tblAssoc (
  intAssocID int(11) NOT NULL auto_increment,
  strName varchar(150) NOT NULL default '',
  strContact varchar(50) default NULL,
  strManager varchar(50) default NULL,
  strSecretary varchar(50) default NULL,
  strPresident varchar(50) default NULL,
  strAddress1 varchar(50) default NULL,
  strAddress2 varchar(50) default NULL,
  strSuburb varchar(50) default NULL,
  strState varchar(50) default NULL,
  strCountry varchar(50) default NULL,
  strPostalCode varchar(15) default NULL,
  strPhone varchar(20) default NULL,
  strFax varchar(20) default NULL,
  strEmail varchar(200) NOT NULL default '',
  dtRegistered datetime default NULL,
  strAssocNo varchar(30) default '',
  intDataAccess int(11) NOT NULL default '2',
  intMemberAdd int(11) default '1',
  intMemberDelete int(11) default '1',
  intClubReport int(11) default '0',
  intParanoia int(11) default NULL,
	intDataOrigin SMALLINT DEFAULT 1, #1 => Sportzware upload, 2 => Web Entry
  intConfigGroupID INTEGER default 0 NOT NULL,
	intRealmID INTEGER NOT NULL DEFAULT 0,
	strFirstSyncCode varchar(30) default '',
	intAllowPayment int(11) default 0,
	intPaymentConfigID int(11) default 0,

  PRIMARY KEY  (intAssocID),
  KEY index_strName (strName),
	KEY index_intConfigGroupID (intConfigGroupID)
);

