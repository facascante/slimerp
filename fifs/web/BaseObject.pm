#
# $Header: svn://svn/SWM/trunk/web/comp/BaseObject.pm 10638 2014-02-10 01:01:16Z apurcell $
#

package BaseObject;

use strict;

use Clone qw(clone);

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
	my %params=@_;
    my $self ={};
    ##bless selfhash to class
    bless $self, $class;

	#Set Defaults
	$self->{'db'}=$params{'db'};
	$self->{'ID'}=$params{'ID'};
	$self->{'assocID'}=$params{'assocID'};
	return undef if !$self->{'db'};
	
	# load DB data if provided
    if ($params{'DBData'}){
        $self->{'DBData'} = $params{'DBData'};
    }
    
    return $self;
}

sub Error	{
  my $self = shift;
	return $self->{'error'};
}

sub LogError	{
  my $self = shift;
	my($error)=@_;
	$self->{'error'}.="$error\n";
}

sub ID {
  my $self = shift;
  return $self->{'ID'} || 0;
}

sub getValue  {
  my $self = shift;
  my($field)=@_;
	if(ref $field eq 'ARRAY')	{
		my @a = ();
		for my $i (@{$field})	{
			push @a, $self->{'DBData'}{$i};
		}
		return @a;
	}
  return $self->{'DBData'}{$field};
}

sub getAllValues{
    my $self = shift;
    return $self->{'DBData'};
}

sub clearDB	{
  my $self = shift;
	my($db) = @_;
	$self->{'db'} = undef;
}

sub setDB	{
  my $self = shift;
	my($db) = @_;
	$self->{'db'} = $db;
}

sub name {
  my $self = shift;
	my($db) = @_;
	return $self->{'DBData'}{'strName'} || '';
}

sub canDelete {
    my $self = shift;
    
    if ( !defined $self->{'can_delete'} ){      
        if ( $self->_can_delete_self() && $self->_can_delete_children() ){
            $self->{'can_delete'} = 1;
        }
        else{
            $self->{'can_delete'} = 0;
        }
    }
    
    return $self->{'can_delete'}; 
}

sub delete {
    my $self = shift;
    
    if ( $self->canDelete() ){      
        $self->_delete_self();
        $self->_delete_children();
        return 1; 
    }
    
    return 0; 
}

sub _delete_self {
    my $self = shift;
    
    # Delete Self
} 

sub _delete_children {
    my $self = shift;
    
    # Delete any child objects
}

sub _can_delete_self {
    my $self = shift;
    
    # No restrictions
    return 1;
}

sub _can_delete_children {
    my $self = shift;
    
    # No children
    return 1;
}

sub _get_sql_details{
    
    my $field_details = {
        'fields_to_ignore' => [],
        'table_name' => '',
        'key_field' => '',
    };
    
    return $field_details;
}

sub load {
    my $self = shift;
    
    my $write_details = $self->_get_sql_details();
    
    # we cant use the generic write method if the object we are using doesn't give us these details
    return 0 unless $write_details;

    my $table_name = $write_details->{'table_name'};
    my $key_field  = $write_details->{'key_field'};

    # Can not continue without a table name and key
    return 0 unless ($table_name && $key_field);
    
    my $sql = qq[
        SELECT 
            *
        FROM 
            $table_name
        WHERE 
            $key_field = ?
    ];
    my $stmt = $self->{'db'}->prepare($sql);
    $stmt->execute($self->{'ID'});
    
    if ($DBI::err) {
        $self->LogError($DBI::err);
    }
    else {
        $self->{'DBData'} = $stmt->fetchrow_hashref();   
    }
    
}

# generic write method
sub write {
    my $self = shift;

    my @values=();
    my @fields; 
    
    my $write_details = $self->_get_sql_details();
    
    # we cant use the generic write method if the object we are using doesn't give us these details
    return 0 unless $write_details;

    my $table_name = $write_details->{'table_name'};
    my $key_field  = $write_details->{'key_field'};
    my $fields_to_ignore = $write_details->{'fields_to_ignore'} || [];

    # Can not continue without a table name and key
    return 0 unless ($table_name && $key_field);
    
    my $DB_data = clone($self->{'DBData'});
    
    # delete the key field
    delete $DB_data->{$key_field};
    
    # delete any other fields 
    foreach my $field_to_remove (@{$fields_to_ignore}){
        delete $DB_data->{$field_to_remove};
    }
    
    for my $k (keys %{$DB_data}){
        push @fields, $k;
        push @values, $self->{'DBData'}{$k};
    }
    
    if( $self->ID() ) {
        my $fields = join(', ', map { $_ . ' = ?' } @fields);
        my $update_sql = qq[
            UPDATE 
                $table_name 
            SET 
                $fields
            WHERE 
                $key_field = ?
        ];
        my $update_stmt = $self->{'db'}->prepare($update_sql);
        $update_stmt->execute(
            @values,
            $self->ID(),
        );  
    }
    else {
        my $fields_sql = join(', ', @fields);
        my $values_sql = join(', ', map { '?' } @fields);
        my $insert_sql = qq[
            INSERT INTO $table_name (
                $fields_sql
            )
            VALUES (
                $values_sql
            )
        ];
        my $insert_stmt = $self->{'db'}->prepare($insert_sql);
        $insert_stmt->execute(@values);  
    }

}
1;
