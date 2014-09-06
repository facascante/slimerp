DROP TABLE IF EXISTS tblPersonNationalities;
CREATE TABLE tblPersonNationalities(
    intPersonID int(11) default 0,
    strISONationality varchar(10) default '',
    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    dtAdded datetime,
    dtLastUpdated datetime,

  PRIMARY KEY  (intPersonID, strISONationality)
) DEFAULT CHARSET=utf8;
