drop table if exists tblPaymentConfig;
CREATE table tblPaymentConfig (
  	intPaymentConfigID      INT NOT NULL AUTO_INCREMENT, 
  	intLevelID  INT NOT NULL,
  	intEntityID INT NOT NULL,
	strCurrency CHAR(5) DEFAULT 'AUD',
	strClientCurrency CHAR(5) DEFAULT 'AUD',
  	intRealmID INT NOT NULL,
  	intRealmSubTypeID INT NOT NULL,

	intPaymentGatewayID INT NOT NULL,
	strSalt VARCHAR(50) NOT NULL,
	strGatewayURL VARCHAR(150) NOT NULL,
	strReturnURL VARCHAR(150) NOT NULL,
	strReturnExternalURL VARCHAR(150) NOT NULL,
	strReturnFailureURL VARCHAR(150) NOT NULL,
	strReturnExternalFailureURL VARCHAR(150) NOT NULL,
	strNotificationAddress VARCHAR(250),
	intStatus int(11) default 0,

PRIMARY KEY (intPaymentConfigID),
  KEY index_IDs(intLevelID,intEntityID),
KEY `index_intRealmID` (`intRealmID`),
KEY `index_intRealmSubTypeID` (`intRealmSubTypeID`)
);
 
