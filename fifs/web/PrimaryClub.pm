#
# $Header: 
#

package PrimaryClub;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(checkPrimaryClub);
@EXPORT_OK = qw(checkPrimaryClub);

use strict;

use lib 'comp';

use Utils;
use PersonObj;
use TTTemplate;

sub checkPrimaryClub {
    my ($Data, $newMember, $format) = @_;

    my @subRealms = ($Data->{'RealmSubType'});

    $format ||= 0;

    my $asBinary = $format == 0;
    my $asHTML   = $format >= 1;

    my @matchedMembers = ();

    if ($Data->{'SystemConfig'}{'checkPrimaryClubOtherSubRealms'}) {
        my $osr = $Data->{'SystemConfig'}{'checkPrimaryClubOtherSubRealms'};

        $osr =~ s/ //g; #remove all spaces

        my $delimiter = ($osr =~ /\|/) ? '\|' : ','; #either a pipe or a comma could be used as a delimiter
        my @otherSubRealms = split($delimiter, $osr);

        push @subRealms, @otherSubRealms;
    }

    foreach my $subRealm (@subRealms) {
        my $matchedMembersSubRealm = PersonObj->already_exists($Data, $newMember, $subRealm);
        push @matchedMembers, @$matchedMembersSubRealm;
    }

    if ($asBinary) {
        return (@matchedMembers) ? 1 : 0;
    }

    my $resultHTML = '';

    if (@matchedMembers) {
        $newMember->{'dob2'} = reformatDate($newMember->{'dob'});

        my @matchedMembers2 = ();

        foreach my $matchedMember (@matchedMembers) {
            $matchedMember->{'transferLink'} = getTransferLink($Data, $newMember, $matchedMember);
            push @matchedMembers2, $matchedMember;
        }

        my %templateData = (
            firstname => $newMember->{'firstname'},
            surname   => $newMember->{'surname'},        
            dob       => $newMember->{'dob2'},
            matched   => \@matchedMembers2,
            format    => $format,
        );

        my $templateFile = 'primaryclub/matchedMembers.templ';

        $resultHTML = runTemplate($Data, \%templateData, $templateFile);
    }

    return $resultHTML;
}

sub getTransferLink {
    my ($Data, $newMember, $matchedMember) = @_;

    my %params = (
        a                    => 'CL_createnew',
        client               => $Data->{'client'},
        sourceAssocID        => $matchedMember->{'intAssocID'},
        sourceStateID        => $matchedMember->{'SourceStateID'},
        sourceClubID         => $matchedMember->{'intClubID'},
        memberID             => $matchedMember->{'intMemberID'},
        member_natnum        => $matchedMember->{'strNationalNum'},
        member_surname       => $newMember->{'surname'},
        member_dob           => $newMember->{'dob2'},
        member_loggedsurname => $newMember->{'surname'},
        member_systemsurname => $newMember->{'surname'},
        member_systemdob     => $newMember->{'dob2'},
    );

    my $clearanceLink = HTML_link('Transfer request', 'main.cgi', \%params);

    return $clearanceLink;
}

sub reformatDate {
    my ($date) = @_;

    return '' if !$date;
    return '00-00-0000' if $date eq '0000-00-00';

    my ($yyyy, $mm, $dd) = $date =~m:(\d+)-(\d+)-(\d+):;
    return $date if !$dd or !$mm or !$yyyy;

    if ($yyyy < 10) {
        $yyyy+=2000; 
    } 
    elsif ($yyyy < 100) {
        $yyyy+=1900;
    }

    $date = sprintf '%02d/%02d/%04d', $dd, $mm, $yyyy;

    return $date;
}

1;
