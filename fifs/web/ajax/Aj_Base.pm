package Aj_Base;

use JSON;

sub new {
    my $this   = shift;
    my $class  = ref($this) || $this;
	my %params = @_;
    my $self   = {};
    bless $self, $class;
    return $self;
}

sub getContent {
    my $self = shift;
    my ($Data) = @_;
    my $content = $self->genContent($Data);
    return $content;
}

sub _createJSON {
    my $self = shift;
    my ($content) = @_;
    my $json = encode_json $content;
    return $json;
}

1;
