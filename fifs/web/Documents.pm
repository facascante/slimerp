#
# $Header: svn://svn/SWM/trunk/web/Documents.pm 9210 2013-08-13 07:53:00Z dhanslow $
#

package Documents;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_documents);
@EXPORT_OK = qw(handle_documents);

use strict;
use lib "..",".";
use Defs;
use Utils;

use ImageUpload;
use FileUpload;
use CGI qw(:cgi param unescape escape);
use Reg_common;
use AuditLog;
use UploadFiles;
use FormHelpers;

sub handle_documents {
	my($action, $Data, $memberID)=@_;
  my $resultHTML='';
	
  my $assocID= $Data->{'clientValues'}{'assocID'} || -1;
	return ('No Member or Association Specified','','') if !$memberID or !$assocID;
	my $newaction='';
  my $client=setClient($Data->{'clientValues'}) || '';

  my $type = '';

	$action ||= 'DOC_L';

  if ($action eq 'DOC_u') {
		my $retvalue = process_doc_upload( 
			$Data,
			$memberID, 
			$client,
		);
		$resultHTML .= qq[<div class="warningmsg">$retvalue</div>] if $retvalue;
		$type = 'Add Document';
	}
  elsif ($action eq 'DOC_d') {
		my $fileID = param('dID') || 0;	
    $resultHTML .= delete_doc($Data, $fileID);
		$type = 'Delete Document';
  }
	$resultHTML .= list_docs($Data,$memberID,$client);

  if ($type) {
    auditLog($memberID, $Data, $type, 'Document');
  }

	return ($resultHTML,'', $newaction);
}


sub list_docs {
	my($Data, $memberID, $client)=@_;
	my $target=$Data->{'target'} || '';
	my $l = $Data->{'lang'};

	my $docs = getUploadedFiles(
		$Data,
		$Defs::LEVEL_MEMBER,	
		$memberID,
		$Defs::UPLOADFILETYPE_DOC,
		$client,
	);

	my $title = $l->txt('Documents');
	my $body = qq[<div class="pageHeading">$title</div>];
	my $options = '';
	my $count = 0;
	for my $doc (@{$docs})	{
    $count++;
    my $c = $count%2==0 ? 'class="rowshade"' : '';
		my $displayTitle = $doc->{'Title'} || 'Untitled Document';
		my $deleteURL = "$Data->{'target'}?client=$client&amp;a=DOC_d&amp;dID=$doc->{'ID'}";
    $options.=qq[
      <tr $c>
        <td><a href="$doc->{'URL'}" target="_doc">$displayTitle</a></td>
        <td>$doc->{'Size'}Mb</td>
        <td>$doc->{'Ext'}</td>
        <td>$doc->{'DateAdded'}</td>
        <td>(<a href="$deleteURL" onclick="return confirm('Are you sure you want to delete this document?');">Delete</a>)</td>
      </tr>
    ];
	}

	if(!$body)	{
		$body .= $Data->{'lang'}->txt('There are no documents');
	}
	else	{
		$body .= qq[
			<table class="listTable">
				$options
			</table>
		];
	}
	$body .= new_doc_form($Data, $client);
	return $body;
}

sub new_doc_form {
	my(
		$Data, 
		$client
	)=@_;

	my $l = $Data->{'lang'};
	my $target=$Data->{'target'} || '';

	my $numoptions = 6;

	my $options = '';
	for my $i (1 .. $numoptions)	{
    #1 = Available to Everyone
    #2 = Available to only the person adding it
    #3 = Available to all bodies at add level and above to which the entity is lnked

		my $currentLevelName = $Data->{'LevelNames'}{$Data->{'clientValues'}{'authLevel'}} || 'organisation';
		my %permoptions = (
			1 => $Data->{'lang'}->txt('All organisations to which this member is linked'),
			2 => $Data->{'lang'}->txt("Only to this $currentLevelName"),
			3 => $Data->{'lang'}->txt("Organisations ( $currentLevelName and above) to which this member is linked"),
		);
		my $perms = drop_down("docperms_$i",\%permoptions,undef,0,1,0);
		$options .= qq[
			<tr style = "border-bottom:1px solid #777;">
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td class="label">Document Name: </td>
				<td><input type="text" name = "docname_$i" value = "" size="40"></td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td><input type="file" name = "doc_$i"></td>
			</tr>
			<tr>
				<td class="label">Viewable by :</td>
				<td> $perms</td>
			</tr>
		];
	}
	my $title = $l->txt('New Document');
	my $body = qq[
	<div class="sectionheader">$title</div>
		<div id="docselect">
		<p>To add a document click the browse button and find the document you wish to upload from your computer.  When you have selected the file click the "Upload" button.</p>
		</p>
		<form action="$target" method="POST" enctype="multipart/form-data">
			<table>
			$options
			</table>
			<br><br>
			<input type="submit" name="submitb" value="Upload" onclick="document.getElementById('docselect').style.display='none';document.getElementById('pleasewait').style.display='block'"  style="width:160px;">
			<input type="hidden" name="client" value="].unescape($client).qq[">
			<input type="hidden" name="a" value="DOC_u">
			<input type="hidden" name="numdocs" value="$numoptions">
		</form>
		</div>
	];
	return $body;
}


sub process_doc_upload	{
	my(
		$Data, 
		$memberID, 
		$client
	)=@_;

	my @files_to_process = ();

	my $numdocs = param('numdocs') || 0;
	for my $i ( 1 .. $numdocs) {
		my $name = param('docname_'. $i) || '';
		my $filefield = 'doc_' . $i;
		my $permission = param('docperms_'. $i) || '';
		push @files_to_process, [$name, $filefield, $permission];
	}
	my $retvalue = processUploadFile(
		$Data, 
		\@files_to_process,
    $Defs::LEVEL_MEMBER,
    $memberID,
    $Defs::UPLOADFILETYPE_DOC,
	);
	return $retvalue;
}

sub delete_doc {
	my($Data, $fileID)=@_;

	my $response = deleteFile(
		$Data,
    $fileID,
  );

	return '';
}

1;
