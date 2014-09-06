#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/automatic/lockMatches.pl 8250 2013-04-08 08:24:36Z rlee $
#

# Developer's notes: This script relates to PE-66 which was prematurely cancelled.
# The script thus far successfully identifies member entries which qualify to be
# processed. For each member, it disactivates the current accreditation record.
# The next steps were to simply add a new accreditation record (with some details
# required for some of its attributes' population) followed by an email notification
# to a list of people (as defined in nrl_club_coach.pl).

use strict;
use lib "../web","..";
use Defs;
use Utils;
use DBI;
use Mail::Sendmail;

# Configuration(s)
my %email_notification = (
	'To'   => q{g.yeong@foxsportspulse.com.au},
	'From' => 'support@sportingpulse.com',
);

my $db = connectDB();

# Start transaction
$db->begin_work() or die $db->errstr();

# Find qualifying members and process them
my $qualifying_members = find_qualifying_members({
		'db' => $db,
	}
);

foreach my $member ( @{$qualifying_members} )
{
	# disactivate the membership and add a new accreditation entry
	my $processed_member = process_membership_record({
			'db' => $db,
			%{ $member },
			# TODO - more details to pass in here
		}
	);

	$email_notification{'message'} .= $processed_member . qq{\n};
}

if ($@)
{
	$db->rollback();
}
else
{
#	$db->commit() or die $db->errstr();

	# Send email out with a list of the processed members for successful commit
	send_email_notification( %email_notification );
}

sub send_email_notification
{
	#TODO: Define this
}

sub find_qualifying_members
{
	#return a hash of members with id and the summary (being the details).
	my ($arg) = @_;

	my $qualifying_members_sql = q{
			SELECT
				acc.intMemberID AS intMemberID,
				qua.intQualificationID AS intQualificationID
			FROM
				tblAccreditation acc,
				tblQualification qua
			WHERE
				acc.intStatus IN (
					SELECT
						intCodeID
					FROM
						tblDefCodes
					WHERE
						intType = '-504'
						AND strName IN ('Complete', 'In Training')
				)
				AND acc.intQualificationID = qua.intQualificationID
				AND qua.intQualificationID IN (
					SELECT
						intQualificationID
					FROM
						tblQualification
					WHERE
						strName IN
						(
							'Modified Games Coach',
							'Modified Games Coach Reaccreditation',
							'International Games Coach',
							'International Games Coach Reaccreditation',
							'Club Coach',
							'Club Coach Reaccreditation'
						)
				)
				AND
				(
					acc.dtExpiry < CURDATE() 
					OR DATEDIFF( CURDATE(), acc.dtExpiry ) <= 3
				)
				AND
					acc.intRecStatus = 1
	};

	my @qualifying_members = ();
	eval
	{
		my $sth = $arg->{'db'}->prepare( $qualifying_members_sql ) or die "Cannot prepare sql";
		$sth->execute or die "Cannot execute sql";

		while ( my $row = $sth->fetchrow_hashref() )
		{
			push @qualifying_members, $row;
		}
	};

	return \@qualifying_members;
}

#   Set membership status to inactive
#   Create new accreditation for the member
sub process_membership_record
{
	my ($arg) = @_;

	my $update_current_accreditation_record_sql = q{
			UPDATE
				tblAccreditation
			SET
				intRecStatus = 0
			WHERE
				intMemberID = ?
		};

	my $sth = undef;
	eval{
		$sth = $arg->{'db'}->prepare( $update_current_accreditation_record_sql );
		$sth->execute( $arg->{'intMemberID'} ) or die $arg->{'db'}->errstr();

		print q{Updated member record of id, } . $arg->{'intMemberID'} . qq{\n}; 

		# TODO: The following lines are work in progress for entering the new
		# record for the member
#		my %record_details = (); # TODO - define the new entry's details here
#		my $insert_new_accreditation_record_sql = q{}; # TODO - define the sql
#		$sth = $arg->{'db'}->prepare( $insert_new_accreditation_record_sql );
#		$sth->execute( ) or die $arg->{'db'}->errstr(); # TODO - provide bind values here
#
#		print q{New member record inserted for member of id, } . $arg->{'intMemberID'} . qq{\n}; 
	};
	if ($@)
	{
		print q{Error processing member record, }
			. $arg->{'intMemberID'}
			. q{ - }
			. $arg->{'db'}->errstr();
	}

	return 1;
}

exit;
