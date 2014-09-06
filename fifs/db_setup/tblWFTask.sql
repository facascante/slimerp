DROP TABLE IF EXISTS tblWFTask;
CREATE TABLE tblWFTask (
  intWFTaskID int(11) NOT NULL AUTO_INCREMENT,
  intWFRuleID int(11) NOT NULL DEFAULT '0',
  intRealmID int(11) NOT NULL DEFAULT '0',
  intSubRealmID int(11) NOT NULL DEFAULT '0',
  intApprovalEntityID int(11) NOT NULL DEFAULT '0' COMMENT 'Which entity has to approve this task',
/*  intApprovalRoleID int(11) NOT NULL DEFAULT '0' COMMENT 'What Role within the Entity has to approve this item',*/
  strTaskType varchar(20) NOT NULL COMMENT 'From tblWFRule',
  strWFRuleFor VARCHAR(30) DEFAULT '' COMMENT 'PERSON, REGO, ENTITY, DOCUMENT',
  strTaskStatus varchar(20) NOT NULL DEFAULT 'ACTIVE' COMMENT 'From tblWFRule',
  strRegistrationNature varchar(20) NOT NULL DEFAULT '0' COMMENT 'NEW,RENEWAL,AMENDMENT,TRANSFER,',
  intProblemResolutionEntityID int(11) DEFAULT NULL COMMENT 'From tblWFRule',
  /*intProblemResolutionRoleID int(11) DEFAULT NULL COMMENT 'From tblWFRule',*/
  /*intActivateUserID int(11) DEFAULT NULL COMMENT 'This person approved another task which caused this task to become active and appear on a list for another person to approve',*/
  intCreatedByUserID INT DEFAULT 0,
  dtActivateDate datetime DEFAULT NULL COMMENT 'What date did this task first appear on a person''s list',
  intApprovalUserID int(11) DEFAULT NULL COMMENT 'Who approved this task',
  dtApprovalDate datetime DEFAULT NULL COMMENT 'What date was this task approved',
  intRejectedUserID int(11) DEFAULT NULL,
  dtRejectedDate datetime DEFAULT NULL,

  intDocumentTypeID int(11) NOT NULL DEFAULT '0' COMMENT 'From tblWFRule',
  intEntityID int(11) NOT NULL DEFAULT '0' COMMENT 'The entity who is registering',
  intPersonID int(11) NOT NULL DEFAULT '0' COMMENT 'The person who is registering',
  intPersonRegistrationID int(11) NOT NULL DEFAULT '0' COMMENT 'Foreign key to the registration that triggered this task',
  intDocumentID int(11) NOT NULL DEFAULT '0' COMMENT 'The document to check - for a particular document',

  tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (intWFTaskID),
  KEY index_intEntityID (intApprovalEntityID),
  KEY index_intProbEntityID (intProblemResolutionEntityID),
    KEY index_WFRule (intWFRuleID),
    KEY index_intRealmID (intRealmID, intSubRealmID),
    KEY index_RuleFor (strWFRuleFor)
) DEFAULT CHARSET=utf8 COMMENT='A list of tasks associated with a Role at an Entity. For a single registration there could be multiple tasks. tblWFTask rows are inserted on a one to one ration with rows from tblWFRule';
