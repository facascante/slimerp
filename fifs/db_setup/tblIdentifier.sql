DROP TABLE IF EXISTS tblIdentifier;
CREATE TABLE tblIdentifier (
    intIdentifierID int(11) NOT NULL AUTO_INCREMENT,
    intEntityLevel tinyint default 0, /*Person, Entity*/
    intEntityID INT DEFAULT 0, /* ID of the Person, Entity */
    strIdentifier varchar(100) default '',
    strIDType varchar(30) default '', /*Define per MA ?? */
    strISOCountry varchar(10) default '',
    dtFrom date,
    dtTo date.
    strDescription varchar(200) default '',

    dtAdded datetime,

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (intEntityIdentifierID),
  KEY index_EntityIDType (intEntityID, strIDType)
) DEFAULT CHARSET=utf8;

