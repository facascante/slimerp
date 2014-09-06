#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Member_Club.pm 8950 2013-07-15 06:24:58Z fkhezri $
#

package RegoForm::RegoForm_Member_Program;

use strict;
use lib ".";
use lib "..","../..","../sportstats";
use base qw(RegoForm::RegoForm_Member);

use ProgramObj;

use Log;
use Data::Dumper;
use DateTime;

sub isAllowed {
    my $self = shift;

    my $program_obj = $self->_get_program_obj();
    
    if (not defined $program_obj){
        return $self->error_message('Could not find Program');
    }
    
    if ( not $program_obj->is_active()){
        return $self->error_message('This form is not available at this time');
    }
    
    #TODO: We can do cool things like... is program full? is program finished? is rego closed?
    
    return $self->SUPER::isAllowed();
    
}

sub setupMember_HTMLForm{
    my $self = shift;

    # Need to carry over some info on programs
    foreach my $field (qw/ program_new program_returning /){
        if ($self->{'RunParams'}->{$field}){
            $self->addCarryField($field, 1);
        }
    }

    return $self->SUPER::setupMember_HTMLForm();
}

sub _get_program_obj {
    my $self = shift;
    
    if (not defined $self->{'programObj'}){
         
        $self->{'programID'} ||= $self->{'cgi'}->param('programID');
        $self->{'programID'} ||= $self->{'RunParams'}{'programID'};
        
        # Got to have a program ID or it is all for nothing dude...
        return undef unless $self->{'programID'};
        
        my $program_obj = ProgramObj->new(
            'ID' => $self->{'programID'},
            'db' => $self->{'db'},
        );
        
        $program_obj->load();

        $self->{'programObj'} = $program_obj;
    }
    
    $self->addCarryField('programID', $self->{'programID'});
    
    return $self->{'programObj'};
}

sub Title{
    my $self = shift;
    
    my $program_obj = $self->_get_program_obj();
    
    if (ref $program_obj){
        return $program_obj->name();
    }
    else{
        return '';
    }
    
}

sub AssocID {
    my $self = shift;
    my $program_obj = $self->_get_program_obj();
    
    if (ref $program_obj){
        return $program_obj->get_assoc_id();
    }
    else{
        return $self->SUPER::AssocID();
    }
}

# Our programs are at Assoc Level
sub EntityTypeID {
    my $self = shift;
    return $Defs::LEVEL_ASSOC;
}

# Our programs are at Assoc Level
sub EntityID { 
    my $self = shift;
    return $self->AssocID();
}

sub validate_initial_info {
    my $self = shift;
    my $program_obj = $self->_get_program_obj();
    
    if (ref $program_obj){ 
        my $dob_dt;
        
        # Work out the date, but don't validate as we are going to do that later anyway
        my ($day, $month, $year) = split /\//, $self->get_dob() || '';
        
        if ( $day && $month && $year ){
            eval{
                $dob_dt = DateTime->new(
                   'year'  => $year,
                   'month' => $month,
                   'day'   => $day,
                );
            };
        }
        
        my ($is_valid, $reasons) = $program_obj->valid_dob($dob_dt);
        
        if (!$is_valid){
            push @{$self->{'RunDetails'}{'Errors'}}, @$reasons;
        }
    }
    
    my ($resultHTML, $ok) = $self->SUPER::validate_initial_info();
    
    if ( $ok != 1){
        # We want to preserve some data that will be lost if validation fails
        foreach my $field (qw/ program_new program_returning /){
            if ($self->{'RunParams'}->{$field}){
                $self->addCarryField($field, 1);
            }
        }
    }

    return ($resultHTML, $ok);
}


sub MeetsFieldRule  {
    my $self = shift;
    my ($fieldname) = @_;

    # Check to see if field are limited by 
    my $field_rules = $self->{'FieldRules'}{$fieldname} || undef;
    
    if ($field_rules) {
        # Program Filter
        my $program_filter = $field_rules->{'intProgramFilter'} || 0;
        if ($program_filter == $RegoFormRuleObj::PROGRAM_NEW) {
            return 0 unless ($self->getCarryFields('program_new'));
        }
        elsif ($program_filter == $RegoFormRuleObj::PROGRAM_RETURNING) {
            return 0 unless ($self->getCarryFields('program_returning'));
        }
    }
   
    return $self->SUPER::MeetsFieldRule();
}


1;
