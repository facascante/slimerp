#!/usr/bin/perl

use strict;
use lib "..", "../web", "../web/comp";
use Utils;
use DBI;
use Data::Dumper;
use SystemConfig;
use Defs;
use Reg_common;

my $db = connectDB();

my $st_select = qq[
    SELECT
        FN.*,
        F.intRegoType
    FROM
        tblRegoFormNotifications AS FN
        JOIN tblRegoForm AS F ON FN.intRegoFormID=F.intRegoFormID
    WHERE
        FN.intNotifiedStatus = 0
        AND FN.intEntityTypeID >= $Defs::LEVEL_ASSOC
];
my $q_select = $db->prepare($st_select);

my $st_items = qq[
    SELECT
        I.*
    FROM
        tblRegoFormNotificationItems AS I
        JOIN tblRegoFormNotifications AS N ON I.intRegoFormNotificationID=N.intRegoFormNotificationID
    WHERE
        N.intRegoFormNotificationID=?
];
my $q_items = $db->prepare($st_items);

my $st_update = qq[
    UPDATE
        tblRegoFormNotifications
    SET
        intNotifiedStatus = ?,
        dtNotified = NOW()
    WHERE
        intRegoFormNotificationID = ?
];
my $q_update = $db->prepare($st_update);

my $st_insert = qq[
    INSERT INTO tblNotifications (
        intEntityTypeID,
        intEntityID,
        dtDateTime,
        strNotificationType,
        strTitle,
        intReferenceID,
        strMoreInfo,
        strURL,
        intNotificationStatus,
        strMoreInfoURLs
    )
    VALUES (
        ?,
        ?,
        NOW(),
        'RegoForm',
        ?,
        ?,
        ?,
        ?,
        0,
        ?
    )
];
my $q_insert = $db->prepare($st_insert);

$q_select->execute();
my $node_notification_ref = $q_select->fetchall_hashref('intRegoFormNotificationID');

if ( scalar keys %$node_notification_ref > 0 ) {
    print "regoform_notifications.pl: unsent notifications found.\n";
    for my $node_notification ( values %$node_notification_ref ) {
        my $notification_id = $node_notification->{'intRegoFormNotificationID'}; 
        my $entity_type     = $node_notification->{'intEntityTypeID'};
        my $entity_id       = $node_notification->{'intEntityID'};
        my $title           = $node_notification->{'strTitle'};

        my $body = '';
        $q_items->execute($notification_id);
        while ( my $hr = $q_items->fetchrow_hashref() ) {
            $body .= $hr->{'strType'};
            $body .= qq[ '$hr->{'strTypeName'}'] if ( $hr->{'strTypeName'} ne '' );
            $body .= ' changed';
            $body .= qq[ from '$hr->{'strOldValue'}'] if ( $hr->{'strOldValue'} ne '' );
            $body .= qq[ to '$hr->{'strNewValue'}'] if ( $hr->{'strNewValue'} ne '' );
            $body .= '. ';
            $body .= '<br>';
        }
        my $entities = get_notify_structrure( $db, $entity_type, $entity_id );
        for my $type_id ( keys %$entities ) {
            for my $id ( keys %{$entities->{$type_id}} ) {
                my $list_notifications_url = $Defs::base_url . '/main.cgi?client=XXX_CLIENT_XXX&amp;a=NOTS_L';
                my $list_regoforms_url = '<a href="' . $Defs::base_url . '/main.cgi?client=XXX_CLIENT_XXX&amp;a=A_ORF_r">Registration Forms</a>';
                $q_insert->execute( $type_id, $id, $title, $notification_id, $body, $list_notifications_url, $list_regoforms_url );
            }
        }
        $q_update->execute( 1, $notification_id );
        print "regoform_notifications.pl: send regoform notification $notification_id.\n";
    }
}

sub get_notify_structrure {
    my ( $db, $entity_type, $entity_id ) = @_;

    my $st = '';
    my $entities = {};
    if ( $entity_type == $Defs::LEVEL_NATIONAL ) {
        $st = qq[
            SELECT
                int30_ID AS 30_id,
                int20_ID AS 20_id,
                int10_ID AS 10_id,
                TNS.intAssocID AS 5_id,
                intClubID AS 3_id
            FROM 
                tblTempNodeStructure AS TNS
                LEFT JOIN tblAssoc_Clubs as AC on ( TNS.intAssocID=AC.intAssocID AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE )
            WHERE
                TNS.int100_ID=$entity_id
        ];
    }
    elsif ( $entity_type == $Defs::LEVEL_STATE ) {
        $st = qq[
            SELECT
                int20_ID AS 20_id,
                int10_ID AS 10_id,
                TNS.intAssocID AS 5_id,
                intClubID AS 3_id
            FROM 
                tblTempNodeStructure AS TNS
                LEFT JOIN tblAssoc_Clubs as AC on ( TNS.intAssocID=AC.intAssocID AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE )
            WHERE
                TNS.int30_ID=$entity_id
        ];
    }
    elsif ( $entity_type == $Defs::LEVEL_REGION ) {
        $st = qq[
            SELECT
                int10_ID AS 10_id,
                TNS.intAssocID AS 5_id,
                intClubID AS 3_id
            FROM 
                tblTempNodeStructure AS TNS
                LEFT JOIN tblAssoc_Clubs as AC on ( TNS.intAssocID=AC.intAssocID AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE )
            WHERE
                TNS.int20_ID=$entity_id
        ];
    }
    elsif ( $entity_type == $Defs::LEVEL_ZONE ) {
        $st = qq[
            SELECT
                TNS.intAssocID AS 5_id,
                intClubID AS 3_id
            FROM 
                tblTempNodeStructure AS TNS
                LEFT JOIN tblAssoc_Clubs as AC on ( TNS.intAssocID=AC.intAssocID AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE )
            WHERE
                TNS.int10_ID=$entity_id
        ];
    }
    elsif ( $entity_type == $Defs::LEVEL_ASSOC ) {
        $st = qq[
            SELECT
                intClubID as 3_id
            FROM
                tblAssoc_Clubs
            WHERE
                intAssocID=$entity_id
                AND intRecStatus = $Defs::RECSTATUS_ACTIVE
        ];
    }
    else {
        # do nothing
    }
    my $q = $db->prepare($st);
    $q->execute();
    while ( my $hr = $q->fetchrow_hashref() ) {
        for my $key ( keys %$hr ) {
            my ( $type ) = split '_', $key;
            $entities->{$type}->{$hr->{$key}} = 1 if ( $hr->{$key} and ( int($type) == 5 or int($type) == 3 ) );
        }
    }

    return $entities;
}
