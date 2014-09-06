#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_EOI.pm 10413 2014-01-13 03:05:35Z dhanslow $
#

package Reports::ReportAdvanced_EOI;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
use Reg_common;
our @ISA =qw(Reports::ReportAdvanced);


use strict;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $SystemConfig = $self->{'SystemConfig'};
	my $clientValues = $Data->{'clientValues'};


	my %config = (
		Name => 'Expressions of Interest',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 3,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,

		Fields => {

        AssocName=> ["$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblAssoc.strName'}],
        ClubName=> ["$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblClub.strName'}],
        strFirstname => ['Firstname',{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1}],
        strSurname => ['Surname',{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1}],
        dtDOB=> ['Date of Birth',{displaytype=>'date', fieldtype=>'date', dbfield=>'tblEOI.dtDOB', dbformat=>' DATE_FORMAT(tblEOI.dtDOB,"%d/%m/%Y")'}, active=>1],
        dtCreated=> ['Date Registered Interest',{allowsort=>1,displaytype=>'date', fieldtype=>'date', dbfield=>'tblEOI.dtCreated', dbformat=>' DATE_FORMAT(tblEOI.dtCreated,"%d/%m/%Y")'}, active=>1],
        strPostalCode=> ['Postal Code',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblEOI.strPostalCode'}],
        strPhone=> ['Phone',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblEOI.strPhone'}],
        strEmail=> ['Email',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblEOI.strEmail', active=>1}],
        intOptIn=> ['Opt In',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> {0=>'No', 1=>'Yes'}, dbfield=>'tblEOI.intOptIn'}],
        strEmail=> ['Email',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblEOI.strEmail', active=>1}],
        strGender=> ['Gender',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{''=>'&nbsp;', 'M'=>'Male', 'F'=>'Female'}, dropdownorder=>['',1,2], size=>3, multiple=>1}],
        strYearBirth=> ['Year of Birth',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblEOI.strYearBirth'}],
        SignedUp=> ['Code Used ?',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => " IF(intNewMemberID>0, 'YES', '') ", active=>1}],
		},
		Order => [qw(
			intEOIID
			AssocName
			ClubName
			strFirstname
			strSurname
			dtDOB
			strPostalCode
			strPhone
			strEmail
			intOptIn
			dtCreated
			SignedUp
		)],
    OptionGroups => {
      default => ['Details',{}],
    },

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'rpform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
		},
	);

if($SystemConfig->{'AllowPendingRegistration'}) {
	$config{'Fields'}{'intEOIID'} = ['Type of Registration',{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield=>' IF(intEOIStatus=2, "Transfer Req", "New Registration")'}];
} else {

	$config{'Fields'}{'intEOIID'} = ['New Individual Code',{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield=>' IF(intEOIStatus=2, "Transfer Req", intEOIID)'}];
}
use Data::Dumper;
print STDERR Dumper($config{'fields'});
	$self->{'Config'} = \%config;
}

sub SQLBuilder  {
  my($self, $OptVals, $ActiveFields) =@_ ;
  my $currentLevel = $self->{'EntityTypeID'} || 0;
  my $Data = $self->{'Data'};
  my $clientValues = $Data->{'clientValues'};
  my $SystemConfig = $Data->{'SystemConfig'};

  my $from_levels = $OptVals->{'FROM_LEVELS'};
  my $from_list = $OptVals->{'FROM_LIST'};
  my $where_levels = $OptVals->{'WHERE_LEVELS'};
  my $where_list = $OptVals->{'WHERE_LIST'};
  my $current_from = $OptVals->{'CURRENT_FROM'};
  my $current_where = $OptVals->{'CURRENT_WHERE'};
  my $select_levels = $OptVals->{'SELECT_LEVELS'};

  my $sql = '';
  { #Work out SQL

		my $assocID=getAssocID($Data->{'clientValues'});

    my $currentLevel =  $Data->{'clientValues'}{currentLevel};

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);
    my $from = qq[ $from_levels $current_from $from_list ];
    my $where = qq[ $where_levels $current_where $where_list ];

    my $EOIjoin = ($from =~ /^\s*INNER/) ? '' : ' INNER JOIN ';
    my $EOIand = ($where =~ /^\s*AND/) ? '' : ' AND ';

    $sql = qq[
		SELECT ###SELECT###
		FROM tblEOI $EOIjoin $from
		WHERE  
			tblEOI.intAssocID = tblAssoc.intAssocID 
			AND tblEOI.intClubID = tblClub.intClubID 
			$EOIand 
			$where
		];
    return ($sql,'');
  }
}

1;
