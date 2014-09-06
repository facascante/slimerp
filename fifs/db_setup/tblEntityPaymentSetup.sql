DROP TABLE IF EXISTS tblEntityPaymentSetup;
CREATE TABLE tblEntityPaymentSetup (
    intPaymentSetupID int(11) NOT NULL AUTO_INCREMENT,
    intParentEntityID int(11) DEFAULT 0, /* tblEntityID */
    intParentEntityType int(11) DEFAULT 0, /* Level 30 etc*/
    intRealmID INT DEFAULT 0,
    intRealmSubTypeID INT NOT NULL,
    intPaymentType TINYINT DEFAULT 0, /*setup for a payment type */

    intAllowPaymentBackend TINY INT DEFAULT 0,
    intAllowPaymentFromRegoForm TINY INT DEFAULT 0,

    intEntityFeeAllocationType TINYINT DEFAULT 0,
    intApproveThisLevelPayment TINYINT DEFAULT 0,
    intApproveChildrenPayment TINYINT DEFAULT 0,

    strCurrency CHAR(5) DEFAULT 'AUD',

    strNotificationAddress VARCHAR(250),

    intPaymentGatewayID INT DEFAULT 0, /*ID to external gateway*/
    strGatewayURL1 VARCHAR(200) DEFAULT '',
    strGatewayURL2 VARCHAR(200) DEFAULT '',
    strGatewayURL3 VARCHAR(200) DEFAULT '',
    strReturnURL VARCHAR(150) NOT NULL,
    strReturnExternalURL VARCHAR(150) NOT NULL,
    strReturnFailureURL VARCHAR(150) NOT NULL,
    strReturnExternalFailureURL VARCHAR(150) NOT NULL,
    strGatewayUsername VARCHAR(100) DEFAULT '',
    strGatewayPassword VARCHAR(100) DEFAULT '',
    strGatewaySignature VARCHAR(100) DEFAULT '',
    strGatewaySalt VARCHAR(50) DEFAULT '',

    strEntityPaymentABN VARCHAR(100) DEFAULT '',
    strEntityPaymentInfo TEXT, 
    strPaymentReceiptBodyTEXT TEXT,
    strPaymentReceiptBodyHTML TEXT,
    
    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (intPaymentSetupID),
    UNIQUE KEY (intParentEntityID, intRealmID, intRealmSubTypeID, intPaymentType),
    KEY index_intRealmID (intRealmID)
) DEFAULT CHARSET=utf8;

