DROP TABLE IF EXISTS tblAgreementsEntity;

CREATE TABLE tblAgreementsEntity	(
  intEntityTypeID INT NOT NULL,
  intEntityID INT NOT NULL,
	intAgreementID INT NOT NULL,
	dtAgreed DATETIME,
    strAgreedBy VARCHAR(200) DEFAULT '',

	PRIMARY KEY (intEntityTypeID, intEntityID, intAgreementID),
	KEY index_agreement(intAgreementID)
);
