DROP TABLE IF EXISTS tblEntityTypes ;
CREATE table tblEntityTypes (
    intEntityTypeID INT NOT NULL AUTO_INCREMENT,
    intEntityID INT DEFAULT 0,
    strSport VARCHAR(20) DEFAULT '', /*futsal, beach, football*/
    strPersonLevel varchar(10) DEFAULT '', /* pro/amateur */
    intGender TINYINT DEFAULT 0,

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,


PRIMARY KEY (intEntityTypeID),
KEY index_ID(intEntityID, strSport, strPersonLevel, intGender)
)DEFAULT CHARSET=utf8;
 
