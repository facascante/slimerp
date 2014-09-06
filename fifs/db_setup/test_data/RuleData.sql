DELETE FROM tblWFRule WHERE intWFRuleID > 0;


INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    1,
    1,
    0,
    1,/*SELF*/
    'REGO',
    '',
    0,
    'PLAYER',
    'AMATEUR',
    'FOOTBALL',
    'NEW',
    'SENIOR',
    0,
    3,
    3,
    1,
    'DOCUMENT',
    'ACTIVE',
    0
);
INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    2,
    1,
    0,
    1,/*SELF*/
    'REGO',
    '',
    0,
    'PLAYER',
    'AMATEUR',
    'FOOTBALL',
    'NEW',
    'SENIOR',
    0,
    3,
    3,
    2,
    'DOCUMENT',
    'ACTIVE',
    0
);
INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    3,
    1,
    0,
    1,/*SELF*/
    'REGO',
    '',
    0,
    'PLAYER',
    'AMATEUR',
    'FOOTBALL',
    'NEW',
    'SENIOR',
    0,
    3,
    3,
    3,
    'DOCUMENT',
    'ACTIVE',
    0
);
INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    4,
    1,
    0,
    1,/*SELF*/
    'REGO',
    '',
    0,
    'PLAYER',
    'AMATEUR',
    'FOOTBALL',
    'NEW',
    'SENIOR',
    0,
    3,
    3,
    0,
    'APPROVAL',
    'PENDING',
    0
);  
INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    5,
    1,
    0,
    1,/*SELF*/
    'REGO',
    '',
    0,
    'PLAYER',
    'AMATEUR',
    'FOOTBALL',
    'NEW',
    'SENIOR',
    0,
    20,
    3,
    0,
    'APPROVAL',
    'PENDING',
    0
);  
INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    6,
    1,
    0,
    1,/*SELF*/
    'REGO',
    '',
    0,
    'PLAYER',
    'AMATEUR',
    'FOOTBALL',
    'NEW',
    'SENIOR',
    0,
    100,
    3,
    0,
    'APPROVAL',
    'PENDING',
    0
);  
INSERT INTO tblWFRule (
    intWFRuleID,
    intRealmID,
    intSubRealmID,
    intOriginLevel,
    strWFRuleFor,
    strEntityType,
    intEntityLevel,
    strPersonType,
    strPersonLevel,
    strSport,
    strRegistrationNature,
    strAgeLevel,
    intPaymentRequired,
    intApprovalEntityLevel,
    intProblemResolutionEntityLevel,
    intDocumentTypeID,
    strTaskType,
    strTaskStatus,
    intNationalPeriodID
)
VALUES (
    7,
    1,
    0,
    1,/*SELF*/
    'ENTITY',
    '',
    -47,
    '',
    '',
    '',
    'NEW',
    '',
    0,
    100,
    100,
    0,
    'APPROVAL',
    'ACTIVE',
    0
);  




DELETE FROM tblWFRulePreReq WHERE intWFRulePreReqID > 0;
INSERT INTO tblWFRulePreReq(intWFRulePreReqID,intWFRuleID,intPreReqWFRuleID) VALUES (1,4,1);
INSERT INTO tblWFRulePreReq(intWFRulePreReqID,intWFRuleID,intPreReqWFRuleID) VALUES (2,4,2);
INSERT INTO tblWFRulePreReq(intWFRulePreReqID,intWFRuleID,intPreReqWFRuleID) VALUES (3,4,3);
INSERT INTO tblWFRulePreReq(intWFRulePreReqID,intWFRuleID,intPreReqWFRuleID) VALUES (4,5,4);
INSERT INTO tblWFRulePreReq(intWFRulePreReqID,intWFRuleID,intPreReqWFRuleID) VALUES (5,6,5);

DELETE FROM tblRolePerson WHERE intRolePersonID > 0;
INSERT INTO tblRolePerson(intRolePersonID,intPersonID,intRoleID,intEntityID) VALUES (1,10759048,1,1);
INSERT INTO tblRolePerson(intRolePersonID,intPersonID,intRoleID,intEntityID) VALUES (2,10759049,2,14);
INSERT INTO tblRolePerson(intRolePersonID,intPersonID,intRoleID,intEntityID) VALUES (3,10759057,3,35);

DELETE FROM tblRole WHERE intRoleID > 0;
INSERT INTO tblRole(intRoleID,intRealmID, intEntityID,strTitle) VALUES (1,1,1,'Administrator');
INSERT INTO tblRole(intRoleID,intRealmID, intEntityID,strTitle) VALUES (2,1,14,'Administrator');
INSERT INTO tblRole(intRoleID,intRealmID, intEntityID,strTitle) VALUES (3,1,35,'Registrar');


DELETE FROM tblDocumentType WHERE intDocumentTypeID > 0;
INSERT INTO tblDocumentType(intDocumentTypeID,intRealmID,strDocumentName,intActive) VALUES (1,1,'Medical Certificate',NULL);
INSERT INTO tblDocumentType(intDocumentTypeID,intRealmID,strDocumentName,intActive) VALUES (2,1,'Clearance Document',NULL);
INSERT INTO tblDocumentType(intDocumentTypeID,intRealmID,strDocumentName,intActive) VALUES (3,1,'Note from your Mum',NULL);
