CREATE TABLE tblPayment_Templates (
  intPaymentTemplateID  INT NOT NULL AUTO_INCREMENT,
    intRealmID          INT DEFAULT 0,
    intRealmSubTypeID   INT DEFAULT 0,
    intAssocID        INT DEFAULT 0,
    strSuccessTemplate TEXT default '',
    strErrorTemplate TEXT default '',
    strFailureTemplate TEXT default '',
    strHeaderHTML TEXT default '',
  tTimeStamp        	TIMESTAMP,

  PRIMARY KEY (intPaymentTemplateID),
  KEY index_realmIDs (intRealmID, intRealmSubTypeID)
);
