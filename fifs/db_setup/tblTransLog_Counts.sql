CREATE TABLE tblTransLog_Counts (
  intTLogID int(11) NOT NULL DEFAULT 0,
  dtLog datetime default NULL,
	strResponseCode varchar(10),
  KEY index_logID (intTLogID)
);
