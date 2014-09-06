ALTER TABLE tblEOI 
ADD COLUMN intProgramID INT DEFAULT 0,
ADD COLUMN strP1FName varchar(50) DEFAULT NULL,
ADD COLUMN strP1SName varchar(50) DEFAULT NULL,
ADD COLUMN strP1Email varchar(250) DEFAULT NULL,
ADD COLUMN strP1Phone varchar(30) DEFAULT NULL,

ADD INDEX index_intProgramID (intProgramID);

