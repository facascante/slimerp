DROP TABLE IF EXISTS tblPaymentSplitMyobExport;

CREATE TABLE tblPaymentSplitMyobExport (
  intMyobExportID int NOT NULL auto_increment,
  intPaymentType tinyint NOT NULL default 0,
  dtIncludeTo date,
  intTotalInvs int default 0,
  curTotalAmount decimal(10,2) default 0,
  dtRun datetime,
  PRIMARY KEY (intMyobExportID)
);
