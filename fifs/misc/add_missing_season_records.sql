#Assoc

INSERT IGNORE INTO tblMember_Seasons_3
(intMemberID, intAssocID, intClubID, intSeasonID, intPlayerStatus, intCoachStatus, intUmpireStatus)

 select DISTINCT M.intMemberID, MA.intAssocID
,0,196
, IF(MTP.intActive = 1, 1,0) as Player 
, IF(MTC.intActive = 1, 1,0) as Coach
, IF(MTU.intActive = 1, 1,0) as Umpire
FROM tblMember AS M 
	INNER JOIN tblMember_Associations AS MA ON M.intMemberID=MA.intMemberID 
	LEFT JOIN tblMember_Seasons_3 AS MS ON (MS.intMemberID=MA.intMemberID AND MS.intSeasonID=196 AND MA.intAssocID=MS.intAssocID) 
	LEFT JOIN tblMember_Types AS MTP ON (MTP.intMemberID=M.intMemberID AND MTP.intTypeID=1 AND MTP.intSubTypeID = 0 AND MTP.intAssocID=MA.intAssocID AND MTP.intRecStatus=1) 
	LEFT JOIN tblMember_Types AS MTC ON (MTC.intMemberID=M.intMemberID AND MTC.intTypeID=2 AND MTC.intSubTypeID = 0 AND MTC.intAssocID=MA.intAssocID AND MTC.intRecStatus=1) 
	LEFT JOIN tblMember_Types AS MTU ON (MTU.intMemberID=M.intMemberID AND MTU.intTypeID=3 AND MTU.intSubTypeID = 0 AND MTU.intAssocID=MA.intAssocID AND MTU.intRecStatus=1) 

WHERE MA.intRecStatus=1 AND MS.intSeasonID IS NULL AND M.intRealmID=3;

# Club
INSERT IGNORE INTO tblMember_Seasons_3
(intMemberID, intAssocID, intClubID, intSeasonID, intPlayerStatus, intCoachStatus, intUmpireStatus)

 select M.intMemberID, MA.intAssocID,
MC.intClubID, 196
, IF(MTP.intActive = 1, 1,0) as Player 
, IF(MTC.intActive = 1, 1,0) as Coach
, IF(MTU.intActive = 1, 1,0) as Umpire
FROM tblMember AS M 
	INNER JOIN tblMember_Associations AS MA ON M.intMemberID=MA.intMemberID 
	INNER JOIN tblMember_Clubs AS MC ON M.intMemberID=MC.intMemberID 
	INNER JOIN tblAssoc_Clubs AS AC ON (AC.intAssocID=MA.intAssocID AND AC.intClubID=MC.intClubID)

	LEFT JOIN tblMember_Seasons_3 AS MS ON (MS.intMemberID=MA.intMemberID AND MS.intSeasonID=196 AND MA.intAssocID=MS.intAssocID AND MS.intClubID > 0) 
	LEFT JOIN tblMember_Types AS MTP ON (MTP.intMemberID=M.intMemberID AND MTP.intTypeID=1 AND MTP.intSubTypeID = 0 AND MTP.intAssocID=MA.intAssocID AND MTP.intRecStatus=1) 
	LEFT JOIN tblMember_Types AS MTC ON (MTC.intMemberID=M.intMemberID AND MTC.intTypeID=2 AND MTC.intSubTypeID = 0 AND MTC.intAssocID=MA.intAssocID AND MTC.intRecStatus=1) 
	LEFT JOIN tblMember_Types AS MTU ON (MTU.intMemberID=M.intMemberID AND MTU.intTypeID=3 AND MTU.intSubTypeID = 0 AND MTU.intAssocID=MA.intAssocID AND MTU.intRecStatus=1) 

WHERE MA.intRecStatus=1 AND MS.intSeasonID IS NULL AND M.intRealmID=3 AND MC.intStatus=1;
