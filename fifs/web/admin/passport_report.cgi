#!/usr/bin/perl
use strict;

use lib '.', '..', '../..';

use Data::Dumper;
use DBI;
use XML::Simple;
use LWP::UserAgent;
use CGI;
use Defs;
use Utils;

my $db = connectDB(); #DBI->connect('DBI:mysql:', '', '', { RaiseError => 1 }); 
my $result = undef;
my $pid_list = undef;
my $st = '';

$st = qq[
    SELECT
        P.intPassportID,
        CASE P.intEntityTypeID
            WHEN 100 THEN 'National'
            WHEN 30  THEN 'State'
            WHEN 20  THEN 'Region'
            WHEN 10  THEN 'Zone'
        ELSE ''
        END AS EntityType,
        N.strName AS EntityName,
        P.intEntityID,
        P.dtLastlogin,
        P.dtCreated
    FROM
        tblPassportAuth AS P
        INNER JOIN tblNode AS N ON ( P.intEntityTypeID IN (100,30,20,10) AND P.intEntityID=N.intNodeID AND P.intEntityTypeID=N.intTypeID)
    ORDER BY P.intEntityTypeID DESC
];
( $result, $pid_list ) = merge_result( $db, $st, $result, $pid_list );
$st = qq[
    SELECT
        P.intPassportID,
        'Association' AS EntityType,
        A.strName AS EntityName,
        P.dtLastlogin,
        P.dtCreated
    FROM
        tblPassportAuth AS P
        INNER JOIN tblAssoc AS A ON ( P.intEntityTypeID=5 AND P.intEntityID=A.intAssocID )
];
( $result, $pid_list ) = merge_result( $db, $st, $result, $pid_list );
$st = qq[
    SELECT
        P.intPassportID,
        'Club' AS EntityType,
        C.strName AS EntityName,
        P.dtLastlogin,
        P.dtCreated
    FROM
        tblPassportAuth AS P
        INNER JOIN tblClub AS C ON ( P.intEntityTypeID=3 AND P.intEntityID=C.intClubID )
];
( $result, $pid_list ) = merge_result( $db, $st, $result, $pid_list );
$st = qq[
    SELECT
        P.intPassportID,
        'Team' AS EntityType,
        T.strName AS EntityName,
        P.dtLastlogin,
        P.dtCreated
    FROM
        tblPassportAuth AS P
        INNER JOIN tblTeam AS T ON ( P.intEntityTypeID=2 AND P.intEntityID=T.intTeamID )
];
( $result, $pid_list ) = merge_result( $db, $st, $result, $pid_list );

my $pid_info = bulk_details(keys %{$pid_list});
my $table = '';

$table .= qq[<tr><td>EntityType</td><td>EntityName</td><td>PassportID</td><td>FirstName</td><td>FamilyName</td><td>Email</td><td>DateCreated</td><td>DateAdded</td><td>DateLastLogin</td></tr>];
for my $db_row ( @{$result} ) {
    my $pid = $db_row->{'PassportID'};
    my $pp_row = $pid_info->{$pid};
    $table .= '<tr>';
    $table .= "<td>$db_row->{'EntityType'}</td>";
    $table .= "<td>$db_row->{'EntityName'}</td>";
    $table .= "<td>$db_row->{'PassportID'}</td>";
    $table .= "<td>$pp_row->{'FirstName'}</td>";
    $table .= "<td>$pp_row->{'FamilyName'}</td>";
    $table .= "<td>$pp_row->{'Email'}</td>";
    $table .= "<td>$pp_row->{'Created'}</td>";
    $table .= "<td>$db_row->{'DateAdded'}</td>";
    $table .= "<td>$db_row->{'DateLastLogin'}</td>";
    $table .= '</tr>';
}

my $cgi = CGI->new();
print $cgi->header();
my $html = qq[
<html>
<head>
    <title>Passport Report</title>
</head>
<body>
<table border="1">
    $table
</table>
</body>
</html>
];
print "$html";

print STDERR "DONE\n";

sub merge_result {
    my ( $db, $st, $result, $pid_list ) = @_;

    print STDERR "get unique passportIDs from $st\n";

    my $q = $db->prepare($st);
    print STDERR "get passportAuth info\n";
    $q->execute();
    while ( my $hr = $q->fetchrow_hashref() ) {
        my $pid = $hr->{'intPassportID'};
        my $r = {
            'EntityType'    => $hr->{'EntityType'},
            'EntityName'    => $hr->{'EntityName'},
            'PassportID'    => $pid,
            'DateAdded'     => $hr->{'dtCreated'},
            'DateLastLogin' => $hr->{'dtLastlogin'},
        };
        $pid_list->{$pid} = 1;
        
        push @{$result}, $r;
    }
    
    return $result, $pid_list;
}

sub bulk_details {
    my @passport_ids = @_;

    my $data_ref = {};
    my $count = 10000;
    my $length = scalar @passport_ids;
    for ( my $i = 0;; $i++ ) { 
        print STDERR "call BulkDetails -- ";

        my $start = $i * $count;
        my $finish = 0;
        if ( ( $start + $count ) >= $length ) { 
            $finish = $length - 1;
        }
        else {
            $finish = $start + $count - 1;
        }

        my $api_data_ref = talk_to_passport( 'BulkDetails', { 'Passports' => join( ',', @passport_ids[$start..$finish] ), 'IncludeSports' => 1 } );
        for my $item ( @{ $api_data_ref->{'Response'}{'Data'}{'Passports'} } ) { 
            my $k = $item->{'PassportID'};
            $data_ref->{$k}->{'PassportID'} = $k;
            $data_ref->{$k}->{'FirstName'} = $item->{'FirstName'};
            $data_ref->{$k}->{'FamilyName'} = $item->{'FamilyName'};
            $data_ref->{$k}->{'Email'} = $item->{'Email'};
            $data_ref->{$k}->{'Created'} = $item->{'Created'};
        }
        if ( ( $start + $count ) >= $length ) { 
            printf STDERR ( "get %5d ids -- ", $length - $start );
            print STDERR "finish call\n";
            last;
        }
        else {
            printf STDERR ( "get %5d ids -- ", $count );
            print STDERR "continue call\n";
            next;
        }
    }   

    return $data_ref;
}

sub talk_to_passport {
    my ( $action, $data ) = @_; 

    my $app_signature = 'LftnCjFIg2N9GT7aQZORxDSWuopXeY';
    my $passport_url  = "https://passport.sportingpulse.com/api/";
    my $ua            = LWP::UserAgent->new;
    $ua->agent('SWM');
    my $request_obj = HTTP::Request->new( GET => $passport_url );
    my %Request = ( 
        Request => {
            Version      => '1.0',
            Action       => $action,
            AppSignature => $app_signature,
            Data         => $data,
        },
    );  

    my $msg = XMLout( \%Request, KeepRoot => 1, NoAttr => 1, KeyAttr => [] );

    $request_obj->header( 'Content-type' => 'application/xml' );
    $request_obj->content($msg);

    my $response_obj = $ua->request($request_obj);
    my $responsetxt  = ''; 
    my $response     = ''; 

    if ( $response_obj->is_success ) { 
        $responsetxt = $response_obj->content;
        $response    = XMLin(
            $responsetxt,
            ForceArray => ['Passports'],
            KeyAttr    => [], 
            SuppressEmpty => '', 
            KeepRoot   => 1
        );
    }   

    return $response;
}


$db->disconnect;
