package DuplicatePrevention;

require Exporter;

@ISA       = qw(Exporter);
@EXPORT    = qw(duplicate_prevention);
@EXPORT_OK = qw(duplicate_prevention);

use strict;
use Utils;
use TTTemplate;

sub duplicate_prevention {
	my ($Data, $new_person, $registering_as, $current_person_id) = @_; 

    return '' if '12' !~ /$Data->{'SystemConfig'}{'DuplicatePrevention'}/;

    #$new_person contains the new person's details to be used for dup checking.

    $registering_as ||= [];
    return '' if !@$registering_as;

    my @new_person_types = ();

    #$registering_as contains the types that the person is registering as or being added as/changed to.
    #Because it can come from different sources, a bit of manipulation is done to each of the types.
    foreach my $person_type (@$registering_as) {
        $person_type =  lc($person_type);
        $person_type =~ s/^yn//;
        $person_type =~ s/^d_int//;
        $person_type =~ s/^matchofficial/umpire/;
        $person_type =  ucfirst($person_type);

        my $config_name   = 'DuplicatePrevention_'.$person_type;
        my $do_prevention = (exists $Data->{'SystemConfig'}{$config_name}) ? $Data->{'SystemConfig'}->{$config_name} : 1;

        push @new_person_types, $person_type if $do_prevention;
    }

    return '' if !@new_person_types;

    # at this point @new_person_types will contain the types to be checked eg (Player Coach Umpire...Volunteer).

    my @sub_realms = ($Data->{'RealmSubType'}); #at a minumum, check the current sub realm.

    if ($Data->{'SystemConfig'}{'DuplicatePrevention_OtherSubRealms'}) {
        my $other_sub_realms = $Data->{'SystemConfig'}{'DuplicatePrevention_OtherSubRealms'};
        $other_sub_realms    =~ s/ //g; #remove all spaces.

        my $delimiter = ($other_sub_realms =~ /\|/) ? '\|' : ','; #either a pipe or a comma could be used as a delimiter.
        push @sub_realms, split($delimiter, $other_sub_realms);
    }

    my $by_person_type   = ($Data->{'SystemConfig'}{'DuplicatePrevention'} == 1) ? 1 : 0; #1 = by person type, 2 (really anything other than 0 or 1) = across all types.
    my $across_all_types = !$by_person_type * 1;

    my @person_types = ($by_person_type)
        ? @new_person_types
        : qw(Player Coach Umpire Official Misc Volunteer);

    my $result_html = '';

    #only DuplicatePrevention_IgnorePending taken into account; AllowPendingRegistration (also on SystemConfig) is deliberately ignored.
    my $matched_persons = get_matched_persons(
        $Data->{'db'}, 
        $new_person, 
        \@person_types, 
        $Data->{'Realm'}, 
        \@sub_realms, $Data->{'SystemConfig'}{'DuplicatePrevention_IgnorePending'},
        $current_person_id
    );

    if (@$matched_persons) {
        my %template_data = (matched=>$matched_persons);  #no need to set format arg. 
        my $template_file = 'primaryclub/matchedMembers.templ'; #makes minimal use of the template.
        $result_html = runTemplate($Data, \%template_data, $template_file);
    }

    return $result_html;
}

#check to see if the player has a person season record for any of the types within the subrealms.
sub get_matched_persons {
    my ($dbh, $new_person, $person_types, $realm_id, $sub_realms, $ignore_pending, $current_person_id) = @_;

    $ignore_pending    ||= 0;
    $current_person_id ||= 0; #should only be set if the person is currently in pending and being approved.

    my $source = "tblPerson as M ";

#    $source .= ' INNER JOIN tblMember  AS M USING (intPersonID)';
#    $source .= ' INNER JOIN tblAssoc   AS A USING (intAssocID)';
#    $source .= ' INNER JOIN tblSeasons AS S USING (intSeasonID)';

    my @fields = (
        'DISTINCT M.strFirstname', 
        'M.strSurname', 
        'M.intGender',
        'M.strEmail', 
        'M.strPhoneMobile',
        'M.dtDOB', 
        'M.strNationalNum',
    );
     
     my %tempHash = ();
 
     foreach my $person_type (@$person_types) {
         $tempHash{"MS.int$person_type".'Status'} = 1;
     }

    #intPlayerPending will be 0 if not pending, 1 if pending, -1 if rejected.
    #if ignorePending, get only rows where it has a value of 0; otherwise all values.
    #intMSRecStatus will be 1 if not pending, 0 if pending.
    #if ignorePending, get only rows where it has a value of 1; otherwise all values.
    my @player_pending = ($ignore_pending) ? (0) : (-1, 0, 1);
    my @ms_rec_status  = ($ignore_pending) ? (1) : (0, 1);

    my @where = (
        -and => [
            {
                'M.intRealmID'        => $realm_id,
                'M.strLocalFirstname'      => $new_person->{'firstname'},
                'M.strLocalSurname'        => $new_person->{'surname'},
                'M.dtDOB'             => $new_person->{'dob'},
                'M.intPersonID'       => {'!=', $current_person_id},
                'M.intStatus'         => {-in => [1, 2]}, #include persons marked as possible dupes.
            },
            -nest => [
                -or => [ %tempHash]
            ]
        ]
    );

    my @order = ('strNationalNum'); #('AssocName', 'SeasonName');

    my ($sql, @bind_values) = getSelectSQL($source, \@fields, \@where, \@order);

    my $q = $dbh->prepare($sql);

    $q->execute(@bind_values);

    my $matched_persons = $q->fetchall_arrayref();

    return $matched_persons;
}

1;
