#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/find_duplicate_members.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..','../web', '../web/comp';
use Getopt::Long;
use Defs;
use DBI;
use Text::CSV_XS;
use Utils;


my $realm;
my @sub_realms;
my $assoc;

GetOptions('assoc=i'=>\$assoc, 'realm=i'=>\$realm, 'subrealm=i'=>\@sub_realms);
if (!$realm or !@sub_realms){ 
    &usage('Please provide the realm, sub realms and asssoc id you wish to check.');
}

#my $DB_DSN = "DBI:mysql:prod_regoSWMEndOct2011";
#$DB_DSN = "DBI:mysql:regoSWMendofApril2011";
#my $DB_DSN = "DBI:mysql:prod_regoSWM_endOfJan12";
#my $DB_DSN = "DBI:mysql:prod_regoSWM_1Jan12";
#my $DB_DSN = "DBI:mysql:prod_regoSWMendNov2011";
#my $DB_USER = "root";
#my $DB_PASSWD = '';
#my $dbh =   DBI->connect($DB_DSN, $DB_USER, $DB_PASSWD);

my $dbh = connectDB();
	
my $sub_realms_in = join(',', @sub_realms);

my $assoc_where = '';
if ($assoc) {
    $assoc_where =  qq[ AND tblAssoc.intAssocID = $assoc];
} 

my $member_query = qq[
                      SELECT 
                      DISTINCT strSurname, strFirstname, dtDOB, tblMember.intMemberID
                      FROM tblMember
                      INNER JOIN tblMember_Clubs ON (tblMember_Clubs.intMemberID = tblMember.intMemberID)
                      INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intClubID = tblMember_Clubs.intClubID)
                      INNER JOIN tblAssoc ON (tblAssoc.intAssocID = tblAssoc_Clubs.intAssocID) 
                      WHERE tblAssoc.intRealmID = $realm
                      AND intPlayer = 1
                      AND tblMember_Clubs.intPermit = 0
                      AND tblAssoc.intAssocTypeID IN ($sub_realms_in)
                      AND tblMember.intStatus IN (0,1)
                      $assoc_where
              ];

my $sth = $dbh->prepare($member_query); 
$sth->execute();

my %members = ();
my %duplicate_members;
my %duplicate_member_ids = ();
my %duplicates = ();

print "Checking for duplicate members for realm $realm, sub realm $sub_realms_in, association $assoc.\n";

while (my $href = $sth->fetchrow_hashref()) {
    
    my $surname = $href->{'strSurname'};
    my $firstname = $href->{'strFirstname'};
    my $dob = $href->{'dtDOB'};
    my $member_id = $href->{'intMemberID'};
    my $key = "$surname$firstname$dob"; 
    
    if (exists $members{$key}) { # We've already encountered a person with this name and date of birth.
        if (not exists $duplicate_members{$key} ) {
            push @{$duplicate_members{$key}}, $members{$key};
            my $duplicate_id = $members{$key}->{intMemberID};
            push @{$duplicate_member_ids{$key}}, $duplicate_id;
            $duplicates{$duplicate_id} = 1;
            $duplicates{$member_id} = 1;
        }
    
        if (not exists $duplicates{$href->{intMemberID}}) {
            push @{$duplicate_members{$key}}, $href;
            push @{$duplicate_member_ids{$key}}, $href->{intMemberID};
        }
    }
    else {
        $members{$key} = $href;
    } 

    #print "line 80\n";
    #use Data::Dumper;
    #print Dumper(\%duplicate_members);
    

    if ($assoc) {
        my @ids = ();
        
        if (exists $duplicate_member_ids{$key}) {
            @ids = join(',',@{$duplicate_member_ids{$key}});
        }
        else {
            $ids[0]= $member_id;
        }
        my $other_assoc_duplicates = check_if_duplicate_in_other_assocs($dbh, $realm, \@sub_realms, $assoc, $href, \@ids);
               
        foreach my $record(@{$other_assoc_duplicates}) { # person from another association with a matching name and different member ID.
            if (not exists $duplicate_members{$key}) {
                push @{$duplicate_members{$key}}, $members{$key};
                my $duplicate_id = $members{$key}->{intMemberID};
                push @{$duplicate_member_ids{$key}}, $duplicate_id;
                $duplicates{$duplicate_id} = 1;

            } 
            
            push @{$duplicate_members{$key}}, $record;
            push @{$duplicate_member_ids{$key}}, $record->{intMemberID};
            $duplicates{$record->{intMemberID}} = 1;

        }
    }
    #print "line 108\n";
    #print Dumper(\%duplicate_members);
    #<STDIN>;
    
#}
    #use Data::Dumper;
    #print Dumper \%duplicate_members;
    #<STDIN>
}

$sth->finish();


my $log_file = 'duplicate_members_' . $realm .  '.csv';
my %resolve_duplicate = ();
my $csv = Text::CSV_XS->new ({ binary => 1, eol => $/ });
open my $fh, ">", $log_file or die "$!\n";

my %assoc_duplicates = ();



foreach my $duplicate(keys %duplicate_members) {
    next if $duplicate eq '';
    
    my %member_last_played = ();
    my %member_assoc = ();    
    
    # Find the last game played for this member, and which asosciation and club this was for.
    # TODO set them to active in this club.
    print "Duplicate:$duplicate\n";
    $csv->print($fh, ["Duplicate:$duplicate"]);
    
    
    foreach my $record (@{$duplicate_members{$duplicate}}) {
        
        my $member = get_member_details($dbh, $record->{'intMemberID'});
        my $member_id = $member->{intMemberID};
        
        my $last_played_data  = get_last_played_date($dbh, $member->{intMemberID});
        my $assoc_name = $last_played_data->{'strName'};
        my $assoc_id = $last_played_data->{'intAssocID'};
        my $last_played_date = $last_played_data->{'dtDate1'};
        
        $last_played_date =~ s/-//g;
        $member_last_played{$member_id} = $last_played_date;
        $member_assoc{$member_id} = $assoc_id;
        
        #push @{$assoc_duplicates{$assoc_id}}, $member;
        
        my @member_data = (
                           $assoc_name,
                           $assoc_id,
                           $last_played_date,
                           $member->{'intMemberID'},
                           $member->{'strFirstname'},
                           $member->{'strMiddlename'},
                           $member->{'strSurname'},
                           $member->{'strAddress1'},
                           $member->{'strAddress2'},
                           $member->{'strSuburb'},
                           $member->{'strState'},
                           $member->{'strPostalCode'},
                           $member->{'strCountry'},
                           $member->{'dtDOB'},
                           $member->{'strEmail'},
                           $member->{'intStatus'},
                           $member->{'strNationalNum'},
                           $member->{'strMemberNo'},
                           $member->{'intStatus'}
                       );
        $csv->print ($fh, \@member_data) or $csv->error_diag;
    }
    
    my $record_count = 0;
    
    if (all_records_have_date(\%member_last_played)) {
        foreach my $id (reverse sort { $member_last_played{$a} <=> $member_last_played{$b}} keys %member_last_played) {
            $record_count++;
            if ($record_count > 1) {
                mark_member_as_duplicate($dbh, $id, $member_assoc{$id});
            }
        }
    }
    else {
        foreach my $id (sort {{$a} <=> {$b}} keys %member_last_played) {
            $record_count++;
            if ($record_count > 1) {
                mark_member_as_duplicate($dbh, $id, $member_assoc{$id});
            }
        }
    }
}   
        
close $fh;


my $assoc_log_file = 'duplicate_members_by_association' . $realm . '.txt';
open(ASSOC_LOG,">$assoc_log_file") || die "Couldn't open log file $assoc_log_file:$!\n";

foreach my $association(sort {$a <=> $b} keys %assoc_duplicates) {
    my $count = scalar @{$assoc_duplicates{$association}};
    print ASSOC_LOG "$association: $count\n";
}
close ASSOC_LOG;

sub mark_member_as_duplicate {
    my ($dbh, $member_id, $assoc_id) = @_;
    
    my $existing_status = $dbh->selectrow_array(qq[SELECT intStatus FROM tblMember WHERE intMemberID = $member_id]);
    
    my $update = qq[
                    UPDATE tblMember
                    SET intStatus = 2
                    WHERE intMemberID = ?
                    LIMIT 1;
                ];
    
    my $sth = $dbh->prepare($update);
    #$sth->execute($member_id) or die "$!\n";
    
    my $sub_realms_list = join('-', @sub_realms);
    my $log_file = 'members_set_to_duplicate' . $realm . '.txt';
    open(LOG,">>$log_file") || die "Couldn't open log file $log_file:$!\n";
    print LOG "member id:$member_id|status before update:$existing_status|rollback:UPDATE tblMember SET intStatus = $existing_status WHERE intMemberID = $member_id LIMIT 1;\n";#, $assoc_id\n";
    close LOG;
    
    return;
}


sub all_records_have_date {
    my $records = shift;
    my $result = 1;
    
    foreach my $date (values %{$records}) {
        if ($date eq '00000000' || !$date) {
            $result = 0;
            last;
        }
    }
    
    return $result;
}

sub get_member_details {
    my ($dbh, $member_id, $assoc_id) = @_;
    
    
    my $query = qq[
                   SELECT 
                       tblMember.intMemberID,
                       tblMember.strFirstname,
                       tblMember.strMiddlename,
                       tblMember.strSurname,
                       tblMember.strAddress1,
                       tblMember.strAddress2,
                       tblMember.strSuburb,
                       tblMember.strState,
                       tblMember.strPostalCode,
                       tblMember.strCountry,
                       tblMember.strSalutation,
                       tblMember.dtDOB,
                       tblMember.intGender,
                       tblMember.strMaidenName,
                       tblMember.strPhoneHome,
                       tblMember.strPhoneWork,
                       tblMember.strPhoneMobile,
                       tblMember.strEmail,
                       tblMember.strPlaceofBirth,
                       tblMember.strEmergContName,
                       tblMember.strEmergContRel,
                       tblMember.strEmergContNo,
                       tblMember.strNationalNum,
                       tblMember.strMemberNo,
                       tblMember.intStatus
                   FROM tblMember
                   WHERE tblMember.intMemberID = $member_id
                   ];
    
    my $member = $dbh->selectrow_hashref($query);    
    return $member;
}

sub get_last_played_date {
    my ($dbh, $member_id) = @_;
    
    my $query = qq[SELECT dtDate1, tblAssoc.intAssocID, strName
                   FROM tblMember_Clubs 
                   INNER JOIN tblAssoc_Clubs USING (intClubID) 
                   INNER JOIN tblMember_Types ON 
                   (
                    tblMember_Clubs.intMemberID = tblMember_Types.intMemberID AND 
                    tblAssoc_Clubs.intAssocID = tblMember_Types.intAssocID
                   ) 
                   INNER JOIN tblAssoc ON (tblMember_Types.intAssocID = tblAssoc.intAssocID)
                   WHERE tblMember_Clubs.intMemberID = $member_id
                   AND tblMember_Clubs.intPermit = 0
                   AND tblMember_Types.intRecStatus != $Defs::RECSTATUS_DELETED
                   ORDER BY dtDate1 DESC
                   LIMIT 1
                   ];
    
    my $href= $dbh->selectrow_hashref($query);
    return $href;
}

sub check_if_duplicate_in_other_assocs {
    my ($dbh, $realm, $sub_realms, $assoc_id, $member, $ids) = @_;
    
    my $sub_realms_list = join(',', @{$sub_realms});
    my $member_ids_in = join(',', @{$ids});
    
    my $query = qq[
                   SELECT
                   DISTINCT strSurname, strFirstname, dtDOB, tblMember.intMemberID
                   FROM tblMember_Clubs
                   INNER JOIN tblMember ON (tblMember.intMemberID = tblMember_Clubs.intMemberID)                   
                   INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intClubID = tblMember_Clubs.intClubID)
                   INNER JOIN tblAssoc ON (tblAssoc.intAssocID = tblAssoc_Clubs.intAssocID)
                   WHERE tblAssoc.intAssocID = $assoc_id
                   AND tblAssoc.intRealmID = $realm
                   AND tblAssoc.intAssocTypeID IN ($sub_realms_list)
                   AND tblMember.intPlayer = 1
                   AND tblMember_Clubs.intPermit = 0
                   AND tblMember.intStatus IN (0,1)
                   AND tblMember.strSurname = ?
                   AND tblMember.strFirstname = ?
                   AND tblMember.dtDOB = ?
                   AND tblMember.intMemberID NOT IN ($member_ids_in)
               ];
    
    #print $member_ids_in, "\n";
    

     my $sth = $dbh->prepare($query);
     $sth->bind_param(1, $member->{strSurname});
     $sth->bind_param(2, $member->{strFirstname});
     $sth->bind_param(3, $member->{dtDOB});
    
    my @duplicates = ();
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref()) {
        push @duplicates, $row;
    }

    return \@duplicates;
}

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./find_duplicate_members.pl --realm realm_id --subrealm sub_realm_id1 --subrealm subrealm_id2 --assoc assoc\n\n";
    exit;
}


