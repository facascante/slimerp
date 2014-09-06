DROP TABLE IF EXISTS tblPaymentConfig;
CREATE TABLE tblPaymentConfig (
    intPaymentConfigID int(11) NOT NULL AUTO_INCREMENT,
    intRealmID INT DEFAULT 0,
    intRealmSubTypeID INT DEFAULT 0,
    intPaymentType TINYINT DEFAULT 0, /*setup for a payment type */

    intAllowPaymentBackend TINYINT DEFAULT 0,
    intAllowPaymentRegoForm TINYINT DEFAULT 0,
    intAllowPayment TINYINT DEFAULT 0,

    intGatewayStatus TINYINT DEFAULT 0,
    intFeeAllocationType TINYINT DEFAULT 0,

    strCurrency CHAR(5) DEFAULT 'AUD',

    intPaymentGatewayID INT DEFAULT 0, /*ID to external gateway*/
    strGatewayImage VARCHAR(200) DEFAULT '',
    strGatewayURL1 VARCHAR(200) DEFAULT '',
    strGatewayURL2 VARCHAR(200) DEFAULT '',
    strGatewayURL3 VARCHAR(200) DEFAULT '',
    strCancelURL VARCHAR(150) NOT NULL,
    strReturnURL VARCHAR(150) NOT NULL,
    strReturnExternalURL VARCHAR(150) NOT NULL,
    strReturnFailureURL VARCHAR(150) NOT NULL,
    strReturnExternalFailureURL VARCHAR(150) NOT NULL,
    strGatewayUsername VARCHAR(100) DEFAULT '',
    strGatewayPassword VARCHAR(100) DEFAULT '',
    strGatewaySignature VARCHAR(100) DEFAULT '',
    strGatewaySalt VARCHAR(50) DEFAULT '',
    strGatewayVersion VARCHAR(50) DEFAULT '',
    
    strNotificationAddress VARCHAR(250),
    strPaymentBusinessNumber VARCHAR(100) DEFAULT '',
    strPaymentInfo TEXT, 
    strPaymentReceiptBodyTEXT TEXT,
    strPaymentReceiptBodyHTML TEXT,
    
    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (intPaymentConfigID),
    UNIQUE KEY (intRealmID, intRealmSubTypeID, intPaymentType)
) DEFAULT CHARSET=utf8;

