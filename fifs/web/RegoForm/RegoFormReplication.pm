#
# $Header: svn://svn/SWM/trunk/web/RegoFormReplication.pm 8251 2013-04-08 09:00:53Z rlee $
#

package RegoFormReplication;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(handleFormReplication);
@EXPORT_OK = qw(handleFormReplication);

use strict;
use Reg_common;
use Utils;
use Defs;
use CGI qw(param Vars);

use RegoFormCreateFromForm;


sub handleFormReplication {
    my ($action, $Data) = @_;

    my $resultHTML = '';
    my $title = 'Form Replication';

    if ($action =~ /^RFR_rtc1/) {
        $resultHTML = select_clubs($Data);
    }
    elsif ($action =~ /^RFR_rtc2/) {
        $resultHTML = process_clubs($Data);
    }
    elsif ($action =~ /^RFR_mac/) {
        $resultHTML = make_a_copy($Data);
    }
    return ($resultHTML, $title);
}


sub select_clubs {
    my ($Data) = @_;

    my $formID = param('fID') || 0;
    return if !$formID;

    my $client = setClient($Data->{'clientValues'}) || '';
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0;
    my $assocID = $Data->{'clientValues'}->{'assocID'} || 0;
    my $dbh = $Data->{'db'};

    my $sql = '';
    my $body = '';

    $sql = qq[
        SELECT c.intClubID, c.strName
        FROM tblClub c
        JOIN tblAssoc_Clubs ac ON c.intClubID=ac.intClubID 
        WHERE ac.intAssocID=$assocID AND c.intRecStatus=$Defs::RECSTATUS_ACTIVE AND ac.intRecStatus=$Defs::RECSTATUS_ACTIVE
        ORDER BY c.strName
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

    my $clubList = '';

    while (my $dref = $query->fetchrow_hashref()) {
        $clubList .= qq[
            <tr>
              <td><input type="checkbox" name="cid_$dref->{'intClubID'}" value="1" class="check"></td>
              <td class="label HTvertform-l">$dref->{'strName'}</td>
            </tr>
        ];
    }
    $body = qq[
        <script type="text/javascript">
          jQuery().ready(function() {
            jQuery("#checkall").click(function(){
              if (jQuery(this).is(':checked')) {
                  jQuery('.check').attr('checked', true);
              }
              else {
                  jQuery('.check').attr('checked', false);
              }
            });
          });
        </script>
        <style>
          th, td { padding:3px; }
          th { font-style:italic; background-color:#D9E7F8; padding-bottom:5px; }
        </style>
        <p>Select the clubs you want the form to be replicated to:</p>
        <div id="messagearea" class="warningmsg" style="width:300px;margin-left:0;display:none">
          <ul>Please select at least one club!</ul>
        </div>
        <br>
        <form id="frmClubs" action="$Data->{'target'}" method="POST">
          <table>
            <tr>
              <th><input type="checkbox" name="checkall" id="checkall"</th>
              <th>Club Name</th>
            </tr>
            $clubList
          </table>
          <br>
          <input type="hidden" name="client" value="$client">
          <input type="hidden" name="a" value="RFR_rtc2">
          <input type="hidden" name="fID" value="$formID">
          <input type="submit" name="btnNext" value="Next >>" class="submit">
        </form>

        <script type="text/javascript"> // 
          jQuery("#frmClubs").submit(function(){
            if (jQuery("#frmClubs input:checked").length <= 0){
                jQuery("#messagearea").show();
                return false;
            }
            jQuery("#messagearea").hide();
            return true;
          });
        </script>
    ];

    return $body;
}


sub process_clubs {
    my ($Data) = @_;

    my $formID = param('fID') || 0;
    return if !$formID;

    my %params = Vars();
    my @clubs = ();

    for my $key (keys %params)  {
        if ($key =~ /^cid_/ and $params{$key} == 1) {
            my $c = $key;
            $c =~ s/^cid_//;
            push @clubs, $c;
        }
    }

    my $body = '';

    if (!@clubs) {
        $body = qq[
            <div class="warningmsg">No clubs found to replicate form $formID to!</div>
        ];
        return $body;
    }

    my $dbh = $Data->{'db'};
    my $client = setClient($Data->{'clientValues'}) || '';

    $body = qq[
        <style>
          th, td { padding:5px; }
          th { font-style:italic; background-color:#d9e7f8; padding-bottom:5px; }
        </style>
        <div>Form #$formID has been replicated as follows:</div>
        <br>
        <table>
          <tr>
            <th>Club Name</th>
            <th>Result</th>
            <th>Form #</th>
          </tr>
    ];

    for my $clubID(@clubs) {
        my $sufa = '';
        my $nid  = '';
        my $col = '';
        my ($result, $message) = create_from_form($Data, $Defs::RFCOPYTYPE_ASSOC_TO_CLUB, $formID, $clubID);

        if ($result > 0) {
            $sufa = 'Success';
            $nid  = $result;
            $col = 'green';
        }
        else {
            $sufa = 'Failure';
            $col = '#fddde0';
        }
        
        my $sql = '';

        $sql = qq[
            SELECT strName
            FROM tblClub
            WHERE intClubID=$clubID
        ];

        my $query = $dbh->prepare($sql);
        $query->execute;

        my $clubName = $query->fetchrow_array();

        $body .= qq[
            <tr>
              <td>$clubName</td>
              <td style="color:$col">$sufa</td>
              <td>$nid</td>
            </tr>
        ];
    }

    my $btrfForm = get_btrf_form($Data);

    $body .= qq[
        </table>
        $btrfForm
    ];

    return $body;
}


sub make_a_copy {
    my ($Data) = @_;

    my $formID = param('fID') || 0;
    return if !$formID;

    my $body = '';

    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};

    my $copyType = ($currentLevel = $Defs::LEVEL_ASSOC)
        ? $Defs::RFCOPYTYPE_WITHIN_ASSOC
        : $Defs::RFCOPYTYPE_WITHIN_CLUB;

    my ($result, $message) = create_from_form($Data, $copyType, $formID);

    my $class = ($result > 0)
        ? 'OKmsg'
        : 'warningmsg';

    my $btrfForm = get_btrf_form($Data);

    $body = qq[
        <div class="$class" style="width:375px;margin-left:0;">$message</div>
        $btrfForm
    ];

    return $body;
}


sub get_btrf_form {
    my ($Data) = @_;

    my $client = setClient($Data->{'clientValues'}) || '';

    my $btrfForm = qq[
        <br>
        <form>
          <input type="hidden" name="client" value="$client">
          <input type="hidden" name="a" value="A_ORF_r">
          <input type="submit" name="btnBack" value="Back to Registration Forms >>" class="submit">
        </form>
    ];

    return $btrfForm;
}


1;
