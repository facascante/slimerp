#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Member_Club.pm 11086 2014-03-21 05:07:59Z apurcell $
#

package RegoForm::RegoForm_Member_Club;

use strict;
use lib ".";
use lib "..","../..","../sportstats","../RegoFormBuilder","../PaymentSplit","../Clearances";
use RegoForm::RegoFormBaseObj;
our @ISA =qw(RegoForm::RegoForm_Member);

use TTTemplate;
use CGI;
use HTML::FillInForm;
use Date::Calc;
use Person;
use ConfigOptions;
use HTMLForm;
use RegoForm_Member;
use RegoForm_Common;
use RegoForm_Products;
use RegoForm_MemberFunctions;
use RegoForm_Auth;
use RegoForm_Notifications;


sub setProcessOrder {
    my $self = shift;
    
    if ($self->{'SystemConfig'} and $self->{'SystemConfig'}{'use_new_process_order'}) {
        $self->{'ProcessOrder'} = [
            ['t',   'display_choose_regotype', 'Choose Type'],
            ['vt',  'validate_choose_regotype','','NoNav'],
            ['cc',  'display_choose_club', '', 'NoNav'],
            ['vcc', 'validate_choose_club'],
            ['i',   'display_initial_info', 'Basic Info'],
            ['vi',  'validate_initial_info'],
            ['d',   'display_form', 'Extra Info'],
            ['vd',  'validate_form'],
            ['p',   'payment', 'Summary'],
        ];
        if( $self->getValue('intAllowMultipleAdult') or $self->getValue('intAllowMultipleChild') ) {
            unshift @{$self->{'ProcessOrder'}}, ['vm', 'validate_choose_multi', '', ''];
            unshift @{$self->{'ProcessOrder'}}, ['m',  'display_choose_multi', '', 'NoNav'];
        }
    }
    else{
        $self->{'ProcessOrder'} = [
            ['t', \&display_choose_regotype, 'Choose Type'],
            ['vt', \&validate_choose_regotype,'','NoNav'],
            ['cc', \&display_choose_club, '', 'NoNav'],
            ['vcc', \&validate_choose_club],
            ['i', \&display_initial_info, 'Basic Info'],
            ['vi', \&validate_initial_info],
            ['d', \&display_form, 'Extra Info'],
            ['vd', \&validate_form],
            ['p', \&payment, 'Summary'],
        ];
        if( $self->getValue('intAllowMultipleAdult') or $self->getValue('intAllowMultipleChild') ) {
            unshift @{$self->{'ProcessOrder'}}, ['vm', \&validate_choose_multi, '', ''];
            unshift @{$self->{'ProcessOrder'}}, ['m', \&display_choose_multi, '', 'NoNav'];
        }
    }   
}

sub display_choose_club {
  my $self = shift;

  my $memberID = $self->{'AuthorisedID'} || 0;
	if(!$memberID)	{
		$self->setCurrentProcessIndex('i');
		return ('',2);
	}
	my $membername = ($self->{'EntityDetails'}{'strFirstname'} || '').' '
    .($self->{'EntityDetails'}{'strSurname'} || '');

	my @existing_club_records = ();
	{

		my $club_selection = $self->ClubID() > 0
			? "AND MC.intClubID = ?"
			: '';

		my $st = qq[
			SELECT     
			DISTINCT MC.intClubID, 
				C.strName
			FROM tblMember_Clubs AS MC
				INNER JOIN tblAssoc_Clubs as AC ON (AC.intClubID = MC.intClubID)
				INNER JOIN tblClub as C ON (C.intClubID = MC.intClubID)
			WHERE 
				AC.intAssocID = ?
				AND MC.intStatus = $Defs::RECSTATUS_ACTIVE
				AND MC.intMemberID = ?
			$club_selection
			ORDER BY   C.strName
		];
		my $query = $self->{'db'}->prepare($st);
		my @params = (
			$self->AssocID(),
			$memberID,
		);
		push @params, $self->ClubID() if $self->ClubID();
		$query->execute(@params);
		while(my $dref = $query->fetchrow_hashref())	{
			my $link = "$self->{'Target'}?";
			my $fields = $self->getCarryFields();
			$fields->{'clubID'} = $dref->{'intClubID'} || next;
			$fields->{'rfp'} = 'vcc';
			for my $k (keys %{$fields})	{
				$link .= "$k=$fields->{$k}&amp;";
			}
			push @existing_club_records, {
				url => $link,
				name => $dref->{'strName'} || next,
			};
		}
	}


  my %PageData = (
   AssocName => $self->{'RunDetails'}{'AssocDetails'}{'strName'} || '',
    ClubName => $self->{'RunDetails'}{'ClubDetails'}{'strName'} || '',
    TopText => $self->getText('strIndivRegoSelect',1) || '',
    HiddenFields => $self->stringifyCarryField(),
    Target => $self->{'Target'},
    AssocID => $self->AssocID(),
    FormID => $self->ID(),
		LevelName_Club => $self->{'Data'}->{'LevelNames'}{$Defs::LEVEL_CLUB},
		MemberName => $membername,

    ShowNewClubButton => $self->{'SystemConfig'}{'regoShowMCNewClubBtn'} || 0,
    ClubList => $self->_getAssocClubList(),
    ClubRecordList => \@existing_club_records,
    Errors => $self->{'RunDetails'}{'Errors'} || [],
	);
	
	my $templatename = 'regoform/member-to-club/choose_club.templ';
  my $pagedata = '';
  if($templatename) {
    $pagedata = runTemplate(
      $self->{'Data'},
      \%PageData,
      $templatename,
    );
  }

  return ($pagedata,0);
}

sub validate_choose_club {
	my $self = shift;
  $self->addCarryField('clubID', $self->{'RunParams'}{'clubID'});

	return ('',1);
}


#--- Stub functions



sub display_choose_regotype { 
	my $self = shift;
	return $self->SUPER::display_choose_regotype();
}
sub validate_choose_regotype {
	my $self = shift;
	return $self->SUPER::validate_choose_regotype();
}
sub display_initial_info {
	my $self = shift;
	return $self->SUPER::display_initial_info();
}
sub validate_initial_info {
	my $self = shift;
	return $self->SUPER::validate_initial_info();
}
sub display_form {
	my $self = shift;
	return $self->SUPER::display_form();
}
sub validate_form {
	my $self = shift;
	return $self->SUPER::validate_form();
}
sub payment {
	my $self = shift;
	return $self->SUPER::payment();
}

sub display_choose_multi {
	my $self = shift;
	return $self->SUPER::display_choose_multi();
}

sub validate_choose_multi {
	my $self = shift;
	return $self->SUPER::validate_choose_multi();
}
1;
