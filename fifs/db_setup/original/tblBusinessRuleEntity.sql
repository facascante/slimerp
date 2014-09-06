DROP TABLE tblBusinessRuleEntity;

CREATE table tblBusinessRuleEntity	(
  intBusinessRuleID INT NOT NULL,
  intRealmID INT NOT NULL,
  intSubRealmID INT NOT NULL,
  intEntityTypeID INT NOT NULL,
  intEntityID INT NOT NULL,
  intMinLevel INT NOT NULL,
  intMaxLevel INT NOT NULL,

PRIMARY KEY (
  intBusinessRuleID,
  intRealmID,
  intSubRealmID,
  intEntityTypeID,
  intEntityID
)
);
