package Registration;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(
    display_screen
    add_registration
);
@EXPORT_OK = qw(
    display_screen
    add_registration
);

use lib "..","../..";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use PersonRegistration;
use AdminCommon;
use TTTemplate;
use Data::Dumper;
# use HTML::FillInForm;

sub display_screen{
    my(
        $db,
        $action,
        $target,
    ) = @_;
    
    my $form_action = 'A';
	my $msg = '';

	my $firstname = 'Fred';
	my $surname = 'Scuttle';
	my $gender = '1';
	my $DOB = '29 Jan 1955';
	my $entityID = '35';
	my $personLevel = 'AMATEUR';
	my $sport = 'FOOTBALL';
	my $registrationNature = 'NEW'; #'REGISTRATION';
	my $ageLevel = 'SENIOR';
	my $personType = 'PLAYER';
   
    my %btn_gender = (
		'1'=>'Male',	
		'2'=>'Female',	
	);

    my %btn_entityID = (
		'1'=>'FIFA',	
		'14'=>'Region',	
		'35'=>'Alands Clubs',	
	);
	
	my $btn_gender = fncRadioBtns($gender,'gender',\%btn_gender);
	my $btn_entityID = fncRadioBtns($entityID,'entityID',\%btn_entityID);
	my $btn_personLevel = fncRadioBtns($personLevel,'personLevel',\%Defs::personLevel);
	my $btn_sport = fncRadioBtns($sport,'sport',\%Defs::sportType);
	my $btn_registrationNature = fncRadioBtns($registrationNature,'registrationNature',\%Defs::registrationNature);
	my $btn_ageLevel = fncRadioBtns($ageLevel,'ageLevel',\%Defs::ageLevel);
	my $btn_personType = fncRadioBtns($personType,'personType',\%Defs::personType);
		
	# Create the form
	my $body = '';
	$body = qq[
  	<form action="$target" method="post">
  	<input type="hidden" name="action" value="$form_action">
  	<table>
  	$msg
	<tr>
		<td class="formbg fieldlabel">First Name:</td>
		<td class="formbg"><input type="text" name="firstname" value="$firstname" style="width:100px;"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Last Name:</td>
		<td class="formbg"><input type="text" name="surname" value="$surname" style="width:100px;"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Gender:</td>
		<td class="formbg">$btn_gender</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Entity:</td>
		<td class="formbg">$btn_entityID</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Type:</td>
		<td class="formbg">$btn_personType</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Level:</td>
		<td class="formbg">$btn_personLevel</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Sport:</td>
		<td class="formbg">$btn_sport</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Registration/Renewal:</td>
		<td class="formbg">$btn_registrationNature</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Age Level:</td>
		<td class="formbg">$btn_ageLevel</td>
	</tr>
	<tr>
    <td class="formbg" colspan="2" style="text-align:center;">
      <input type="submit" name="submit" value="Register">
    </td>
  </tr>
	</table>
    ];
    
    return '<h1>Add a new Registration</h1><tablecellpadding="5">' . $body . '</table>';
}

sub add_registration {
    my(
        $db,
        $action,
        $target,
    ) = @_;

    my $form_action = 'A';
	my $msg = '';

    my $firstname   	 = param('firstname') || '';
    my $surname     	 = param('surname') || '';
    my $gender      	 = param('gender') || '';
    my $DOB         	 = param('DOB') || '';
    my $entityID   	 	 = param('entityID') || '';
    my $personLevel 	 = param('personLevel') || '';
    my $personType  	 = param('personType') || '';
    my $sport       	 = param('sport') || '';
    my $registrationNature = param('registrationNature') || 0;
    my $ageLevel    	 = param('ageLevel') || '';

  	my $st = '';
	my $q = '';
	
	$st = qq[
   		INSERT INTO tblPerson
		(
        intRealmID,
        intSystemStatus,
		strLocalFirstname,
		strLocalSurname,
		intGender,
		dtDOB
		)
		VALUES
		(1,1,
        ?,
		?,
		?,
		?)
		];
		
  	$q = $db->prepare($st);
  	$q->execute(
  		$firstname,
  		$surname,
  		$gender,
  		$DOB
  		);
  		
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
  	my $personID = $q->{mysql_insertid};

	my %registration_data = (
		personID => $personID,
		entityID => $entityID,
		personLevel => $personLevel,
		personType => $personType,
		registrationNature => $registrationNature,
		sport => $sport,
		dtFrom => '2013-01-01',
		dtTo => '2013-12-31',
		ageLevel => $ageLevel,
	 	);

	#Fudge to setup %Data
	my %Data = (
		db => $db,
		Realm => 1,
		SubRealm => 0,
	 	);	

	my $rc = addRegistration (\%Data,\%registration_data);

	if ($rc == 0) {
		return('<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;Your registration has been received and you will be notified in due course when it has been approved.<br>
			<p>&nbsp;</p><p>&nbsp;</p>
			<p>&nbsp;<a href="/main.cgi?client=MHwwfDB8MXwtMXwxNHwtMXwzNXwxMDczMzU1MXwxfDEwMHw1fDE0MDQ5MDYzMzN8OGQyNWQ3N2ZiY2ZiZTU2YWZjOGUwYzJmNjNhY2Y2N2Q&a=WF_xxx">View Approval Tasks</a>') 
	}
	else {
		return('<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;Your registration has been completed and approved.<br>
			<p>&nbsp;</p><p>&nbsp;</p>
			<p>&nbsp;<a href="/main.cgi?client=MHwwfDB8MXwtMXwxNHwtMXwzNXwxMDczMzU1MXwxfDEwMHw1fDE0MDQ5MDYzMzN8OGQyNWQ3N2ZiY2ZiZTU2YWZjOGUwYzJmNjNhY2Y2N2Q&a=WF_xxx">View Approval Tasks</a>') 
			};
}

sub fncRadioBtns {
   	my ($field_value,$field_name, $button_fin_inst, $separator) = @_;
		
	my $txt = '';
	my $pfx = '';
	my $sfx = '';
	if (!$separator) {
		$separator = '&nbsp;'
	}
	
	#PP How do I get a sorted list?
	my $i = -1;
    foreach my $key (sort { $button_fin_inst->{$a} cmp $button_fin_inst->{$b}} keys %{$button_fin_inst})   {
#    foreach my $key(keys %{$button_fin_inst}) {
       	$i = $i + 1;
        if ($key eq $field_value) { 
            $sfx = ' checked ';
        }
        else {
            $sfx = '';
        }
        $txt = $txt . $pfx . '<input type=radio name="' . $field_name . '" value="' . $key . '"' . $sfx . '>' . $button_fin_inst->{$key};
        $pfx = $separator;
    }
	return $txt;
}




