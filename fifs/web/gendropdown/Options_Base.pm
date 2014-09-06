package Options_Base;

use JSON;

sub new {
    my $this   = shift;
    my $class  = ref($this) || $this;
	my %params = @_;
    my $self   = {};
    ##bless selfhash to class
    bless $self, $class;
    return $self;
}

sub getOptions {
    my $self = shift;
    my ($Data, $params) = @_;

    my $dbh = $Data->{'db'};
    my $sql = $self->getSQL($params);

    my $query = $dbh->prepare($sql);

    $query = $self->doQuery($params, $query);

    my $optionID = $self->getOptionID();

    my %Options = ();
    my $count   = 0;

    while (my $dref = $query->fetchrow_hashref()) {
        $count++;
        my $optionDesc = $self->getOptionDesc($dref);
        $Options{$count} = {
            id   => $dref->{$optionID},
            desc => $optionDesc,
        };
    }

    return \%Options;
}

sub createSelect {
    my $self = shift;
    my ($Data, $params, $Options) = @_;

    my $selectName   = $self->getSelectName();
    my $selectID     = $self->getSelectID();
    my $selectDesc   = $self->getSelectDesc();
    my $defaultValue = $self->getDefaultValue($Data, $params);

    my $select = qq[<select name="$selectName" id="$selectID"><option value="">--Select a $selectDesc--</option>];

    my $selected = (keys %$Options == 1) ? 'selected' : '';

    foreach my $key (sort keys %$Options) {
        my $optionID   = $Options->{$key}{'id'};
        my $optionDesc = $Options->{$key}{'desc'};
        $selected = 'selected' if !$selected and $optionDesc eq $defaultValue;
        $select .= qq[<option value="$optionID" $selected>$optionDesc</option>];
    }

    $select .= qq[</select>];

    return $select;
}

sub createJSON {
    my $self = shift;
    my ($Options) = @_;

    my $json = encode_json $Options;
    
    return $json;
}

1;
