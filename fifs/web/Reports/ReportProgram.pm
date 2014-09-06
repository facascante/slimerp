#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportData_Ladder.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportProgram;

use lib ".", "..", "../comp", "../..";
use base qw(Reports::ReportStandard);
use Exporter qw(import);
@EXPORT = qw(merch_report);
@EXPORT_OK = qw(merch_report);

use strict;

use DefCodes;
use CustomFields;
require ProgramTemplateObj;
require ProgramObj;
require ProgramTemplateUtils;
require ProgramUtils;

use Log;
use Data::Dumper;

sub merch_report {
    my $class = shift;
    my ($Data, $params) = @_;
    my %template_data;
    
    return {} unless ($params->{'opt_PROGRAM_TEMPLATE'});
    
    # get program template
    my $program_template_obj = ProgramTemplateObj->new( 
        'db' => $Data->{'db'},
        'ID' => $params->{'opt_PROGRAM_TEMPLATE'},
    );
    
    # Check access permissions to that program
    my $permission = $program_template_obj->have_permission({
        'realm_id'    => $Data->{'Realm'}, 
        'subrealm_id' => $Data->{'RealmSubType'},
        'auth_level'  => $Data->{'clientValues'}{'authLevel'},
    });
    
    return {} unless ($permission);
    
    $template_data{'program_template_obj'} = $program_template_obj;
    
    # get programs
    my $get_program_params = {};
    if ( $Data->{'clientValues'}{'assocID'} && ($Data->{'clientValues'}{'assocID'} != $Defs::INVALID_ID) ){
        $get_program_params->{'assoc_id'} = $Data->{'clientValues'}{'assocID'}; 
    }
    my $programs = $program_template_obj->get_programs($get_program_params);

    # store programs by assoc
    foreach my $program_obj (@$programs){
        push @{$template_data{'associations'}{$program_obj->get_assoc_id()}{'programs'}}, $program_obj;
    }
    
    my $assoc_name_sql = 'SELECT strName FROM tblAssoc WHERE intAssocID = ?';
    my $assoc_name_sth = $Data->{'db'}->prepare($assoc_name_sql);
    
    # For each assoc,
    foreach my $assoc_id ( keys %{$template_data{'associations'}}){
        
         # get assoc name
         if (not defined $template_data{'associations'}{$assoc_id}{'name'}){
             $assoc_name_sth->execute($assoc_id);
             my ($assoc_name) = $assoc_name_sth->fetchrow_array();
             $template_data{'associations'}{$assoc_id}{'name'} = $assoc_name;
         }
         
         # sort Assoc programs by location entity type/id
         my $programs_in_assoc= $template_data{'associations'}{$assoc_id}{'programs'};
         my @sorted_programs = sort {$a->getValue('intFacilityID') <=> $b->getValue('intFacilityID')} @$programs_in_assoc;
         $template_data{'associations'}{$assoc_id}{'programs'} = \@sorted_programs;

    }
    
    # Def Codes for custom fields 
    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        assocID    => $Data->{'clientValues'}{'assocID'},
        hideCodes  => $Data->{'SystemConfig'}{'AssocConfig'}{'hideDefCodes'},
    );

    # Defcodes for custom loopup fields
    my $def_code_id = getCustomLookupTypes('intNatCustomLU1'); 
    $template_data{'intNatCustomLU1_map'} = $DefCodes->{$def_code_id};
    
    # Fix dates
    foreach my $field ('opt_STARTDATE', 'opt_ENDDATE'){
        my $date = $params->{$field};

        #convert to mysql date format
        if ($date =~ m/(\d{1,2})\/(\d{1,2})\/(\d{4})/){
           $params->{$field} = "$3-$2-$1";
        }
    }

    $template_data{'before'} = $params->{'opt_ENDDATE'};
    $template_data{'after'}  = $params->{'opt_STARTDATE'};
    
    # DONE!
    return \%template_data;
}


sub attendance_report {
    my $class = shift;
    my ($Data, $params) = @_;
    my %template_data;

    my $program_id = $params->{'opt_PROGRAM'};
    my $assoc_id = $Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
    
    return {} if ($assoc_id == $Defs::INVALID_ID);
    
    my %search_params = (
        'assoc_id' => $assoc_id,
    );
        
    if ($program_id){
        $search_params{'program_id'} = $program_id;
    }

    $template_data{'programs'} = ProgramUtils::get_programs($Data->{'db'}, \%search_params);
    
    # Def Codes for Lookups 
    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        assocID    => $assoc_id,
        hideCodes  => $Data->{'SystemConfig'}{'AssocConfig'}{'hideDefCodes'},
    );

    $template_data{'gender_map'} = \%Defs::genderInfo;
    $template_data{'assist_area_map'} = $DefCodes->{-1002}; #TODO: Replace with defcode constant when available
    
    
    # DONE!
    return \%template_data;
}



sub _get_display_options {
    my $self = shift;

    # Get all display options from ReportStandard
    my $options = $self->SUPER::_get_display_options();
    
    # Add the program template option
    $options->{'program'}          = $self->can('_option_program');
    $options->{'program_template'} = $self->can('_option_program_template');
    
    return $options;
}

sub _option_program {
    my ($self, $field) = @_;
    
    my $parameter = $self->{'Config'}{'Parameters'}{$field};

    my $program_list = ProgramUtils::get_programs($self->{'Data'}{'db'}, {
        'assoc_id' => $self->{'Data'}{'clientValues'}{'assocID'} || $Defs::INVALID_ID,
    });
    
    my $result_html = '';
    
    if ($program_list) {
        my @dropdown_rows = ('<option value="0">All Programs</option>');
        
        foreach my $program_obj (@$program_list){
            my $program_name =  $program_obj->name() . ' (' . $program_obj->display_day_of_week('short') . ' '. $program_obj->display_time() . ')';
            push @dropdown_rows, '<option value="' . $program_obj->ID() .'">' . $program_name . '</option>';
        }
        
        my $select_data = join ("\n", @dropdown_rows);
        
        $result_html = qq[
            <select name="opt_$field">
                $select_data
            </select>
        ];
    }
    else {
        $result_html = "There are no available programs at this time";
    }
    

    return $result_html;
}

sub _option_program_template {
    my ($self, $field) = @_;
    
    my $parameter = $self->{'Config'}{'Parameters'}{$field};

    my $program_template_list = ProgramTemplateUtils::get_available_program_templates({
        'dbh'      => $self->{'db'},
        'realm_id' => $self->{'Data'}{'Realm'},
        #TODO: Subrealm
    });
    
    my $result_html = '';
    
    if ($program_template_list){
        my @dropdown_rows;
        
        foreach my $program_template_obj (@$program_template_list){
            push @dropdown_rows, '<option value="' . $program_template_obj->ID() .'">' . $program_template_obj->name() . '</option>';
        }
        
        my $select_data = join ("\n", @dropdown_rows);
        
        $result_html = qq[
                <select name="opt_$field">
                    $select_data
                </select>
        ];
    }
    else{
        $result_html = "There are no available programs at this time";
    }
    

    return $result_html;
}


1;
