package Lang;

@EXPORT= (qw/get_handle/);
use lib "..",".";
use LangBase;
use Defs;

sub new {

  my $this   = shift;
  my $class  = ref($this) || $this;
  my %params = @_;
  my $self   = {
    'handle' => $params{'handle'}
  };
  ##bless selfhash to class
  bless $self, $class;
  return $self;
}

sub get_handle    {
    my $class = shift;
    my($locale, $SystemConfig) = @_;
    $locale = generateLocale($SystemConfig) if !$locale;
    my $handle = LangBase->get_handle($locale);
    if($handle) {
        $handle->bindtextdomain("messages", $Defs::fs_base."/translations");
        $handle->textdomain("messages");
        $handle->encoding("UTF-8");
        my $o = new Lang(handle => $handle);
        return $o;
    }
    return undef;
}

our $AUTOLOAD;
sub AUTOLOAD {
  my $self = shift;
  my $called =  $AUTOLOAD =~ s/.*:://r;
  return $self->{'handle'}->$called(@_);
}


sub generateLocale  {
    my (
        $SystemConfig,
    ) = @_;

    my $defaultLocale = $SystemConfig->{'DefaultLocale'} || '';
    my $cgi = new CGI;
    my $cookie_locale = $cgi->cookie($Defs::COOKIE_LANG) || '';
    
    return 
        $cookie_locale 
        || $defaultLocale
        || 'en_US';
}

1;
