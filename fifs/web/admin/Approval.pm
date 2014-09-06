package Approval;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(
    list_tasks
);
@EXPORT_OK = qw(
    list_tasks
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

sub list_tasks {
    my(
        $db,
        $roleID,
        $WFTaskID,
    ) = @_;
    
   	#Fudge to setup %Data
	my %Data = (
		db => $db,
		RealmID => 1,
		SubRealm => 0,
	 	);
    
    if ($WFTaskID) {
    	my $PersonRegistrationID = approveTask(\%Data, $WFTaskID);
    	my $rc = checkForOutstandingTasks(\%Data, $PersonRegistrationID)
    }
    
    my $st = qq[
		SELECT r.intRoleID, p.strLocalFirstname, p.strLocalSurname, e.strLocalName, r.strTitle
		FROM tblRole r
		INNER JOIN tblEntity e on r.intEntityID = e.intEntityID
		INNER JOIN tblRolePerson pr on r.intRoleID = pr.intRoleID
		INNER JOIN tblPerson p on pr.intPersonID = p.intPersonID
        ORDER BY r.intRoleID
    ];
 
    my $query = $db->prepare($st);
    $query->execute();
    my $body = '';
    
    while(my $dref= $query->fetchrow_hashref()) {
	    $body .= qq[
	      <tr>
	        <td class="listborder">$dref->{intRoleID}</td>
	        <td class="listborder">$dref->{strLocalFirstname} $dref->{strLocalSurname}</td>
	        <td>&nbsp;</td>
	        <td class="listborder"><a href="approval.cgi?RID=$dref->{intRoleID}">$dref->{strLocalName} - $dref->{strTitle}</a></td>
	      </tr>
	    ];
    }
    

    $body = '<h1>Select your current Role</h1>'
    	. '<p><a href="registration.cgi">Registration</a>'
    	. '<table cellpadding="5">'
	    . '<tr style="margin: 10px;"><th>RoleID</th><th>Name</th><th>&nbsp;</th><th>Entity/Role</th></tr>' 
	    . $body . 
	    '</table>';

    if (!$roleID) {
    	return($body);	
    }    

    $body .= '<h1>Approve any outstanding tasks</h1><table cellpadding="5">'
	    . '<tr style="margin: 10px;"><th>TaskID</th><th>Name</th><th>Status</th><th>TaskType</th><th>PersonLevel</th><th>AgeLevel</th><th>Sport</th><th>Registration<br>Type</th><th>Document</th><th>&nbsp;</th><th>Approve</th><th>Reject</th></tr>';

    $st = qq[
		SELECT t.intWFTaskID, t.strTaskStatus, t.strTaskType, pr.strPersonLevel, pr.strAgeLevel, pr.strSport, pr.intRegistrationNature, dt.strDocumentName,
		p.strLocalFirstname, p.strLocalSurname, p.intPersonID
		FROM tblWFTask t
		INNER JOIN tblPersonRegistration_1 pr ON t.intPersonRegistrationID = pr.intPersonRegistrationID
		INNER JOIN tblPerson p on t.intPersonID = p.intPersonID
		LEFT OUTER JOIN tblDocumentType dt ON t.intDocumentTypeID = dt.intDocumentTypeID
		WHERE t.intWFRoleID = ?
		ORDER BY p.strLocalSurname, p.strLocalFirstname, p.intPersonID, t.strTaskType, dt.strDocumentName
    ];
 
    $query = $db->prepare($st);
    $query->execute($roleID);


    my $link = '';
    
    while(my $dref= $query->fetchrow_hashref()) {
	        if ($dref->{strTaskStatus} eq 'ACTIVE') {
        		$link = qq[<td class="listborder"><a href="approval.cgi?RID=$roleID&TID=$dref->{intWFTaskID}">Approve</a></td><td class="listborder">Reject</td>]
	        }
	        else {
        		$link = qq[<td class="listborder">&nbsp;</td><td class="listborder">&nbsp;</td>]
	        }
     	
	    $body .= qq[
	      <tr>
	        <td class="listborder">$dref->{intWFTaskID}</td>
	        <td class="listborder">$dref->{strLocalFirstname} $dref->{strLocalSurname}</td>
	        <td class="listborder">$dref->{strTaskStatus}</td>
	        <td class="listborder">$dref->{strTaskType}</td>
	        <td class="listborder">$dref->{strPersonLevel}</td>
	        <td class="listborder">$dref->{strAgeLevel}</td>
	        <td class="listborder">$dref->{istrSport}</td>
	        <td class="listborder">$dref->{intRegistrationNature}</td>
	        <td class="listborder">$dref->{strDocumentName}</td>
	        <td>&nbsp;</td>
	   		$link
	      </tr>
	    ];
    }
    
    return $body . '</table>';

    
}






