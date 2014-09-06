#
# $Header: svn://svn/SWM/trunk/web/admin/UtilsAdmin.pm 8248 2013-04-08 07:55:17Z dhanslow $
#

package TempRegos;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(DisplayTempRegos searchTempRegos);
@EXPORT_OK = qw(DisplayTempRegos searchTempRegos);

use strict;
use lib ".","..","../..";
use Defs;
use Utils;
use Reg_common;
use InstanceOf;
use MCache;
use CGI qw(param unescape escape);
use DBI;
use GridDisplayAdmin;
use Data::Dumper;

sub searchTempRegos {
    my($db) =@_;
    my $body =qq[
             <form>
                <h3 align="center"> Search by: </h3>
                <table align="center"> 
                    <tr>
                        <td><label> Form ID :</label></td>
                        <td><input name ="formID" type="text" value="" /> </td>
                    </tr>
                    <tr>
                        <td><label> Temp ID :</label></td>
                        <td><input name ="tempID" type="text" value="" /> </td>
                    </tr>
                    <tr>
                        <td><label> Association ID :</label></td>
                        <td><input name ="assocID" type="text" value="" /> </td>
                    </tr>
                    <tr>
                        <td><input type="submit" name="submit" value="Display List">
                           <input type = "hidden" name="action" value="TempReg_Display"></td>
                     </tr>
            </table>
            </form>
        ];
    
}
sub DisplayTempRegos {
    my ($db, $formID, $tempID,$assocID) = @_;
    my $json_string;
    my $deserial;
    my $name;
    my $email;
    my $where = qq[ ];
    my  @vals =();
    if (!$formID and !$tempID and !$assocID ){
        return "I don't know what to search for!";
    }
    if($formID and $formID !=-1 ) {
        $where =  qq[ AND intFormID = ? ];
        push  @vals,$formID;
    }
    if($tempID){    
        $where .= qq[ AND intTempMemberID = ?  ];
        push  @vals,$tempID;
    }
    if($assocID){    
        $where .= qq[ AND intAssocID = ?  ];
        push  @vals,$assocID;
    }
    my $st = qq[
                SELECT
                    *
                FROM
                    tblTempMember
                WHERE
                    1
                    $where
                ];

    my $body = qq[];
    my $query = $db->prepare($st);
    $query->execute(@vals);
    my @rowdata =();

    while (my $dref =$query->fetchrow_hashref())	{
        $json_string = $dref->{'strJson'};
	    $deserial = JSON::from_json($json_string); 
        $name =$deserial->{'strName'} || $deserial->{'strFirstname'}.$deserial->{'strSurname'} ;
        $email = $deserial->{'strEmail'};
        push @rowdata ,{
            id => $dref->{'intTempMemberID'},
            RealID => $dref->{'intRealID'},
            FormID => $dref->{'intFormID'},
            Name=> $name,
            Email=>$email,
            Session => $dref->{'strSessionKey'},
            Transactions => $dref->{'strTransactions'},
            AssocID => $dref->{'intAssocID'},
            ClubID => $dref->{'intClubID'},
            TeamID => $dref->{'intTeamID'},
            Status => $dref->{'intStatus'},
            TransLogID => $dref->{'intTransLogID'},
            tTimestamp => $dref->{'tTimestamp'},
        };
		
    }

    my @headers =(
        {
            name  => 'TempID',
            field => 'id',
             sorttype =>'number',
        },
        {
            name  => 'RealID',
            field => 'RealID',
            allowsort =>1,
            sorttype =>'number',
        },
        {
            name  => 'FormID',
            field => 'FormID',
            sorttype =>'number',
        },
        {
            name  => 'Name',
            field => 'Name',
        },
         {
            name  => 'Email',
            field => 'Email',
        },
        {
            name  => 'Session',
            field => 'Session',
        },
        
        {
            name => "Transactions",
            field => "Transactions",
             sorttype =>'number',
        },
        {
            name => "AssocID",
            field => "AssocID",
             sorttype =>'number',
        },
        {
            name => "ClubID",
            field => "ClubID",
            sorttype =>'number',
	},
        {
            name => "TeamID",
            field => "TeamID",
             sorttype =>'number',
        },
        {
            name => "Status",
            field => "Status",
        },
        {
            name => "TransLogID",
            field => "TransLogID",
             sorttype =>'number',
        },
        {
            name => "tTimestamp",
            field => "tTimestamp",
        },
	);
    my $Data = {};
    my $grid .= showGrid (
        Data =>$Data,
        columns => \@headers,
        rowdata=> \@rowdata,
        gridid=>'grid',
        simple=>0,
        width => 1600,
        height => 1100,
        font_size => "1.1em"
    );
    #width => 1400,
    #height => 1100,
    #filters => $filterfields,
    #font_size => "1.2em"
    $body .= qq[
        <div class="_grid-filter-wrap">
            $grid
        </div>
    ];

    return $body;  

}

1;
