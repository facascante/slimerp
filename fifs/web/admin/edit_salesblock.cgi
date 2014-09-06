#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/admin/edit_salesblock.cgi 10069 2013-12-01 22:53:32Z tcourt $
#

use strict;
use warnings;

use CGI qw(param escape unescape);

use lib "../comp","../..","..",".";

use Defs;
use DBI;
use Utils;
use DeQuote;
use HTMLForm;
use AdminPageGen;
use FormHelpers;
use FileUpload;

main();

sub main	{
	my $target='edit_salesblock.cgi';
	my $returnstr='';
	my $action=param('a') || '';
	my $id=param('id') || '';
	my $heid=param('heid') || '';
	my $db=connectDB();

  my %blocktypes = (
		1 => 'NavBar',
		2 => 'Registration Confirmation email',
		3 => 'Payment Receipt email',
  );

	if($action eq "ed")	{
 		$returnstr=edit($db, $id, $target, \%blocktypes);
	}
	elsif($action eq "ADDLINK")	{
 		$returnstr=add_link($db, $target, $id);
 		$returnstr.=list_entities($db, $target, $id);
	}
	elsif($action eq "ADDEXCL")	{
 		$returnstr=add_exclusion($db, $target, $id);
 		$returnstr.=list_exclusions($db, $target, $id);
	}
	elsif($action eq "del")	{
 		$returnstr=del_link($db, $target, $heid);
 		$returnstr.=list_entities($db, $target, $id);
	}
	elsif($action eq "delexcl")	{
 		$returnstr=del_exclusion($db, $target, $heid);
 		$returnstr.=list_exclusions($db, $target, $id);
	}
	elsif($action eq "lex")	{
 		$returnstr.=list_exclusions($db, $target, $id);
	}
	elsif($action eq "le")	{
 		$returnstr=list_entities($db, $target, $id);
	}
	else	{
		$returnstr= list($db, $target, \%blocktypes);
	}
	$returnstr.=qq[<br><br><a href="$target">Return to List</a>];
  print_adminpageGen($returnstr, "", "");
}


sub edit	{
	my($db,$id, $target, $blocktypes)=@_;

  my $option='edit';
  $option='add' if !$id;
  my $field=loadDetails($db, $id) || ();

	my $urlbase = "$Defs::salesimage_url/$id";
	my $imageblock = qq[

		<div><span class="label">Thumbnail Image</span><input type="file" name="thumbimg">
			<img src="$urlbase-t.jpg">
		</div>
		<div><span class="label">Detail Image</span><input type="file" name="detailimg">
			<img src="$urlbase-d.jpg">
		</div>
	];



  my %FieldSalesBlocks=(
    fields=>  {
      intType => {
        label => 'Block Type',
        value => $field->{intType},
        type  => 'lookup',
        options => $blocktypes,
        firstoption => [''," "],
        compulsory => 1,
      },

      intSalesBlockID=> {
        label => 'ID',
        value => $field->{intSalesBlockID},
        type  => 'text',
        size  => '5',
        maxsize => '5',
        readonly => 1,
      },
      strName=> {
        label => 'Name (Internal Only)',
        value => $field->{strName},
        type  => 'text',
        size  => '50',
        maxsize => '150',
        compulsory => 1,
      },
      strTitle => {
        label => 'Title',
        value => $field->{strTitle},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        compulsory => 1,
      },
      strURL => {
        label => 'Click Through URL',
        value => $field->{strURL},
        type  => 'text',
        size  => '80',
        maxsize => '200',
        compulsory => 1,
      },
      intRanking => {
        label => 'Ad Ranking (1 least important - 100 most important)',
        value => $field->{intRanking} || 5,
        type  => 'text',
        size  => '2',
        maxsize => '2',
        compulsory => 1,
      },
		},
    order => [qw(intSalesBlockID intType strName strTitle strURL intRanking)],
    options => {
      labelsuffix => ':',
      hideblank => 1,
      target => $target,
      formname => 'n_form',
      submitlabel => "Update ",
      introtext => 'auto',
      updateSQL => qq[
        UPDATE tblSalesBlock
          SET --VAL--
        WHERE intSalesBlockID=$id
      ],
      addSQL => qq[
        INSERT INTO tblSalesBlock
          ( --FIELDS-- )
          VALUES ( --VAL-- )
      ],
      afteraddFunction => \&postAdd,
			afteraddParams => [$option],
      afterupdateFunction => \&postAdd,
			afterupdateParams => [$option, $id],
			pre_button_bottomtext => $imageblock,
			FormEncoding => 'multipart/form-data',
    },
    carryfields =>  {
      a=> 'ed',
			id => $id,
    },
  );
  my $resultHTML='';
  ($resultHTML, undef )=handleHTMLForm(\%FieldSalesBlocks, undef, $option, '',$db);

	return $resultHTML;
}

sub list {
	my ($db, $target, $blocktypes)=@_;
  my $returnstring=  qq[
        <h2>List</h2>
			<a href="$target?a=ed">Add SalesBlock</a>
				<table>
					<tr>
						<th>ID</th>
						<th>Type</th>
						<th>Name</th>
						<th>&nbsp;</th>
					</tr>
	];
	my $statement="
		SELECT intSalesBlockID, strName, intType
		FROM tblSalesBlock
		ORDER BY strName
	";
	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute or query_error($statement);
	while(my($id, $name, $type)=$query->fetchrow_array())	{
		$returnstring.=  qq[
								<tr>
									<td>$id</td>
									<td>$blocktypes->{$type}</td>
									<td>$name</td>
									<td><a href="$target?id=$id&amp;a=ed">Edit</a> &nbsp; | &nbsp;
									<a href="$target?id=$id&amp;a=le">Relationships</a> &nbsp; | &nbsp;
									<a href="$target?id=$id&amp;a=lex">Exclusions</a>
								</tr>
		];
	}
 	$returnstring.=  qq[
								</table>
			<a href="$target?a=ed">Add SalesBlock</a>
	];
}



sub loadDetails {
  my($db, $id) = @_;
  return {} if !$id;
  my $statement=qq[
    SELECT *
    FROM tblSalesBlock
    WHERE intSalesBlockID=$id
  ];
  my $query = $db->prepare($statement);
  $query->execute;
  my $field=$query->fetchrow_hashref();
  $query->finish;
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}


sub list_entities {
	my ($db, $target, $salesblockID)=@_;
  my $returnstring=  qq[
        <h2>Entity List for SalesBlock #$salesblockID</h2>
				<table>
					<tr>
						<th>Realm</th>
						<th>Country</th>
						<th>State</th>
						<th>Assocs</th>
						<th>Clubs</th>
						<th>Other</th>
					</tr>
	];
	my $statement="
		SELECT *
		FROM tblSalesBlockEntity
		WHERE intSalesBlockID = ?
	";
	my $query = $db->prepare($statement);
	$query->execute(
		$salesblockID,
	);

	# Get RealmOptions	
	my %realmoptions = (
		"0:0" => 'All Realms',
	);	
	my @realmorder = ('0:0');
	{
		my $st = qq[
			SELECT 
				R.intRealmID, 
				R.strRealmName, 
				S.intSubTypeID, 
				S.strSubTypeName 
			FROM tblRealms AS R 
				LEFT JOIN tblRealmSubTypes AS S ON R.intRealmID = S.intRealmID 
			ORDER BY 
				R.strRealmName, 
				S.strSubTypeName
		];
		my $q= $db->prepare($st);
		$q->execute();
		my $lastrealmID = 0;
		while(my $dref = $q->fetchrow_hashref())	{
			my $key ='';
			$dref->{'intSubTypeID'} ||= 0;
			if($lastrealmID != $dref->{'intRealmID'} and $dref->{'intSubTypeID'} != 0)	{
				$key = "$dref->{'intRealmID'}:0";
				$realmoptions{$key} = "$dref->{'strRealmName'} : (ALL) ";
				push @realmorder, $key;
			}
			$lastrealmID = $dref->{'intRealmID'} || 0;

			$dref->{'strSubTypeName'} ||= '(ALL)';
			$key = "$dref->{'intRealmID'}:$dref->{'intSubTypeID'}";
			$realmoptions{$key} = "$dref->{'strRealmName'} : $dref->{'strSubTypeName'}";
			push @realmorder, $key;
		}
	};

	my $realmoption=drop_down('realmID',\%realmoptions,\@realmorder, 0,1,0,'','');

	while(my $dref =$query->fetchrow_hashref())	{
		my $id = $dref->{'intSalesBlockEntityID'} || next;

		$returnstring.=  qq[
								<tr>
									<td>$realmoptions{"$dref->{'intRealmID'}:$dref->{'intSubRealmID'}"}</td>
									<td>$dref->{'strCountry'}</td>
									<td>$dref->{'strState'}</td>
									<td>$dref->{'intAssocs'}</td>
									<td>$dref->{'intClubs'}</td>
									<td>$dref->{'intOther'}</td>
									<td><a href="$target?heid=$id&amp;a=del&amp;id=$salesblockID" onclick="return confirm('Are you sure you want to delete this linkage?');">Delete</a></td>
								</tr>
		];
	}
 	$returnstring.=  qq[
								</table>
<br>
<br>
<br>
<br>
<br>
  <form action="$target" method=post>
		<h2>Add a new linkage</h2>

		<span class="label">Realm:</span> $realmoption <br><br>
		<span class="label">Country:</span> <input type="text" name="country" value="" size="30"><br><br>
		<span class="label">State:</span> <input type="text" name="state" value="" size="30"><br><br>
		<span class="label">Display on Assocs:</span> <input type="checkbox" name="assocs" value="1"><br><br>
		<span class="label">Display on Clubs:</span> <input type="checkbox" name="clubs" value="1"><br><br>
		<span class="label">Display on Other:</span> <input type="checkbox" name="other" value="1"><br><br>

		<input type="submit" value="Add Linkage">
		<input type="hidden" name="id" value="$salesblockID">
		<input type="hidden" name="a" value="ADDLINK">
	
		</form>
	];
	return $returnstring;
}



sub add_link	{
	my ($db, $target, $salesblockID)=@_;
	my $country=param('country') || '';
	my $state=param('state') || '';
	my $assocs =param('assocs') || '';
	my $clubs =param('clubs') || '';
	my $other =param('other') || '';
	my $realm =param('realmID') || '0:0';
	my ($realmID, $subrealmID) =split /:/, $realm;


	return 'Invalid SalesBlock' if !$salesblockID;

	my $st=qq[
		INSERT INTO tblSalesBlockEntity
		(
			intSalesBlockID, 
			intRealmID,
			intSubRealmID,
			intAssocs,
			intClubs,
			intOther,
			strCountry,
			strState
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?
		)
	];
	my $q = $db->prepare($st);
	$q->execute(
		$salesblockID, 
		$realmID,
		$subrealmID,
		$assocs,
		$clubs,
		$other,
		$country,
		$state,
	);
	return '';
}

sub del_link	{
	my ($db, $target, $id)=@_;
	return 'Invalid ID' if !$id;

	my $st=qq[
		DELETE FROM tblSalesBlockEntity
		WHERE intSalesBlockEntityID = $id
	];
	$db->do($st);
	return '';
}

sub postAdd {
  my($id,$params,$action, $ID_IN)=@_;

	$id ||= $ID_IN;
	if($id)	{

		my $fname = "$Defs::fs_salesimage_dir/$id";
		my $thumb_img = new FileUpload(
			fieldname => 'thumbimg',
			filename =>$fname."-t",
			maxsize => 4*1024*1024,
			useextension=>1,
			overwrite =>1,
		);
		my $error = '';
		my $ret=$thumb_img->get_upload();
		if($ret) {$error .= "Cannot create Upload object".$thumb_img->Error();}
		else  { }
		my $detail_img = new FileUpload(
			fieldname => 'detailimg',
			filename =>$fname."-d",
			maxsize => 4*1024*1024,
			useextension=>1,
			overwrite =>1,
		);
		my $ret2=$detail_img->get_upload();
		if($ret2) {$error="Cannot create Upload object".$detail_img->Error();}
		else  { }
	}
  if($action eq 'add')  {
    if($id) {
      return (0,qq[
        <div class="OKmsg"> Sales Block Added Successfully</div><br>
        <a href="edit_salesblock.cgi?a=ed&id=$id">Display Details for SalesBlock</a><br><br>
        <b>or</b><br><br>
        <a href="edit_salesblock.cgi?a=ed">Add another Sales Block</a>

      ]);
    }
	}
	elsif($action eq 'edit')	{
      return (0,qq[
        <div class="OKmsg"> Sales Block Updated Successfully</div><br>
			]);
	}
}

sub list_exclusions {
	my ($db, $target, $salesblockID)=@_;

	my %types = (
		$Defs::LEVEL_CLUB => 'Club',
		$Defs::LEVEL_ASSOC => 'Assoc',
	);
	my $typeoptions=drop_down('typeID',\%types,undef, 0,1,0,'','');

  my $returnstring=  qq[
        <h2>Exclusion List for SalesBlock #$salesblockID</h2>
				<table>
					<tr>
						<th>Type</th>
						<th>ID</th>
					</tr>
	];
	my $statement="
		SELECT *
		FROM tblSalesBlockExclusion
		WHERE intSalesBlockID = ?
	";
	my $query = $db->prepare($statement);
	$query->execute(
		$salesblockID,
	);

	while(my $dref =$query->fetchrow_hashref())	{
		my $id = $dref->{'intSalesBlockExclusionID'} || next;
		my $type = $types{$dref->{'intEntityTypeID'}} || '';

		$returnstring.=  qq[
								<tr>
									<td>$type</td>
									<td>$dref->{'intEntityID'}</td>
									<td><a href="$target?heid=$id&amp;a=delexcl&amp;id=$salesblockID" onclick="return confirm('Are you sure you want to delete this exclusion?');">Delete</a></td>
								</tr>
		];
	}
 	$returnstring.=  qq[
								</table>
<br>
<br>
<br>
<br>
<br>
  <form action="$target" method=post>
		<h2>Add a new exclusion</h2>

		<span class="label">Type:</span> $typeoptions
		<span class="label">Entity ID:</span> <input type="text" name="eID" value="" size="10"><br><br>

		<input type="submit" value="Add Exclusion">
		<input type="hidden" name="id" value="$salesblockID">
		<input type="hidden" name="a" value="ADDEXCL">
	
		</form>
	];
	return $returnstring;
}

sub add_exclusion {
	my ($db, $target, $salesblockID)=@_;
	my $eID=param('eID') || '';
	my $etID=param('typeID') || '';

	return 'Invalid SalesBlock' if !$salesblockID;

	my $st=qq[
		INSERT INTO tblSalesBlockExclusion
		(
			intSalesBlockID, 
			intEntityTypeID,
			intEntityID
		)
		VALUES (
			?,
			?,
			?
		)
	];
	my $q = $db->prepare($st);
	$q->execute(
		$salesblockID, 
		$etID,
		$eID,
	);
	return '';
}

sub del_exclusion {
	my ($db, $target, $id)=@_;
	return 'Invalid ID' if !$id;

	my $st=qq[
		DELETE FROM tblSalesBlockExclusion
		WHERE intSalesBlockExclusionID = $id
	];
	$db->do($st);
	return '';
}

