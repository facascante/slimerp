#
# $Header: svn://svn/SWM/trunk/web/admin/SchoolAdmin.pm 10066 2013-12-01 22:51:29Z tcourt $
#

#;ckage AuskickAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(schoolAdmin);
@EXPORT_OK = qw(schoolAdmin);


use strict;
use warnings;

use CGI qw(param escape unescape);

use lib "../comp","../..","..",".";

use DBI;
use Utils;
use HTMLForm;
use AdminPageGen;
use FormHelpers;


sub schoolAdmin {
    
  my ($db,$target) = @_;

    my $returnstr = '';
    my $act    = param('a')      || '';
    my $id        = param('id')     || '';
    my $filter    = param('filter') || 'A';
    my $srealm    = param('srealm') || 1;

    my %school_realms = (
          1 => 'FootyWeb',
          3 => 'NZ Football',
    );

    if($act eq "ed") {
        $returnstr = edit_school($db, $id, $target, \%school_realms, $srealm, $filter);
    }
    elsif ($act eq "del") {
        $returnstr = delete_school($db, $target, $id);
    }
    else {
        $returnstr = list($db, $target, \%school_realms, $srealm, $filter);
    }

    $returnstr .= qq[<br><br><a href="$target?srealm=$srealm&amp;filter=$filter">Return to List</a>];

    return $returnstr;
}


sub edit_school {
    my ($db, $id, $target, $school_realms, $srealm, $filter) = @_;

    my $option = 'edit';
    $option = 'add' if !$id;
    my $field = loadDetails($db, $id) || ();


    my %FieldDefs =(
        fields=>  {
            strName => {
                label => 'School Name',
                value => $field->{strName},
                type  => 'text',
                size  => '100',
                compulsory => 1,
            },

            strAddress1 => {
                label => 'Address Line 1',
                value => $field->{strAddress1},
                type  => 'text',
                size  => '50',
            },
            strAddress2 => {
                label => 'Address Line 2',
                value => $field->{strAddress2},
                type  => 'text',
                size  => '50',
            },
            strSuburb => {
                label => 'Suburb',
                value => $field->{strSuburb},
                type  => 'text',
                size  => '50',
                compulsory => 1,
            },
            strState => {
                label => 'State',
                value => $field->{strState},
                type  => 'text',
                size  => '15',
                compulsory => 1,
            },
            strPostalCode => {
                label => 'Postcode',
                value => $field->{strPostalCode},
                type  => 'text',
                size  => '15',
                compulsory => 1,
            },
            intSchoolRealm => {
                label => 'School Realm',
                value => $field->{intSchoolRealm} || $srealm,
                type  => 'lookup',
                options => $school_realms,
                compulsory => 1,
            },
        },
        order => [qw(strName strAddress1 strAddress2 strSuburb strState strPostalCode intSchoolRealm)],
        options => {
            labelsuffix => ':',
            hideblank => 1,
            target => $target,
            formname => 'n_form',
            submitlabel => "Update ",
            introtext => 'auto',
            updateSQL => qq[
                UPDATE tblSchool
                    SET --VAL--
                WHERE intSchoolID=$id
            ],
            addSQL => qq[
                INSERT INTO tblSchool
                    ( --FIELDS-- )
                VALUES ( --VAL-- )
            ],
        },
        carryfields =>  {
            a  => 'ed',
            action=>'UTILS_school',
	    id => $id,
            srealm => $srealm,
            filter => $filter,
        },
    );

    my $resultHTML = '';

    ($resultHTML, undef) = handleHTMLForm(\%FieldDefs, undef, $option, '', $db);

    return $resultHTML;
}

sub list {
    my ($db, $target, $school_realms, $srealm, $filter) = @_;

    my $cgi = new CGI;

    my $where = qq[ 
        WHERE intSchoolRealm=$srealm
    ];

    $where .= qq[ AND strName like "$filter%"]  if $filter;

    my $statement = qq[
        SELECT intSchoolID, strName, strSuburb, strState, strPostalCode, intSchoolRealm
        FROM tblSchool
        $where
        ORDER BY strName
    ];

    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);

    #grabbed jb's code here from events. works ok, but has his usual maps and joins :-(
    my @m_array = ();
    while (my $m_ref = $query->fetchrow_hashref()) { push @m_array, $m_ref; }
    $query->finish();
    my $m_ref = \@m_array;

    my $srealm_bar = qq[
        <a href=$target?action=UTILS_school&srealm=1&amp;filter=$filter>Footyweb</a>&nbsp|&nbsp<a href=$target?action=UTILS_school&srealm=3&amp;filter=$filter>NZ Football</a>
        <br><br>
    ];

    my $alphabet_bar = join('&nbsp|&nbsp', map { $cgi->a( { -href => "$target?action=UTILS_school&srealm=$srealm&amp;filter=$_" }, $_ ) } ('A' .. 'Z')) . $cgi->br() x 2;

    my $returnstring = qq[
        <h3>School List</h3>
        $srealm_bar
        $alphabet_bar
        <a href="$target?action=UTILS_school&a=ed&amp;srealm=$srealm&amp;filter=$filter">Add School</a>
        <br><br>
        <table>
            <tr>
                <td style="font-weight:bold">Name</td>
                <td style="font-weight:bold">Suburb</td>
                <td style="font-weight:bold">State</td>
                <td style="font-weight:bold">Postcode</td>
                <td style="font-weight:bold">School Realm</td>
            </tr>
    ];

    for my $m_key (0 .. $#$m_ref)   {
        my $school_id = $m_ref->[$m_key]{intSchoolID};
        my $school_realm = $school_realms->{$m_ref->[$m_key]{intSchoolRealm}};
        $returnstring .= qq[
            <tr>
                <td>$m_ref->[$m_key]{strName}</td>
                <td>$m_ref->[$m_key]{strSuburb}</td>
                <td>$m_ref->[$m_key]{strState}</td>
                <td>$m_ref->[$m_key]{strPostalCode}</td>
                <td>$school_realm</td>
                <td><a href="$target?action=UTILS_school&id=$school_id&amp;a=ed&amp;srealm=$srealm&amp;filter=$filter">Edit</a>
                    &nbsp|&nbsp
                    <a href="$target?action=UTILS_school&id=$school_id&amp;a=del&amp;srealm=$srealm&amp;filter=$filter" onclick="return confirm('Are you sure you want to delete the selected school?');">Delete</a>
                </td>
            </tr>
        ];
    }

    $returnstring .= qq[
        </table>
        <br><br>
        <a href="$target?action=UTILS_school&a=ed&amp;srealm=$srealm">Add School</a>
        <br>
    ];
}

sub loadDetails {
    my($db, $id) = @_;

    return {} if !$id;

    my $statement = qq[
      SELECT *
      FROM tblSchool
      WHERE intSchoolID=$id
    ];

    my $query = $db->prepare($statement);
    $query->execute;

    my $field=$query->fetchrow_hashref();
    $query->finish;

    foreach my $key (keys %{$field}) { 
        if (!defined $field->{$key}) { $field->{$key} = ''; } 
    }

    return $field;
}

sub delete_school    {
    my ($db, $target, $id) = @_;
    return 'Invalid ID' if !$id;

    my $st = qq[
        DELETE FROM tblSchool
        WHERE intSchoolID=$id
    ];
    $db->do($st);

    return 'School deleted';
}
