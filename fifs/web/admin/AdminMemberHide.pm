package AdminMemberHide;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(member_hide);
@EXPORT_OK = qw(member_hide);

use strict;
use CGI qw(param);
use DBI;
use Data::Dumper;

sub member_hide {
    my ( $db, $assocID, $target )=@_;

	my $body  = '';
    my $break_body = qq[
        <br>
        <hr>
        <br>
    ];

    $body .= get_assoc_body( $db, $target, $assocID, $break_body );
    $body .= get_club_body( $db, $target, $assocID, $break_body );
    $body .= get_member_body( $db, $target, $assocID, $break_body );

    return $body;
}

sub get_assoc_body {
    my ( $db, $target, $assocID, $break_body ) = @_;

    my $is_hidden = '';
    my $action_body = '';
    my $body = '';

    return $body if ( $assocID == 0 );

    if ( param('action') eq 'ASSOC_memberhide_assoc' and param('hide_action') ne '' ) {
        ( $is_hidden, $action_body ) = process_member_hide( $db, 0, $assocID, param('hide_action') );
    }

    $body .= qq[
        <form action="$target" method="post">
        <input type="hidden" name="action" value="ASSOC_memberhide_assoc">
        <input type="hidden" name="intAssocID" value="$assocID">
            <table>
                <tr>
                    <td><input type="checkbox" name="assoc_only" value="1" onChange="this.form.submit()"></td>
                    <td>All members in Assoc $assocID</td>
                    <td><input type="submit" name="hide_action" value="Hide"><input type="submit" name="hide_action" value="Unhide"></td>
                </tr>
            </table>
        </form>
    ];

    $body .= $action_body if ( $action_body ne '' );
    $body .= $break_body if ( $body ne '' );

    return $body;
}

sub get_club_body {
    my ( $db, $target, $assocID, $break_body ) = @_;

    my $is_hidden = '';
    my $action_body = '';
    my $body = '';

    return $body if ( param('assoc_only') == 1 or $assocID == 0 );
    
    my $club_ref = {};
    my $sql = qq[
        SELECT
            tblMember_Clubs.intMemberID,
            tblMember_Clubs.intClubID,
            tblClub.strName AS strClubName
        from
            tblMember_Clubs
            INNER JOIN tblAssoc_Clubs ON tblMember_Clubs.intClubID = tblAssoc_Clubs.intClubID
            INNER JOIN tblClub ON tblMember_Clubs.intClubID = tblClub.intClubID
        WHERE
            tblAssoc_Clubs.intAssocID = ?
    ];
    my $sth = $db->prepare($sql);
    $sth->execute($assocID);
    while( my $hr = $sth->fetchrow_hashref() ) {
        $club_ref->{$hr->{'intClubID'}}->{'strClubName'} = $hr->{'strClubName'};
        push @{$club_ref->{$hr->{'intClubID'}}->{'intMemberID'}}, $hr->{'intMemberID'};
    }

    if ( param('action') eq 'ASSOC_memberhide_club' and param('intClubID') ne '' ) {
        my $clubID = param('intClubID');
        for my $memberID ( @{$club_ref->{$clubID}->{'intMemberID'}} ) {
            ( $is_hidden, $action_body ) = process_member_hide( $db, $memberID, $assocID, param('hide_action') );
        }
        $action_body = "<p>". param('hide_action') . " club: $clubID $club_ref->{$clubID}->{'strClubName'} in Assoc: $assocID successfully</p>";
    }

    $body .= qq[
        <form action="$target" method="post">
        <input type="hidden" name="action" value="ASSOC_memberhide_club">
        <input type="hidden" name="intAssocID" value="$assocID">
            <table>
                <tr>
                    <td></td>
                    <td>
                        <select name="intClubID"><option value="" selected>--Select Club Name--</option>
    ];

    for ( sort { $club_ref->{$a}->{'strClubName'} cmp $club_ref->{$b}->{'strClubName'} } keys %$club_ref ) {
        $body .= qq[
            <option value="$_">$club_ref->{$_}->{'strClubName'}</option>
        ];
    }

    $body .= '</select>';
    $body .= qq[
                    </td>
                    <td><input type="submit" name="hide_action" value="Hide"><input type="submit" name="hide_action" value="Unhide"></td>
                </tr>
            </table>
        </form>
    ];

    $body .= $action_body if ( $action_body ne '' );
    $body .= $break_body if ( $body ne '' );

    return $body;
}

sub get_member_body {
    my ( $db, $target, $assocID, $break_body ) = @_;

    my $is_hidden = '';
    my $action_body = '';
    my $body = '';

    return $body if ( param('assoc_only') == 1 );
        
    if ( param('intMemberID') ne '' or param('strNationalNum') ne '' ) {
        my $memberID = param('intMemberID') || 0;
        my $nationalNum = param('strNationalNum') || '';
        my $is_member_exist = dbi_is_member_exist( $db, $assocID, $memberID, $nationalNum );
        if ( $is_member_exist ) {
            ( $is_hidden, $action_body ) = process_member_hide( $db, $memberID, $assocID, param('hide_action') );
        }
        else {
            $action_body = qq[<p>No member found in Assoc $assocID!</p>];
        }
    }

    for ( param('member_group') ) {
        my $tmp_action_body = '';
        ( $is_hidden, $tmp_action_body ) = process_member_hide( $db, $_, $assocID, param('hide_action') );
        $action_body .= $tmp_action_body;
    }

    $body .= $action_body if ( $action_body ne '' );

    $body .= qq[
        <form action="$target" method="post">
        <input type="hidden" name="action" value="ASSOC_memberhide_member">
        <input type="hidden" name="intAssocID" value="$assocID">
            <table>
                <tr>
                    <td></td>
                    <td>strNationalNum<input type="text" name="strNationalNum"> OR intMemberID<input type="text" name="intMemberID"></td>
                    <td><input type="submit" name="hide_action" value="Hide"><input type="submit" name="hide_action" value="Unhide"></td>
                </tr>
            </table>
    ];

    my $hidden_member_body = '';
    my $have_hidden_member = 0;
    my $sql = qq[
        SELECT DISTINCT
            MH.intAssocToHideID,
            MH.intMemberToHideID,
            M.strFirstname,
            M.strSurname,
            M.dtDOB,
            IF( MH.intAssocToHideID != 0, C.intClubID, '' ) AS intClubID,
            IF( MH.intAssocToHideID != 0, C.strName, '' ) AS strClubName,
            M.intRealmID,
            R.strRealmName
        FROM
            tblMemberHidePublic AS MH
            INNER JOIN tblMember AS M ON MH.intMemberToHideID = M.intMemberID
            INNER JOIN tblRealms AS R ON M.intRealmID = R.intRealmID
            LEFT JOIN tblMember_Clubs AS MC ON ( MH.intMemberToHideID = MC.intMemberID )
            LEFT JOIN tblAssoc_Clubs AS AC ON ( MC.intClubID = AC.intClubID AND MH.intAssocToHideID = AC.intAssocID )
            LEFT JOIN tblClub AS C ON MC.intClubID = C.intClubID
        WHERE
            intAssocToHideID = ?
            AND intMemberToHideID != 0
        ORDER BY
            M.intRealmID ASC,
            strClubName ASC,
            M.strFirstname ASC
    ];
    my $sth = $db->prepare($sql);
    $sth->execute($assocID);
    $hidden_member_body .= qq[
            <p>Members hidden in Assoc: $assocID are listed below. Please select and click 'Unhide' to Unhide them.</p>
            <table>
                <tr>
                    <td></td>
                    <td>Member ID</td>
                    <td>Firstname</td>
                    <td>Surname</td>
                    <td>DOB</td>
                    <td>Club ID</td>
                    <td>Club Name</td>
                    <td>Realm ID</td>
                    <td>Realm Name</td>
                </tr>
    ];
    while( my $hr = $sth->fetchrow_hashref() ) {
        $hidden_member_body .= qq[
                <tr>
                    <td><input type="checkbox" name="member_group" value="$hr->{'intMemberToHideID'}"></td>
                    <td>$hr->{'intMemberToHideID'}</td>
                    <td>$hr->{'strFirstname'}</td>
                    <td>$hr->{'strSurname'}</td>
                    <td>$hr->{'dtDOB'}</td>
                    <td>$hr->{'intClubID'}</td>
                    <td>$hr->{'strClubName'}</td>
                    <td>$hr->{'intRealmID'}</td>
                    <td>$hr->{'strRealmName'}</td>
                </tr>
        ];
        $have_hidden_member = 1;
    }
    $hidden_member_body .= qq[
                <tr>
                    <td><input type="submit" name="hide_action" value="Unhide"></td>
                </tr>
            </table>
    ];
    $body .= $hidden_member_body if ($have_hidden_member);

    $body .= qq[
        </form>
    ];

    $body .= $break_body if ( $body ne '' );

    return $body;
}

sub dbi_is_member_exist {
    my ( $db, $assocID, $memberID, $nationalNum ) = @_;

    my $is_exist = 0;

    my $where = '';

    if ($assocID) {
        $where .= "tblMember_Associations.intAssocID = $assocID";
    }
    else {
        $where .= "tblMember_Associations.intAssocID IS NOT NULL";
    }
    $where .= " AND tblMember.intMemberID = $memberID" if ($memberID);
    $where .= " AND tblMember.strNationalNum = $nationalNum" if ($nationalNum);
    my $sql = qq[
        SELECT
            *
        FROM
            tblMember
        JOIN
            tblMember_Associations ON tblMember.intMemberID = tblMember_Associations.intMemberID
        WHERE
            $where
    ];
    my $sth = $db->prepare($sql);
    $sth->execute();
    while ( my $hr = $sth->fetchrow_hashref() ) {
        $is_exist = 1;
    }

    return $is_exist;
}

sub dbi_is_member_hidden {
    my ( $db, $memberID, $assocID ) = @_;

    my $is_hidden = 0;
    my $sql = qq[
        SELECT
            intMemberToHideID,
            intAssocToHideID
        FROM
            tblMemberHidePublic
        WHERE
            intMemberToHideID = ? 
            AND intAssocToHideID = ?
    ];
    my $sth = $db->prepare($sql);
    $sth->execute( $memberID, $assocID );
    if ( !defined $sth->fetchrow_array() ) {
        $is_hidden = 0;
    }
    else {
        $is_hidden = 1;
    }

    return $is_hidden;
}

sub dbi_hide {
    my ( $db, $memberID, $assocID ) = @_;

    my $sql = qq[
        INSERT INTO
            tblMemberHidePublic
        VALUES ( ?, ? )
    ];
    my $sth = $db->prepare($sql);
    $sth->execute( $memberID, $assocID );
}

sub dbi_unhide {
    my ( $db, $memberID, $assocID ) = @_;

    my $sql = qq[
        DELETE
        FROM
            tblMemberHidePublic
        WHERE
            intMemberToHideID = ?
            AND intAssocToHideID = ?
    ];
    my $sth = $db->prepare($sql);
    $sth->execute( $memberID, $assocID );
}

sub process_member_hide {
    my ( $db, $memberID, $assocID, $action ) = @_;
    my $sql = '';
    my $sth = '';
    my $is_hidden = '';
    my $action_body = '';

    if ( ( $memberID == 0 ) and ( $assocID == 0 ) ) {
        $action_body = "<p>INVALID IDs intMemberID: 0 and intAssocID: 0.</p>";
    }
    else {
        $is_hidden = dbi_is_member_hidden( $db, $memberID, $assocID );

        if ( $action eq 'Hide' ) {
            if ( $is_hidden == 0 ) {
                dbi_hide( $db, $memberID, $assocID );
                dbi_update_timestamp( $db, $memberID, $assocID );
                $is_hidden = 1;
                $action_body = "<p>Hide member: $memberID in Assoc: $assocID successfully</p>";
            }
            else {
                $action_body = "<p>Member: $memberID is already hidden in Assoc: $assocID</p>";
            }
        }
        elsif ( $action eq 'Unhide' ) {
            if ( $is_hidden == 1 ) {
                dbi_unhide( $db, $memberID, $assocID );
                dbi_update_timestamp( $db, $memberID, $assocID );
                $is_hidden = 0;
                $action_body = "<p>Unhide member: $memberID in Assoc: $assocID successfully</p>";
            }
            else {
                $action_body = "<p>Member: $memberID is already not hidden in Assoc: $assocID</p>";
            }
        }
        else {
            $action_body = "<p>INVALID ACTION</p>";
        }
    }

    return $is_hidden, $action_body;
}

sub dbi_update_timestamp {
    my ( $db, $memberID, $assocID ) = @_;

    my $sql = '';
    my $sth = '';
    my @sqls = ();
    my $realmID = '';

    if ( $memberID != 0 and $assocID != 0 ) {
        push @sqls, qq[UPDATE tblMember_Associations  SET tTimeStamp=NOW() WHERE intMemberID = $memberID AND intAssocID = $assocID];
        push @sqls, qq[UPDATE tblCompMatchPlayerStats SET tTimeStamp=NOW() WHERE intMemberID = $memberID];

        $sql = qq[SELECT intRealmID FROM tblAssoc WHERE intAssocID = $assocID]; 
        $sth = $db->prepare($sql);
        $sth->execute();
        ($realmID) = $sth->fetchrow_array();

        push @sqls, qq[UPDATE tblPlayerCompStats_SG_$realmID SET tTimeStamp=NOW() WHERE intPlayerID = $memberID AND intAssocID = $assocID];
        push @sqls, qq[UPDATE tblPlayerCompStats_ME_$realmID SET tTimeStamp=NOW() WHERE intPlayerID = $memberID AND intAssocID = $assocID];
    }

    if ( $memberID != 0 and $assocID == 0 ) {
        push @sqls, qq[UPDATE tblMember_Associations  SET tTimeStamp=NOW() WHERE intMemberID = $memberID];
        push @sqls, qq[UPDATE tblCompMatchPlayerStats SET tTimeStamp=NOW() WHERE intMemberID = $memberID];

        $sql = qq[
            SELECT DISTINCT
                tblAssoc.intRealmID
            FROM
                tblMember_Associations
                INNER JOIN tblAssoc ON tblMember_Associations.intAssocID = tblAssoc.intAssocID
            WHERE
                tblMember_Associations.intMemberID = ?
        ];
        $sth = $db->prepare($sql);
        $sth->execute($memberID);
        while ( ($realmID) = $sth->fetchrow_array() ) {
            push @sqls, qq[UPDATE tblPlayerCompStats_SG_$realmID SET tTimeStamp=NOW() WHERE intPlayerID = $memberID];
            push @sqls, qq[UPDATE tblPlayerCompStats_ME_$realmID SET tTimeStamp=NOW() WHERE intPlayerID = $memberID];
        }
    }

    if ( $memberID == 0 and $assocID != 0 ) {
        push @sqls, qq[UPDATE tblMember_Associations  SET tTimeStamp=NOW() WHERE intAssocID = $assocID];

        $sql = qq[SELECT intRealmID FROM tblAssoc WHERE intAssocID = $assocID];
        $sth = $db->prepare($sql);
        $sth->execute();
        ($realmID) = $sth->fetchrow_array();

        push @sqls, qq[UPDATE tblPlayerCompStats_SG_$realmID SET tTimeStamp=NOW() WHERE intAssocID = $assocID];
        push @sqls, qq[UPDATE tblPlayerCompStats_ME_$realmID SET tTimeStamp=NOW() WHERE intAssocID = $assocID];

        $sql = qq[
            SELECT
                intMemberID
            FROM
                tblMember_Associations
            WHERE
                intAssocID = ?
        ];
        $sth = $db->prepare($sql);
        $sth->execute($assocID);

        while ( ($memberID) = $sth->fetchrow_array() ) {
            push @sqls, qq[UPDATE tblCompMatchPlayerStats SET tTimeStamp=NOW() WHERE intMemberID = $memberID];
        }
    }

    for $sql (@sqls) {
        $sth = $db->prepare($sql);
        $sth->execute();
    }
}
