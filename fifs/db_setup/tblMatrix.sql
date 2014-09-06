CREATE TABLE `tblMatrix` (
    intMatrixID int NOT NULL AUTO_INCREMENT,
    intRealmID  INT DEFAULT 0,
    intSubRealmID  INT DEFAULT 0,
    intOfEntityLevel TINYINT DEFAULT 0, /* Level of entity being registered.. ie: OF type club/venue/person */
    intEntityLevel TINYINT DEFAULT 0, /* Entity Level Registerign TO */
    strWFRuleFor VARCHAR(30) DEFAULT '',
    strEntityType VARCHAR(30) DEFAULT '', /* School/club */
    strPersonType VARCHAR(30) DEFAULT '', /*/Player/COACH*/
    strPersonEntityRole varchar(50) DEFAULT '',
    strRegistrationNature VARCHAR(30) DEFAULT '',
    strPersonLevel varchar(10) DEFAULT '', /* pro, amateur */  
    strSport    VARCHAR(20) DEFAULT '',
    intOriginLevel INT DEFAULT 0, /* Self, club, Reg, MA */
    strAgeLevel VARCHAR(20) NOT NULL DEFAULT 'ALL', /* ALL,ADULT,MINOR */
    intPaymentRequired TINYINT DEFAULT 0,
    dtAdded date,

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (intMatrixID),
  KEY `index_intRealmID` (`intRealmID`, intSubRealmID),
  KEY `index_strWFRuleFor` (`strWFRuleFor`),
  KEY `index_intPersonType` (`strPersonType`)
) DEFAULT CHARSET=utf8;
