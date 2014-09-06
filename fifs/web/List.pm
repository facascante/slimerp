#
# $Header: svn://svn/SWM/trunk/web/List.pm 10771 2014-02-21 00:20:57Z cgao $
#

package List;

## LAST EDITED -> 10/09/2007 ##

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(listProdTransactions listMemberSeasons list_row list_headers);
@EXPORT_OK = qw(list_row list_headers listProdTransactions listMemberSeasons );

use strict;
use CGI;

use lib '.', "..";
use Defs;
use Reg_common;
use FormHelpers;

require Seasons;

sub listMemberSeasons   {
	my ($Data, $memberID)=@_;
	my $assocID=$Data->{'clientValues'}{'assocID'} || 0; #Current Association
	my $client=setClient($Data->{'clientValues'});
	my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
	my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
	return '' if ! $assocSeasons->{'allowSeasons'};

	my $txt_Name= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
	my $txt_Names= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
	my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
	my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

    ### set up all the text labels for translation ###
    my $lang = $Data->{'lang'};
    my %textLabels = ( #in lexicon
        'addSeasonClubRecord' => $lang->txt("Add $txt_Name $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Record"),
        'addSeasonRecord' => $lang->txt("Add $txt_Name Record"),
        'ageGroup' => $lang->txt($txt_AgeGroupName),
        'ageGroups' => $lang->txt($txt_AgeGroupNames),
        'assocName' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Name"),
        'assocSeasonMemberPackage' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} $txt_Name Member Package"), 
        'clubName' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name"),
        'clubSeasonMemberPackage' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} $txt_Name Member Package"), 
        'coach' => $lang->txt('Coach?'),
        'coachInAssoc' => $lang->txt("Coach in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'coachInClub' => $lang->txt("Coach in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'misc' => $lang->txt('Misc?'),
        'miscInAssoc' => $lang->txt("Misc in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'miscInClub' => $lang->txt("Misc in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'volunteer' => $lang->txt('Volunteer?'),
        'volunteerInAssoc' => $lang->txt("Volunteer in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'volunteerInClub' => $lang->txt("Volunteer in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'matchOfficial' => $lang->txt('Match Official?'),
        'matchOfficialInAssoc' => $lang->txt("Match Official in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'matchOfficialInClub' => $lang->txt("Match Official in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"), 
        'player' => $lang->txt('Player?'),
        'playerAgeGroup' => $lang->txt("Player $txt_AgeGroupName"), 
        'playerInAssoc' => $lang->txt("Player in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'playerInClub' => $lang->txt("Player in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'season' => $lang->txt($txt_Name),
        'seasonMemberPackage' => $lang->txt("$txt_Name Member Package"),
        'seasons' => $lang->txt($txt_Names),
    );

    if ($Data->{'SystemConfig'}{'Seasons_Other1'}) {
        $textLabels{'seasonsOther1'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other1'}?");
        $textLabels{'seasonsOther1InAssoc'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other1'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?");
        $textLabels{'seasonsOther1InClub'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other1'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?");
    };

    if ($Data->{'SystemConfig'}{'Seasons_Other2'}) {
	    $textLabels{'seasonsOther2'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other2'}?");
	    $textLabels{'seasonsOther2InAssoc'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other2'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?");
	    $textLabels{'seasonsOther2InClub'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other2'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?");
    };
    
	my $st=qq[
		SELECT MS.*, S.strSeasonName, IF(C.intRecStatus=-1, CONCAT(C.strName, " (Deleted)"), C.strName) as ClubName, G.strAgeGroupDesc, MP.strPackageName, A.strName as AssocName, S.intAssocID as SeasonAssocID, C.intRecStatus
		FROM $MStablename as MS
			INNER JOIN tblSeasons as S ON (S.intSeasonID = MS.intSeasonID)
			INNER JOIN tblAssoc as A ON (A.intAssocID = MS.intAssocID)
			LEFT JOIN tblClub as C ON (C.intClubID = MS.intClubID)
			LEFT JOIN tblAgeGroups as G ON (G.intAgeGroupID = MS.intPlayerAgeGroupID)
			LEFT JOIN tblMemberPackages as MP ON (MP.intMemberPackagesID = MS.intSeasonMemberPackageID)
		WHERE intMemberID = $memberID
			AND MS.intMSRecStatus = 1
		ORDER BY intSeasonOrder, strSeasonName, AssocName, ClubName
	];
            #The below added to the WHERE might clean up deleted clubs AND C.intRecStatus<>-1 to the left join
            #AND (MS.intClubID = 0 OR MS.intClubID= C.intClubID)
	my $query = $Data->{'db'}->prepare($st);
	$query->execute;

	my $other1Title = $Data->{'SystemConfig'}{'Seasons_Other1'} ? $textLabels{'seasonsOther1InAssoc'} : '';
	my $other2Title = $Data->{'SystemConfig'}{'Seasons_Other2'} ? $textLabels{'seasonsOther2InAssoc'} : '';

	my $ALLother1Title = $Data->{'SystemConfig'}{'Seasons_Other1'} ? $textLabels{'seasonsOther1'} : '';
	my $ALLother2Title = $Data->{'SystemConfig'}{'Seasons_Other2'} ? $textLabels{'seasonsOther2'} : '';

	my $other1ClubTitle = $Data->{'SystemConfig'}{'Seasons_Other1'} ? $textLabels{'seasonsOther1InClub'} : '';
	my $other2ClubTitle = $Data->{'SystemConfig'}{'Seasons_Other2'} ? $textLabels{'seasonsOther2InClub'} : '';

	my $ALLHistoryHeader = list_headers([
        $textLabels{'season'},
        $textLabels{'assocName'},
        $textLabels{'clubName'},
        $textLabels{'seasonMemberPackage'},
        $textLabels{'ageGroup'},
        $textLabels{'player'},
        $textLabels{'coach'},
        $textLabels{'matchOfficial'},
        $textLabels{'misc'},
        $textLabels{'volunteer'},
        $ALLother1Title, 
        $ALLother2Title
    ]) || '';
    
	my $assocHeader = list_headers([
        $textLabels{'season'},
        $textLabels{'assocSeasonMemberPackage'}, 
        $textLabels{'ageGroup'}, 
        $textLabels{'playerInAssoc'},
        $textLabels{'coachInAssoc'},
        $textLabels{'matchOfficialInAssoc'},
        $textLabels{'miscInAssoc'},
        $textLabels{'volunteerInAssoc'},
        $other1Title,$other2Title
    ]) || '';

	my $clubHeader = list_headers([
        $textLabels{'season'},
        $textLabels{'clubName'},
        $textLabels{'clubSeasonMemberPackage'}, 
        $textLabels{'playerAgeGroup'}, 
        $textLabels{'playerInClub'},
        $textLabels{'coachInClub'}, 
        $textLabels{'matchOfficialInClub'},
        $textLabels{'miscInClub'}, 
        $textLabels{'volunteerInClub'}, 
        $other1ClubTitle, $other2ClubTitle
    ]) || '';

	my $assocaddLink = ($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC and !$Data->{'ReadOnlyLogin'})
        ? qq[<a href="$Data->{'target'}?client=$client&amp;a=SN_MSviewADD"><img src="images/add_icon.gif" border="0" alt="$textLabels{'addSeasonRecord'}" title="$textLabels{'addSeasonRecord'}"></a>] 
        : '';

		my $assocBody = qq[
			<table id="ltable" class="listTable" style="width:100%" >
				$assocHeader
		];

	my $clubaddLink = '';
	$clubaddLink = $Data->{'clientValues'}{'authLevel'}>=$Defs::LEVEL_CLUB 
        ? qq[<a href="$Data->{'target'}?client=$client&amp;a=SN_MSviewCADD"><img src="images/add_icon.gif" border="0" alt="$textLabels{'addSeasonClubRecord'}" title="$textLabels{'addSeasonClubRecord'}"></a>] 
        : '';
	$clubaddLink = '' if $Data->{'ReadOnlyLogin'};
  $clubaddLink = '' if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'Club_MemberEditOnly'});

	if(
		$Data->{'SystemConfig'}{'memberReReg_notInactive'}
        and (
        	! $Data->{'MemberActiveInClub'}
            or $Data->{'MemberClrdOut_ofClub'}
        )
        )
	{
		$clubaddLink = '';
  }
        my $clubBody = qq[
                <table id="ltable" class="listTable" style="width:100%">
		$clubHeader
        ];

  $assocaddLink = '' if ($Data->{'SystemConfig'}{'LockSeasons'} or $Data->{'SystemConfig'}{'LockSeasonsCRL'});
  $clubaddLink = '' if ($Data->{'SystemConfig'}{'LockSeasons'} or $Data->{'SystemConfig'}{'LockSeasonsCRL'});

	my $AllBody = qq[
                <table id="ltable" class="listTable" style="width:100%">
		$ALLHistoryHeader
        ];
        my $assocCount=0;
        my $clubCount=0;
        my $count=0;
	my $currentAssoc='';
        while(my $dref=$query->fetchrow_hashref())      {
                $dref->{intPlayerStatus} = $dref->{intPlayerStatus} ? 'Y' : '';
                $dref->{intMSRecStatus} = $dref->{intMSRecStatus} ? 'Y' : '';
                $dref->{intCoachStatus} = $dref->{intCoachStatus} ? 'Y' : '';
                $dref->{intUmpireStatus} = $dref->{intUmpireStatus} ? 'Y' : '';
                $dref->{intMiscStatus} = $dref->{intMiscStatus} ? 'Y' : '';
                $dref->{intVolunteerStatus} = $dref->{intVolunteerStatus} ? 'Y' : '';
                $dref->{intOther1Status} = $dref->{intOther1Status} ? 'Y' : '';
                $dref->{intOther2Status} = $dref->{intOther2Status} ? 'Y' : '';

		my $other1 = $Data->{'SystemConfig'}{'Seasons_Other1'} ? 'intOther1Status' : '';
		my $other2 = $Data->{'SystemConfig'}{'Seasons_Other2'} ? 'intOther2Status' : '';
		if ($dref->{'intAssocID'} == $assocID)	{
	                if ($dref->{'intClubID'})       {
        	                $clubCount++;
				my $fields=[qw(strSeasonName ClubName strPackageName strAgeGroupDesc intPlayerStatus intCoachStatus intUmpireStatus intMiscStatus intVolunteerStatus intOther1Status intOther2Status )];
				$clubBody .=list_row($dref, $fields,["$Data->{'target'}?client=$client&amp;a=SN_MSview&amp;msID=$dref->{intMemberSeasonID}"],($clubCount)%2);
        	        }
        	        else    {
        	                $assocCount++;
				my $fields=[qw(strSeasonName strPackageName strAgeGroupDesc intPlayerStatus intCoachStatus intUmpireStatus intMiscStatus intVolunteerStatus intOther1Status intOther2Status )];
				$assocBody.=list_row($dref, $fields,["$Data->{'target'}?client=$client&amp;a=SN_MSview&amp;msID=$dref->{intMemberSeasonID}"],($assocCount)%2);
        	        }
		}
		next if ($Data->{'SystemConfig'}{'Seasons_SummaryNationalOnly'} and $dref->{SeasonAssocID});
		next if ($Data->{'SystemConfig'}{'Seasons_DefaultID'} == $dref->{intSeasonID} and $Data->{'SystemConfig'}{'Seasons_SummaryNotDefault'}); 
		$dref->{'AssocName'} = '' if $currentAssoc eq $dref->{'AssocName'};
		$currentAssoc=$dref->{'AssocName'};
		$count++;
		my $fields=[qw(strSeasonName AssocName ClubName strPackageName strAgeGroupDesc intPlayerStatus intCoachStatus intUmpireStatus intMiscStatus intVolunteerStatus intOther1Status intOther2Status )];
		$AllBody .=list_row($dref, $fields,[],($count)%2);
        }
        $assocBody .= qq[</table> $assocaddLink];
        $clubBody .= qq[</table> $clubaddLink];
        $AllBody .= qq[</table>];
        my $body = '';
				my @vals = ();
        push @vals, qq[ <div id="assocseason_dat"> $assocBody </div>] ;
        push @vals, qq[ <div id="clubseason_dat"> $clubBody</div>] ;
        push @vals, qq[ <div id="allseason_dat"> $AllBody</div>] ;

        return (\@vals,  join('',@vals));
}



sub listProdTransactions {
    my($Data, $memberID, $assocID) = @_;
warn("listProdTXNS");
	$memberID ||= 0;
	$assocID ||= 0;
	my $db=$Data->{'db'};
	my $resultHTML = '';
    my $lang = $Data->{'lang'};
    my %textLabels = (
        'addTran' => $lang->txt('Add a Transaction'),
        'amountDue' => $lang->txt('Amount Due'), 
        'amountPaid' => $lang->txt('Amount Paid'),
        'assoc' => $lang->txt('Association'), 
	    'listOfTrans' => $lang->txt('List of Transactions'),
		'name' => $lang->txt('Name'),
        'noTransFound' => $lang->txt('No Transactions can be found in the database.'),
        'qty' => $lang->txt('Qty'),
        'status' => $lang->txt('Status'),
    );

	my $orignodename='';
	my $statement =qq[
		SELECT P.strName, T.*, A.strName as AssocName
		FROM tblProdTransactions as T
			INNER JOIN tblProducts as P ON P.intProductID = T.intProductID
		LEFT JOIN tblAssoc as A ON (A.intAssocID = T.intAssocID)
		WHERE T.intMemberID = ?
	];
	 if ($Data->{'clientValues'}{'assocID'})	{
		$statement .= qq[
				AND (T.intAssocID=$Data->{'clientValues'}{'assocID'} or P.intAssocUnique = 1)
		]
	}

	$statement .= qq[
		ORDER BY T.dtTransaction
	];
  my $query = $db->prepare($statement);
  $query->execute($memberID);
  my $found = 0;
	my $client=setClient($Data->{'clientValues'});
	my $currentname='';
  while (my $dref = $query->fetchrow_hashref) {
		$dref->{status} = $dref->{intStatus} == $Defs::TXN_PAID ? $Defs::ProdTransactionStatus{$Defs::TXN_PAID} : $Defs::ProdTransactionStatus{$Defs::TXN_UNPAID};
		$dref->{delete} = qq[<a href="$Data->{target}?a=M_PRODTXN_DEL&amp;client=$client&amp;tID=$dref->{intTransactionID}">Delete</a>];
		$dref->{delete} = '' if ($dref->{intAssocID} != $Data->{'clientValues'}{'assocID'});
    $dref->{delete} = '' if $Data->{'ReadOnlyLogin'};
		$resultHTML.=list_row($dref, [qw(strName AssocName intQty curAmountDue curAmountPaid status delete)],["$Data->{'target'}?client=$client&amp;a=M_PRODTXN_EDIT&amp;tID=$dref->{intTransactionID}"],($found)%2) if ($dref->{intAssocID} == $Data->{'clientValues'}{'assocID'});
		$resultHTML.=list_row($dref, [qw(strName AssocName intQty curAmountDue curAmountPaid status delete)],[""],($found)%2) if ($dref->{intAssocID} != $Data->{'clientValues'}{'assocID'});
    $found++;
  }
  $query->finish;
  if (!$found) {
    $resultHTML .= textMessage($textLabels{'noTransFound'});
  }
  else  {
		my $headings=list_headers([
            $textLabels{'name'}, 
            $textLabels{'assoc'}, 
            $textLabels{'qty'}, 
            $textLabels{'amountDue'}, 
            $textLabels{'amountPaid'}, 
            $textLabels{'status'},
            "&nbsp;"
        ]) || '';
		$resultHTML = qq[ 
			<table class="listTable">
				$headings
				$resultHTML
			</table>
		];
  }
	my $title=$textLabels{'listOfTrans'};
	my $addlink=qq[<div class="changeoptions"><a href="$Data->{'target'}?client=$client&amp;a=M_PRODTXN_ADD"><img src="images/add_icon.gif" border="0" alt="$textLabels{'addTran'}" title="$textLabels{'addTran'}"></a></div>];
  $addlink = '' if $Data->{'ReadOnlyLogin'};
	$title = $addlink.$title;
  return ($resultHTML,$title);
}

## LIST TAGS ##
## Created by TC - 7/9/2007
## Last Updated by TC - 10/9/2007
##
## Controls the process for updating tags in bulk for an association
## or club. The process is that the user selects the tags they wish to
## change and then uses listMembers() to display a list of members
## and the selected tags. These can be updated by the user.
##
## IN
## $Data - Contains generic data
## $id - Passed in but not used
## $action - Contains the current action to perform
##
## OUT
## $resultHTML - HTML for page that is to be displayed
## $title - Title of page that is to be displayed

sub list_row {
	my($dref,$fields,$links,$shade, $checkbox_fields, $keyfield, $lookup_fields)=@_;
	my $body='';
	return '' if(!$dref or !$fields);
	my $shade_str=$shade ? 'class="rowshade" ' : '';
	for my $i (0 .. $#{$fields}) {
		my $fieldname=$fields->[$i];
		$fieldname=~s/\./_/g;
		$dref->{$fieldname} ='' if !defined $dref->{$fieldname};
		my $val=$dref->{$fieldname};
		$val= $lookup_fields->{$fields->[$i]}{$val} if exists $lookup_fields->{$fields->[$i]};
		$val='' if !defined $val;
		if($val ne '' and $links and $links->[$i])	{ $val=qq[<a href="$links->[$i]">$val</a>];	}
		$val='&nbsp;' if $val eq '00/00/0000';
		$val=list_row_checkbox($fields->[$i],$dref->{$fieldname}, $dref->{$keyfield}, $checkbox_fields) if $checkbox_fields->{$fields->[$i]};
		$body.="<td $shade_str>$val</td>\n";
	}
	return qq[
  	<tr>
		$body
	</tr>
	];
}


sub list_row_checkbox	{
	my($fieldname, $val, $keyfield, $checkbox_fields)=@_;
	my $checked='';
	if ($val =~ /\|/) {
		my ($value,$recstatus) = split /\|/,$val;
		$checked=(defined $recstatus and $recstatus eq $checkbox_fields->{$fieldname}) ? ' CHECKED ' : '';
	}
	else {
		$checked=(defined $val and $val eq $checkbox_fields->{$fieldname}) ? ' CHECKED ' : '';
	}
	return qq[<input type="checkbox" name="cbx_].$keyfield.qq[_$fieldname" value="1" $checked ><input type="hidden" name="cbxold_$keyfield].qq[_$fieldname" value="$val">];
}

sub list_headers	{
	my($fields)=@_;
	my $body='';
	return '' if(!$fields);
	for my $f (@{$fields})	{ $body.="<th>$f</th>\n"; }
	return qq[ <tr> $body </tr> ];
}

1;

