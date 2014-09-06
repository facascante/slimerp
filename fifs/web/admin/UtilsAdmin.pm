#
# $Header: svn://svn/SWM/trunk/web/admin/UtilsAdmin.pm 11628 2014-05-21 04:15:45Z ppascoe $
#

package UtilsAdmin;

require Exporter;
@ISA = qw(Exporter);
@EXPORT =
  qw(handle_categories handle_interchange_agreements handle_holidays decodeForm decodeInfo);
@EXPORT_OK =
  qw(handle_categories handle_interchange_agreements handle_holidays decodeForm decodeInfo);

use strict;
use lib ".", "..", "../..", "../comp";
use Defs;
use Utils;
use Reg_common;
use InstanceOf;
use MCache;
use CGI qw(param unescape escape);
use DBI;
use FormHelpers;

sub get_state_node_id {
    my ( $db, $assoc_id ) = @_;

    my $st = qq[
                SELECT intNodeID
                FROM tblNode
                INNER JOIN tblTempNodeStructure ON (tblNode.intNodeID = tblTempNodeStructure.int20_ID)
                WHERE intAssocID = ?
                AND intTypeID = 20
                ];

    my $qry = $db->prepare($st) or query_error($st);
    $qry->execute($assoc_id) or query_error($st);

    my ($state_node_id) = $qry->fetchrow_array();

    return $state_node_id;

}

sub handle_interchange_agreements {

    #  return 'This Page is currently under development. Please Return later.';
    my ( $db, $action, $target, $intAssocID ) = @_;
    print STDERR "\n\n" . $intAssocID . "\n\n";
    my $intAssocID1     = param('intAssocID1')     || 0;
    my $intAssocID2     = param('intAssocID2')     || 0;
    my $intPermitTypeID = param('intPermitTypeID') || 0;
    my $intRecStatus    = param('intRecStatus');
    my $intStateNodeID = get_state_node_id( $db, $intAssocID1 ) || 0;
    my $method = param('method') || '';

    if ( !AdminCommon::verify_hash() ) {
        return ("Error in Querystring hash");
    }

    my $body = '';
    my $menu = '';
    if (    $action eq 'ASSOC_agreements_manage' && $method ne ''
        and $intPermitTypeID > 0 )
    {
        $body = edit_agreements($db, $action, $target, $method, $intAssocID1, $intAssocID2, $intPermitTypeID, $intStateNodeID, $intRecStatus, $intAssocID);
    }
    else {
        $body = list_agreements( $db, $action, $target, $intAssocID1, $intAssocID2, $intPermitTypeID, $intStateNodeID, $intRecStatus, $intAssocID );
    }
    return $body;
}

sub list_agreements {
    my ( $db, $action, $target, $intAssocID1, $intAssocID2, $intPermitTypeID, $intStateNodeID, $intRecStatus, $intAssocID ) = @_;
    my $body = '';
    $body .= qq[
                <table  style="margin-left:auto;margin-right:auto;">
                <tr><td class="formbg">
                <h2> Current Interchange Agreements</h2>
                <p>Note: Adding/Editing will also create a duplicate record with Assoc1 & Assoc2 switched.
                <table width='100%' style="margin-left:auto;margin-right:auto;"  cellpadding=5 cellspacing=1 border=1>
                <tr>
                        <th>Assoc1</th>
                        <th>Assoc2</th>
                        <th>Permit Type</th>
                        <th>IntRecStatus</th>
                        <th>&nbsp;</th>
                </tr>
        ];

    my $statement = qq[
                SELECT IA.*, A1.strName AssocName1, A2.strName AssocName2 
                FROM tblInterchangeAgreements IA
                LEFT JOIN tblAssoc A1 ON (IA.intAssocID1 = A1.intAssocID)
                LEFT JOIN tblAssoc A2 ON (IA.intAssocID2 = A2.intAssocID)
                WHERE intAssocID1 = $intAssocID
                ORDER BY tTimeStamp desc 
                        ];
    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    my $displayAdd = 'Yes';
    my $hash_value = AdminCommon::create_hash( 0, 0, $intAssocID, 0, 0 );
    while ( my $dref = $query->fetchrow_hashref() ) {
        if (   $intAssocID1 == $dref->{intAssocID1}
            && $intAssocID2 == $dref->{intAssocID2}
            && $intPermitTypeID == $dref->{intPermitTypeID} )
        {
            $displayAdd = 'No';
            $body .= qq[

                        <form method="post" action="">
                        <input type="hidden" name="action" value="ASSOC_agreements_manage">
                        <input type="hidden" name="method" value="update">
                        <input type="hidden" name="hID" value="$dref->{intPublicHolidaysID}">
                        <input type="hidden" name="intAssocID" value="$intAssocID">
                        <input type="hidden" name="hash" value="$hash_value">
            <tr>
                        <td><input type="hidden" name="intAssocID1" value="$dref->{intAssocID1}">$dref->{AssocName1}</td>
                        <td><input type="hidden" name="intAssocID2" value="$dref->{intAssocID2}">$dref->{AssocName2}</td>
                        <td><input type="hidden" name="intPermitTypeID" value="$dref->{intPermitTypeID}">$Defs::clearancePermitType{2}{$dref->{intPermitTypeID}}</td>
                        <td><input type="text" name="intRecStatus" value="$dref->{intRecStatus}"></td>
                        <td><input type="submit" value="Edit" name="frmSubmit"></td></td></tr></form>
                                 ];

        }
        else {
            $body .= qq[
                                <tr>
                                <td>$dref->{AssocName1}</td>
                                <td>$dref->{AssocName2}</td>
                                <td>$Defs::clearancePermitType{2}{$dref->{intPermitTypeID}}</td>
                                <td>$dref->{intRecStatus}</td>
                                ];
            $body .= qq[<td><a href="
                ?action=ASSOC_agreements
                &intAssocID=$dref->{intAssocID1}
                &intAssocID1=$dref->{intAssocID1}
                &intAssocID2=$dref->{intAssocID2}
                &intPermitTypeID=$dref->{intPermitTypeID}
                &hash=$hash_value">Edit</a></td>
                                 ];
            $body .= qq[   </tr>
                                ];
        }
    }
    if ( $displayAdd eq 'Yes' ) {

        my $intStateNodeID = get_state_node_id( $db, $intAssocID ) || 0;
        
        if (!$intAssocID1) {
            # First time in, initialise to the selected AssocID
            $intAssocID1 = $intAssocID;
        }      

        my $st = "
                SELECT A.intAssocID, A.strName 
                FROM tblTempNodeStructure T
                INNER JOIN tblAssoc A ON (A.intAssocID = T.intAssocID)
                WHERE T.int20_id = $intStateNodeID";

        my $DB_Assoc2 = getDBdrop_down( 'intAssocID2', $db, $st, $intAssocID2, '&nbsp;' );
        my $DB_Assoc1 = getDBdrop_down( 'intAssocID1', $db, $st, $intAssocID1, '&nbsp;' );
        $DB_Assoc2 =~ s/class = ""/class = "chzn-select"/g;
        $DB_Assoc1 =~ s/class = ""/class = "chzn-select"/g;

        $body .= qq[</table><h2 style="text-align:center;"> Add Interchange Agreement</h2>
                        <table  style="margin-left:auto;margin-right:auto;">
                        <tr>
                        <th>AssocID1</th>
                        <th>AssocID2</th>
                        <th>PermitType</th>
                        </tr>
                        ];
        my $permitDD = drop_down( 'intPermitTypeID', $Defs::clearancePermitType{2} );
        $permitDD =~ s/class = ""/class = "chzn-select"/g;
        $body .= qq[
                        <form method="post" action="">
                        <input type="hidden" name="method" value="insert">
                        <input type="hidden" name="action" value="ASSOC_agreements_manage">
            <td>$DB_Assoc1</td>
                        <td>$DB_Assoc2</td>
            <td>$permitDD</td>
                        </tr>
                        <tr><td colspan=6 align='right'><input type="submit" name="new" value="ADD INTERCHANGE AGREEMENT"></td></tr>
                        </table></form>
                        ];
    }
    $body .= qq[
                </td></tr></table>
                ];
    return $body;
}

sub edit_agreements {
    my ($db,$action,$target,$method,$intAssocID1,$intAssocID2,$intPermitTypeID, $intStateNodeID, $intRecStatus, $intAssocID) = @_;
    if ( $method ne 'update' && $method ne 'delete' && $method ne 'insert' ) {
        return 'Ooops, you broke it';
    }
    if ( $method eq 'update' ) {
        my $st = qq[
                UPDATE tblInterchangeAgreements
                SET intRecStatus = ?
                WHERE intAssocID1 = ?
                AND intAssocID2 = ?
                AND intPermitTypeID = ?];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute( $intRecStatus, $intAssocID2, $intAssocID1,
            $intPermitTypeID ) or query_error($st);
        $qry->execute( $intRecStatus, $intAssocID1, $intAssocID2,
            $intPermitTypeID ) or query_error($st);
    }
    elsif ( $method eq 'insert' ) {
        my $st = qq[
                INSERT IGNORE INTO tblInterchangeAgreements
                SET
                intAssocID1 = ?,
                intAssocID2 = ?,
                intPermitTypeID = ?,
                intStateNodeID = ?
                ];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute( $intAssocID1, $intAssocID2, $intPermitTypeID,
            $intStateNodeID ) or query_error($st);
        $qry->execute( $intAssocID2, $intAssocID1, $intPermitTypeID,
            $intStateNodeID ) or query_error($st);

    }
    my $hash_value = AdminCommon::create_hash_qs( 0, 0, $intAssocID1, 0, 0 );

    print "Location: ?action=ASSOC_agreements&intAssocID=$intAssocID1&hash=$hash_value\n\n";
    exit;
}

sub handle_holidays {
    my ( $db, $action, $target ) = @_;
    my $holiday_IN = param('hID')    || 0;
    my $method     = param('method') || '';
    my $body       = '';
    my $menu       = '';
    if ( $action eq 'UTILS_holidays_manage' && $method ne '' ) {
        $body = edit_holiday( $db, $action, $target, $method, $holiday_IN );
    }
    else {
        $body = list_holidays( $db, $action, $target, $holiday_IN );
    }
    return ( $body, $menu );
}

sub edit_holiday {
    my ( $db, $action, $target, $method, $intHolidayID ) = @_;
    my $strDate    = param("date");
    my $strHoliday = param("holiday");

    if ( $method ne 'update' && $method ne 'delete' && $method ne 'insert' ) {
        return 'Ooops, you broke it';
    }
    if ( ( $method == 'update' || $method == 'delete' )
        && $intHolidayID !~ /^\d+$/ )
    {
        return "<h2 style='color:red;'>YOU MUST SELECT A TEAMSHEET</h2>\n";
    }
    if ( $method eq 'update' ) {
        my $st = qq[
        UPDATE tblPaymentExclusions              
            SET
                strDate = ?,
                strHoliday = ?
                WHERE
                intPaymentExclusionID = ?];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute( $strDate, $strHoliday, $intHolidayID )
          or query_error($st);
    }
    elsif ( $method eq 'insert' ) {
        my $st = qq[
                INSERT INTO tblPaymentExclusions
                SET
                strDate = ?,
                strHoliday = ?
                ];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute( $strDate, $strHoliday ) or query_error($st);
        print STDERR $st;
    }
    elsif ( $method eq 'delete' ) {
        my $st = qq[
                DELETE FROM tblPaymentExclusions
        WHERE
                intPaymentExclusionID = ?];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute( $intHolidayID ) or query_error($st);
    }
    print "Location: ?action=UTILS_holidays\n\n";
    exit;
}

sub list_holidays {
    my ( $db, $action, $target, $intRecordID ) = @_;
    my $body = '';
    $intRecordID ||= 0;
    $body .= qq[
                <table  style="margin-left:auto;margin-right:auto;">
                <tr><td class="formbg">
            <h2> Current Payment Exclusions</h2><table width='100%' style="margin-left:auto;margin-right:auto;"  cellpadding=5 cellspacing=1 border=1>
                <tr>
                        <th>Event</th>
                        <th>Date (yyyy-mm-dd)</th>
            <th colspan=2>&nbsp;</th>
                </tr>
        ];

    my $statement = qq[
                SELECT * from tblPaymentExclusions ORDER BY strDate asc
            ];
    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    while ( my $dref = $query->fetchrow_hashref() ) {
        if ( $intRecordID == $dref->{intPaymentExclusionID} ) {

            $body .= qq[
                        <form method="post" action="">
                        <input type="hidden" name="action" value="UTILS_holidays_manage">
                        <input type="hidden" name="method" value="update">
                        <input type="hidden" name="hID" value="$dref->{intPaymentExclusionID}">
                        <tr>
                        <td><input type="holiday" name="holiday" value="$dref->{strHoliday}"></td>
                        <td><input type="text" name="date" value="$dref->{strDate}"></td>
                        <td><input type="submit" value="Edit" name="frmSubmit"></td></td></tr></form>
                             ];
        }
        else {
            $body .= qq[
                            <tr>
                                <td>$dref->{strHoliday}</td>
                                <td>$dref->{strDate}</td>
                        ];
            $body .= qq[<td><a href="?action=UTILS_holidays&hID=$dref->{intPaymentExclusionID}">Edit</a></td>
                       <td><a href="Javascript:confirm_delete($dref->{intPaymentExclusionID})">Delete</a></td> 
                       ];
            $body .= qq[   </tr>
                        ];
        }
    }
    $body .= "<script>
    function confirm_delete(sheet)
    {
        var agree=confirm('Are you sure you want to delete this Holiday?');
        if (agree)
                window.location = '?action=UTILS_holidays_manage&method=delete&hID='+sheet;
    }
    </script>";

    if ( $intRecordID == '' ) {
        $body .= qq[</table><h2 style="text-align:center;"> Add New Exclusion</h2>
            <table  style="margin-left:auto;margin-right:auto;">
            <tr>
                        <th>Event</th>
                        <th>Date</th>
                    </tr>
            ];
        $body .= qq[
                        <form method="post" action="">
                        <input type="hidden" name="method" value="insert">
                        <input type="hidden" name="action" value="UTILS_holidays_manage">
                        <td><input type="holiday" name="holiday" value=""></td>
                        <td><input type="text" name="date" value=""> (yyyy-mm-dd)</td>
            </tr>
            <tr><td colspan=6 align='right'><input type="submit" name="new" value="ADD EXCLUSION DATE"></td></tr>
            </table></form>
                    ];
    }
    $body .= qq[
                </td></tr></table>
            ];
    return $body;
}

sub decodeForm {
    my ( $target, $url ) = @_;
    my $body = '';
    my $menu = '';

    $body = qq[
        <table style="margin-left:auto;margin-right:auto;">
        <tr><td class="formbg"><h2>Decode URL</h2>
        
          <form action="$target" method="post">
                <b>URL to decode</b>: <input type = "text" value = "$url" size =" 100" name = "decodeurl"><br>
            <input type="submit" name="submit" value="Decode URL">
            <input type = "hidden" name="action" value="UTILS_decodeURL">
            </div>
          </form><br>
        </td></tr></table>
            ];
    return $body;
}

sub decodeInfo {
    my ( $url, $db, $cache ) = @_;

    #get clientstring
    my ($client) = $url =~ /.*client=(.*?)&/;
    return '' if !$client;
    my %clientValues = getClient($client) if $client;
    my @outdata = ();

    my %Data = (
        clientValues => \%clientValues,
        cache        => $cache,
        db           => $db,
    );

    if ( $clientValues{'interID'} and $clientValues{'interID'} > 0 ) {
        my $obj =
          getInstanceOf( \%Data, 'international', $clientValues{'interID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata,
              [ 'InternationalID', $clientValues{'interID'}, $name ];
        }
    }
    if ( $clientValues{'intregID'} and $clientValues{'intregID'} > 0 ) {
        my $obj =
          getInstanceOf( \%Data, 'intregion', $clientValues{'intregID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata,
              [ 'InternationalRegionID', $clientValues{'intregID'}, $name ];
        }
    }
    if ( $clientValues{'intzonID'} and $clientValues{'intzonID'} > 0 ) {
        my $obj =
          getInstanceOf( \%Data, 'intzone', $clientValues{'intzonID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata,
              [ 'InternationalZoneID', $clientValues{'intzonID'}, $name ];
        }
    }
    if ( $clientValues{'natID'} and $clientValues{'natID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'national', $clientValues{'natID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata, [ 'NationalID', $clientValues{'natID'}, $name ];
        }
    }
    if ( $clientValues{'stateID'} and $clientValues{'stateID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'state', $clientValues{'stateID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata, [ 'StateID', $clientValues{'stateID'}, $name ];
        }
    }
    if ( $clientValues{'regionID'} and $clientValues{'regionID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'region', $clientValues{'regionID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata, [ 'RegionID', $clientValues{'regionID'}, $name ];
        }
    }
    if ( $clientValues{'zoneID'} and $clientValues{'zoneID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'zone', $clientValues{'zoneID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata, [ 'ZoneID', $clientValues{'zoneID'}, $name ];
        }
    }
    if ( $clientValues{'assocID'} and $clientValues{'assocID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'assoc', $clientValues{'assocID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata,
              [
                'AssocID', $clientValues{'assocID'},
                "<a href='?action=DATA&type=intAssocID&useID="
                  . $clientValues{'assocID'} . "'>"
                  . $name . "</a>"
              ];
        }
    }
    if ( $clientValues{'compID'} and $clientValues{'compID'} ) {
        my $obj = getInstanceOf( \%Data, 'comp', $clientValues{'compID'}, );
        if ($obj) {
            my $name = $obj->getValue('strTitle') || '';
            push @outdata,
              [
                'CompID', $clientValues{'compID'},
                "<a href='?action=DATA&type=intCompID&useID="
                  . $clientValues{'compID'}
                  . "&intAssocID="
                  . $clientValues{'assocID'} . "'>"
                  . $name . "</a>"
              ];
        }
    }
    if ( $clientValues{'clubID'} and $clientValues{'clubID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'club', $clientValues{'clubID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata,
              [
                'ClubID', $clientValues{'clubID'},
                "<a href='?action=DATA&type=intClubID&useID="
                  . $clientValues{'clubID'} . "'>"
                  . $name . "</a>"
              ];
        }
    }
    if ( $clientValues{'teamID'} and $clientValues{'teamID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'team', $clientValues{'teamID'}, );
        if ($obj) {
            my $name = $obj->getValue('strName') || '';
            push @outdata,
              [
                'TeamID', $clientValues{'teamID'},
                "<a href='?action=DATA&type=intTeamID&useID="
                  . $clientValues{'teamID'} . "'>"
                  . $name . "</a>"
              ];
        }
    }
    if ( $clientValues{'memberID'} and $clientValues{'memberID'} > 0 ) {
        my $obj = getInstanceOf( \%Data, 'member', $clientValues{'memberID'}, );
        if ($obj) {
            my $name = $obj->name() || '';
            push @outdata,
              [
                'MemberID', $clientValues{'memberID'},
                "<a href='?action=DATA&type=intMemberID&useID="
                  . $clientValues{'memberID'} . "'>"
                  . $name . "</a>"
              ];
        }
    }

    push @outdata,
      [
        'Current Level',
        $clientValues{'currentLevel'},
        $Defs::LevelNames{ $clientValues{'currentLevel'} }
      ];
    push @outdata,
      [
        'Auth Level',
        $clientValues{'authLevel'},
        $Defs::LevelNames{ $clientValues{'authLevel'} }
      ];
    push @outdata, [ 'Username', $clientValues{'userName'}, '' ];

    my $body = '';
    for my $row (@outdata) {
        $body .= qq{
            <tr>
                <td class="formbg">$row->[0]</td>
                <td class="formbg">$row->[1]</td>
                <td class="formbg">$row->[2]</td>
            </tr>
        };
    }
    $body = qq[
    <table class="formbg" style="margin-left:auto;margin-right:auto;">
            $body
        </table>
    ];
    return $body;

}

sub handle_categories {
    my ( $db, $action, $target ) = @_;
    my $category_IN = param('cID')    || 0;
    my $method      = param('method') || '';
    my $body        = '';
    my $menu        = '';
    if ( $action eq 'UTILS_categories_manage' && $method ne '' ) {
        $body = edit_category( $db, $action, $target, $method, $category_IN );
    }
    else {
        $body = list_categories( $db, $action, $target, $category_IN );
    }
    return ( $body, $menu );
}

sub edit_category {
    my ( $db, $action, $target, $method, $intCategoryID ) = @_;
    my $intRealmID      = param("realmID")      || '';
    my $intSubRealmID   = param("subRealmID")   || '';
    my $intAssocID      = param("assocID")      || '';
    my $intEntityType   = param("entityType")   || '';
    my $strCategoryName = param("categoryName") || '';
    my $strCategoryDesc = param("categoryDesc") || '';

    if ( $method ne 'update' && $method ne 'insert' ) {
        return 'Ooops, you broke it';
    }
    if ( ( $method eq 'update' ) && $intCategoryID !~ /^\d+$/ ) {
        return "<h2 style='color:red;'>YOU MUST SELECT A Category</h2>\n";
    }
    if ( $method eq 'insert'
        && ( $intRealmID < 0 || ( $intEntityType != 3 && $intEntityType != 5 ) )
      )
    {
        return "<h2 style='color:red;'>YOU MUST SELECT A Realm & EntityType Must be 3 or 5</h2>\n";
    }

    if ( $method eq 'update' ) {
        my $st = qq[
        UPDATE tblEntityCategories
            SET
                strCategoryName = ?,
                strCategoryDesc = ?
                WHERE
                intEntityCategoryID = ?];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute( $strCategoryName, $strCategoryDesc, $intCategoryID )
          or query_error($st);
        warn $st . "|"
          . $intCategoryID . "|"
          . $strCategoryDesc . "|"
          . $strCategoryName;
    }
    elsif ( $method eq 'insert' ) {
        my $st = qq[
                INSERT INTO tblEntityCategories
                SET
                intRealmID = ?,
                intSubRealmID = ?,
                intAssocID = ?,
                intEntityType = ?,
                strCategoryName = ?,
                strCategoryDesc = ?
                ];
        my $qry = $db->prepare($st) or query_error($st);
        $qry->execute(
            $intRealmID,    $intSubRealmID,   $intAssocID,
            $intEntityType, $strCategoryName, $strCategoryDesc
        ) or query_error($st);
    }
    print "Location: ?action=UTILS_categories\n\n";
    exit;
}

sub list_categories {
    my ( $db, $action, $target, $intRecordID ) = @_;
    my $body = '';
    $intRecordID ||= 0;
    $body .= qq[
                <table  style="margin-left:auto;margin-right:auto;">
                <tr><td class="formbg">
                <h2> Current Entity Categories</h2><table width='100%' style="margin-left:auto;margin-right:auto;"  cellpadding=5 cellspacing=1 border=1>
                <tr>
                        <th>Realm ID</th>
                        <th>SubRealm ID</th>
                        <th>Assoc ID</th>
                        <th>Entity Type</th>
                        <th>Category Name</th>
                        <th>Category Desc</th>
                <th colspan=2>&nbsp;</th>
                </tr>
        ];

    my $statement = qq[
                SELECT * from tblEntityCategories ORDER BY intRealmID, intEntityType, tTimeStamp
            ];
    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    while ( my $dref = $query->fetchrow_hashref() ) {
        if ( $intRecordID == $dref->{intEntityCategoryID} ) {

            $body .= qq[

                        <form method="post" action="">
                        <input type="hidden" name="action" value="UTILS_categories_manage">
                        <input type="hidden" name="method" value="update">
                        <input type="hidden" name="cID" value="$dref->{intEntityCategoryID}">
                        <tr>
            
                                <td>$dref->{intRealmID}</td>
                                <td>$dref->{intSubRealmID}</td>
                                <td>$dref->{intAssocID}</td>
                                <td>$dref->{intEntityType}</td>
                        <td><input type="text" name="categoryName" value="$dref->{strCategoryName}"></td>
                        <td><input type="text" name="categoryDesc" value="$dref->{strCategoryDesc}"></td>
                        <td><input type="submit" value="Edit" name="frmSubmit"></td></td></tr></form>
                             ];

        }
        else {
            $body .= qq[
                            <tr>
                                <td>$dref->{intRealmID}</td>
                                <td>$dref->{intSubRealmID}</td>
                                <td>$dref->{intAssocID}</td>
                                <td>$dref->{intEntityType}</td>
                                <td>$dref->{strCategoryName}</td>
                                <td>$dref->{strCategoryDesc}</td>
                        ];
            $body .= qq[<td><a href="?action=UTILS_categories&cID=$dref->{intEntityCategoryID}">Edit</a></td>
                             ];
            $body .= qq[   </tr>
                        ];
        }
    }

    if ( $intRecordID == '' ) {
        $body .= qq[</table><h2 style="text-align:center;"> Add New Entity Category</h2>
            <table  style="margin-left:auto;margin-right:auto;">
            <tr>

                        <th>Realm ID</th>
                        <th>SubRealm ID</th>
                        <th>Assoc ID</th>
                        <th>Entity Type</th>
                        <th>Category Name</th>
                        <th>Category Desc</th>
                    </tr>
            ];
        $body .= qq[
                        <form method="post" action="">
                        <input type="hidden" name="method" value="insert">
                        <input type="hidden" name="action" value="UTILS_categories_manage">
                        

                                <td><input type="text" name="realmID" value=""></td>
                                <td><input type="text" name="subRealmID" value=""></td>
                                <td><input type="text" name="assocID" value="0"></td>
                                <td><input type="text" name="entityType" value="5"></td>
                        <td><input type="text" name="categoryName" value=""></td>
                        <td><input type="text" name="categoryDesc" value=""></td>

            </tr>
            <tr><td colspan=6 align='right'><input type="submit" name="new" value="ADD ENTITY CATEGORY"></td></tr>
            </table></form>
                    ];
    }
    $body .= qq[
                </td></tr></table>
            ];
    return $body;
}

