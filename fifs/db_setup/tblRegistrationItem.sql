DROP TABLE IF EXISTS tblRegistrationItem;

CREATE TABLE tblRegistrationItem (
    intItemID int(11) NOT NULL AUTO_INCREMENT,
    intRealmID int(11) NOT NULL DEFAULT '0',
    intSubRealmID int(11) NOT NULL DEFAULT '0',

    intOriginLevel INT DEFAULT 0, /* ORIGIN LEVEL (See Defs) of the record. 0 = ALL */
    strRuleFor VARCHAR(30) DEFAULT '' COMMENT 'REGO, ENTITY',

    strEntityType VARCHAR(30) DEFAULT '', /* School/Club -- Can even have School rules for a REGO*/
    intEntityLevel INT DEFAULT 0, /*Venue/Club*/

    strRegistrationNature varchar(20) NOT NULL DEFAULT '0' COMMENT 'NEW,RENEWAL,AMENDMENT,TRANSFER,',

    strPersonType varchar(20) NOT NULL DEFAULT '' COMMENT 'PLAYER, COACH, REFEREE',
    strPersonLevel varchar(20) NOT NULL DEFAULT '' COMMENT 'AMATEUR,PROFESSIONAL',
    strPersonEntityRole varchar(50) DEFAULT '', /* head coach, doctor etc */
    strSport varchar(20) NOT NULL DEFAULT '' COMMENT 'FOOTBALL,FUTSAL,BEACHSOCCER',
    strAgeLevel varchar(20) NOT NULL DEFAULT '' COMMENT 'SENIOR,JUNIOR',

    strItemType varchar(20) default '' COMMENT 'DOCUMENT (TYPE), PRODUCT',
    intID INT DEFAULT 0 COMMENT 'ID of strItemType',

    intUseExistingThisEntity TINYINT DEFAULT 0, /* An existing use of this ID is possible within this entity */
    intUseExistingAnyEntity TINYINT DEFAULT 0,/* An existing use of this ID is Ok against ANY entity */
    intPaymentRequired TINYINT DEFAULT 0 COMMENT '0=Optional, 1 =Required', /* Sets intPaymentRequired in tblPersonRego */
    intRequired TINYINT DEFAULT 0 COMMENT '0=Optional, 1 =Required',

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,


    PRIMARY KEY (intItemID),
    KEY index_Realms (intRealmID, intSubRealmID),
    KEY strRuleFor (strRuleFor)
) DEFAULT CHARSET=utf8;
