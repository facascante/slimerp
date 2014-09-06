#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_pipeline.cgi 9724 2013-10-09 23:59:27Z dhanslow $
#

use lib "../..","..",".";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use AdminPageGen;
use AdminCommon;
use FormHelpers;
use GridDisplayAdmin;
use PassportLink;
use Data::Dumper;
main();

sub main	{

# Variables coming in

	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $title = "$Defs::sitename PMS Pipeline";
	my $action = param('a') || '';
	my $eID = param('eID') || 0;
	my $etID = param('etID') || 0;
	my $target='pms_pipeline.cgi';
	my $db=connectDB();
    $body = qq[<div style="margin:0px 40px;width:1200px">]; 
	if($action eq 'details')	{
		$body .= display_details($db, $etID, $eID);
	}
	else	{
		$body .= display_pipeline($target, $db);
	}
    $body .= "</div>";
	disconnectDB($db) if $db;
	print_adminpageGen($body, $title, "");
}


sub display_pipeline	{
	my($target, $db)=@_;
	my $realm = param('realm') || 0;
	my $dtFrom= param('dtFrom') || 0;

	my %activated = ();

	my %emails = ();

	my %terms= ();
	{
		# T & Cs signed
		my $st = qq[
			SELECT DISTINCT
				intEntityTypeID,
				intEntityID,
				dtCreated,
				strPaymentEmail
			FROM tblPaymentApplication
		];
		my $q = $db->prepare($st);
		$q->execute();
		while(my ($type, $id, $dtCreated, $strPaymentEmail) = $q->fetchrow_array())	{
			$terms{$type}{$id} = $dtCreated;
			$emails{$type}{$id} = $strPaymentEmail;
		}
	}

	my %regoforms = ();
	{
		# forms created
		my $st = qq[
			SELECT DISTINCT
				intClubID,
				intAssocID
			FROM tblRegoForm
		];
		my $q = $db->prepare($st);
        $q->execute();
		
        while(my ($club, $assoc) = $q->fetchrow_array())	{
			if($club>0)	{
				$regoforms{$Defs::LEVEL_CLUB}{$club} = 1;	
			}
			else	{
				$regoforms{$Defs::LEVEL_ASSOC}{$assoc} = 1;	
			}
		}
	}

	#my %products = ();
	#{
	#	# products created
	#	my $st = qq[
	#		SELECT DISTINCT
	#			intCreatedLevel,
	#			intCreatedID
	#		FROM tblProducts
	#		WHERE intCreatedLevel IN ( $Defs::LEVEL_ASSOC, $Defs::LEVEL_CLUB)
	#	];
	#	my $q = $db->prepare($st);
	#	$q->execute();
	#	while(my ($level, $id) = $q->fetchrow_array())	{
	#		$products{$level}{$id} = 1;	
	#	}
#
#	}
	my %transactions = ();
	{
		my $dtFromWHERE = $dtFrom ? qq[ AND dtLog > "$dtFrom"] : '';
		# Transactions created
		my $st = qq[
			SELECT DISTINCT
				intClubID,
				intAssocID
			FROM tblRegoForm AS RF
				INNER JOIN tblTransLog AS TL
					ON  (TL.intRegoFormID = RF.intRegoFormID)
			WHERE intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
				$dtFromWHERE
		];
		my $q = $db->prepare($st);
		$q->execute();
		while(my ($clubID, $assocID) = $q->fetchrow_array())	{
			if($clubID>0)	{
				$transactions{$Defs::LEVEL_CLUB}{$clubID} = 1;	
			}
			else	{
				$transactions{$Defs::LEVEL_ASSOC}{$assocID} = 1;	
			}
		}

	}
	my %accountsetup = ();
	{
		# PayPal account setup
		my $st = qq[
			SELECT DISTINCT
				intEntityID,
				intEntityTypeID	
			FROM tblBankAccount
		];

		#		INNER JOIN  tblVerifiedEmail AS VE
		#			ON tblBankAccount.strMPEmail = VE.strEmail
		#	WHERE strMPEmail <> '' 
		#		AND strMPEmail IS NOT NULL
		#		AND VE.dtVerified > '2009-01-01'
		#];
		my $q = $db->prepare($st);
		$q->execute();
		while(my ($id, $level) = $q->fetchrow_array())	{
			$accountsetup{$level}{$id} = 1;	
		}

	}
	my %Entities = ();	
	{
		my %clubs = ();
		my %assocs = ();

		for my $k (keys %{$regoforms{$Defs::LEVEL_CLUB}})	{$clubs{$k} = 1;}
		for my $k (keys %{$transactions{$Defs::LEVEL_CLUB}})	{$clubs{$k} = 1;}
		for my $k (keys %{$activated{$Defs::LEVEL_CLUB}})	{$clubs{$k} = 1;}
		for my $k (keys %{$terms{$Defs::LEVEL_CLUB}})	{$clubs{$k} = 1;}
		for my $k (keys %{$accountsetup{$Defs::LEVEL_CLUB}})	{$clubs{$k} = 1;}

		for my $k (keys %{$regoforms{$Defs::LEVEL_ASSOC}})	{$assocs{$k} = 1;}
		for my $k (keys %{$transactions{$Defs::LEVEL_ASSOC}})	{$assocs{$k} = 1;}
		for my $k (keys %{$activated{$Defs::LEVEL_ASSOC}})	{$assocs{$k} = 1;}
		for my $k (keys %{$terms{$Defs::LEVEL_ASSOC}})	{$assocs{$k} = 1;}
		for my $k (keys %{$accountsetup{$Defs::LEVEL_ASSOC}})	{$assocs{$k} = 1;}

		my $clubIDs = join(',', keys %clubs);
		my $assocIDs = join(',', keys %assocs);

	my $realmWHERE = $realm ? qq[ AND A.intRealmID=$realm] : '';
		my $st = qq[
			SELECT 
				intAssocID,
				strName,
				intAllowPayment,	
				IF(strSubTypeName IS NOT NULL,CONCAT(strRealmName,' - ',strSubTypeName), strRealmName) as strRealmName
			FROM 
				tblAssoc as A
					INNER JOIN tblRealms ON (A.intRealmID=tblRealms.intRealmID)
					LEFT JOIN tblRealmSubTypes ON (A.intAssocTypeID=tblRealmSubTypes.intSubTypeID)
			WHERE A.intAssocID IN ($assocIDs)
				$realmWHERE
		];
		my $q = $db->prepare($st);
		$q->execute();
		while(my ($id, $name, $payment, $realm) = $q->fetchrow_array())	{
			$Entities{$Defs::LEVEL_ASSOC}{$id} = [$name, $realm];	
			$activated{$Defs::LEVEL_ASSOC}{$id} = $payment;	
		}
		$st = qq[
			SELECT 
				C.intClubID,
				CONCAT(C.strName,' (',A.strName,")"),
				intAllowPayment,	
			    IF(strSubTypeName IS NOT NULL,CONCAT(strRealmName,' - ',strSubTypeName), strRealmName) as strRealmName
			FROM 
				tblClub AS C
				INNER JOIN tblAssoc_Clubs AS AC ON C.intClubID=AC.intClubID
				INNER JOIN tblAssoc AS A ON A.intAssocID=AC.intAssocID
				INNER JOIN tblRealms ON A.intRealmID=tblRealms.intRealmID
                LEFT JOIN tblRealmSubTypes ON (A.intAssocTypeID=tblRealmSubTypes.intSubTypeID)
			WHERE C.intClubID IN ($clubIDs)
				$realmWHERE
		];
		$q = $db->prepare($st);
		$q->execute();
		while(my ($id, $name, $payment,$realm) = $q->fetchrow_array())	{
			$Entities{$Defs::LEVEL_CLUB}{$id} = [$name, $realm];	
			$activated{$Defs::LEVEL_CLUB}{$id} = $payment;	
		}
	}

	my $body = '';
	$body .= qq[
		<h1>Payment Pipeline Report</h1>
	];
    my @rowdata =();
    my @rowdata_club =();

	for my $id (keys %{$Entities{$Defs::LEVEL_ASSOC}})	{
				#<td class="bg-].($activated{$Defs::LEVEL_ASSOC}{$id} ? 'Yes' : 'No').qq[" >].($activated{$Defs::LEVEL_ASSOC}{$id} ? 'Yes' : 'No').qq[</td>
        my $assoc_name = $Entities{$Defs::LEVEL_ASSOC}{$id}[0];
        my $realm_name = $Entities{$Defs::LEVEL_ASSOC}{$id}[1];
        my $term =$terms{$Defs::LEVEL_ASSOC}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="color:white;background-color:red;">No</div>';
           $term =($terms{$Defs::LEVEL_ASSOC}{$id} ? qq[<div style="background-color:lime;">
                    <a style="text-decoration: underline;"href="$target?a=details&amp;eID=$id&amp;etID=$Defs::LEVEL_ASSOC" target="details">$terms{$Defs::LEVEL_ASSOC}{$id}</a></div>] : '<div style="background-color:red;color:white;">No</div>');
        my $acc_setup = $accountsetup{$Defs::LEVEL_ASSOC}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $activated = $activated{$Defs::LEVEL_ASSOC}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $regoforms = $regoforms{$Defs::LEVEL_ASSOC}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $transaction = $transactions{$Defs::LEVEL_ASSOC}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $email = $emails{$Defs::LEVEL_ASSOC}{$id} || '';
	my $login_link = passportURL(
                        {},
                        {},
                        '',
                        "$Defs::base_url/authenticate.cgi?i=$id&amp;t=$Defs::LEVEL_ASSOC",
		) ;

        push @rowdata ,{
            id => "<a style='color:blue' href='$login_link' target='_blank'>$id</a>",
            name => $assoc_name,
            realm => $realm_name,
            forms => $regoforms,
            activated => $activated,
            terms => $term,
            acc_setup => $acc_setup,
            transaction => $transaction,
            email =>$email, 
            type=>"ASSOCIATION"
        };
    }

	for my $id (keys %{$Entities{$Defs::LEVEL_CLUB}})	{
	    	
        my $club_name = $Entities{$Defs::LEVEL_CLUB}{$id}[0];
        my $realm_name = $Entities{$Defs::LEVEL_CLUB}{$id}[1];
        my $term = $terms{$Defs::LEVEL_CLUB}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="color:white;background-color:red;">No</div>';
           $term =($terms{$Defs::LEVEL_ASSOC}{$id} ? qq[<div style="background-color:lime">
                    <a href="$target?a=details&amp;eID=$id&amp;etID=$Defs::LEVEL_ASSOC" target="details">$terms{$Defs::LEVEL_ASSOC}{$id}</a></div>] : '<div style="background-color:red;color:white;">No</div>');
        my $activated = $activated{$Defs::LEVEL_CLUB}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $acc_setup = $accountsetup{$Defs::LEVEL_CLUB}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $regoforms = $regoforms{$Defs::LEVEL_CLUB}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $transaction = $transactions{$Defs::LEVEL_CLUB}{$id} ? '<div style="background-color:lime;">Yes</div>' : '<div style="background-color:red;color:white;">No</div>';
        my $email = $emails{$Defs::LEVEL_CLUB}{$id} || '';
	my $login_link = passportURL(
                        {},
                        {},
                        '',
                        "$Defs::base_url/authenticate.cgi?i=$id&amp;t=$Defs::LEVEL_CLUB",
		) ;
        push @rowdata ,{
            id => "<a href='$login_link' target='_blank'>$id</a>",
            name => $club_name,
            realm => $realm_name,
            forms => $regoforms,
            activated => $activated,
            terms => $term,
            acc_setup => $acc_setup,
            transaction => $transaction,
            email =>$email,
            type=>'CLUB',
        };
	}
    my @headers =(
        {
            name  => 'ID',
            field => 'id',        
            width=> 40,
             type=>'HTML',
        },
        {
            name  => 'Type',
            field => 'type',
            width=>50,
        },
        {
            name => "Name",
            field => "name",
        },
        {
            name => "Realm",
            field => "realm",
        },
        {
            name => "Payments On",
            field => "activated",
             type=>'HTML',
        },
        {
            name => "RegoForms",
            field => "forms",
             type=>'HTML',
        },
        {
            name => "Terms",
            field => "terms",
             type=>'HTML',
        },
        {
            name => "Account Setup",
            field => "acc_setup",
            type=>'HTML',
            width=>50
        },
        {   
            name => "Transaction",
            field => "transaction",
            width=>50,
             type=>'HTML',
        },
        {
            name => "Email Address",
            field => "email",
        }
        );
    my $filterfields = [
        {
            field => 'realm',
            elementID => 'id_realm',
            type => 'regex',
        },
        {
            field => 'type',
            elementID => 'id_type',
            type => 'regex',
        },
        {
            field => 'name',
            elementID => 'id_name',
            type => 'regex',
        },
  ];

my $rectype_options = qq[ <div style="font-size:1.2em;margin:20px 30px;" >
        Type: <input type="text" name="type" value="" size="10" id = "id_type">
        Name: <input type="text" name="name" value="" size="10" id = "id_name">
        Realm: <input type="text" name="realm" value="" size="10" id = "id_realm"> 
</div>];
my $Data ={};
my $grid .= showGrid (
        Data =>$Data,
        columns => \@headers,
        rowdata=> \@rowdata,
        gridid=>'grid',
        width => 1400,
        height => 1100,
        simple=>0,
        filters => $filterfields,
        font_size => "1.2em"
    );
    $body .= qq[
        <div class="_grid-filter-wrap">
            $rectype_options
            $grid
        </div>
    ];
	return $body;
}

sub display_details	{
	my(
		$db, 
		$etID,
		$eID,
	) = @_;


	my $st = qq[
		SELECT 
			strOrgName,
			strACN,
			strContact,
			strContactPhone,
			strMailingAddress,
			strSuburb,
			strPostalCode,
			strOrgPhone,
			strOrgFax,
			strOrgEmail,
			strPaymentEmail,
			strAgreedBy
		FROM 
			tblPaymentApplication
		WHERE 
			intEntityTypeID = ?
			AND intEntityID = ?
	];
	my $q = $db->prepare($st);
	$q->execute($etID, $eID);
	my $dref = $q->fetchrow_hashref();
	$q->finish();

	my $body = qq[

		<table>
			<tr>
				<td>Org Name</td>
				<td>$dref->{'strOrgName'}</td>
			</tr>
			<tr>
				<td>ACN</td>
				<td>$dref->{'strACN'}</td>
			</tr>
			<tr>
				<td>ABN</td>
				<td>$dref->{'strABN'}</td>
			</tr>
			<tr>
				<td>Contact</td>
				<td>$dref->{'strContact'}</td>
			</tr>
			<tr>
				<td>Contact Phone</td>
				<td>$dref->{'strContactPhone'}</td>
			</tr>
			<tr>
				<td>Mailing Address</td>
				<td>$dref->{'strMailingAddress'}</td>
			</tr>
			<tr>
				<td>Suburb</td>
				<td>$dref->{'strSuburb'}</td>
			</tr>
			<tr>
				<td>Postal Code</td>
				<td>$dref->{'strPostalCode'}</td>
			</tr>
			<tr>
				<td>Org Phone</td>
				<td>$dref->{'strOrgPhone'}</td>
			</tr>
			<tr>
				<td>Org Fax</td>
				<td>$dref->{'strOrgFax'}</td>
			</tr>
			<tr>
				<td>Email</td>
				<td>$dref->{'strOrgEmail'}</td>
			</tr>
			<tr>
				<td>Payment Email</td>
				<td>$dref->{'strPaymentEmail'}</td>
			</tr>
			<tr>
				<td>Agreed By</td>
				<td>$dref->{'strAgreedBy'}</td>
			</tr>
		</table>


	];
	return $body;
}

