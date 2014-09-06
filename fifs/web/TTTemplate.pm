#
# $Header: svn://svn/SWM/trunk/web/TTTemplate.pm 9127 2013-07-31 05:12:38Z tcourt $
#

package TTTemplate;
require Exporter;
@ISA =	qw(Exporter);
@EXPORT = qw(runTemplate);
@EXPORT_OK = qw(runTemplate);

use strict;
use lib ".",'../';
use Template;
use Defs;

sub runTemplate	{
	my($Data, $InData, $filename, $content) = @_;
	return '' if (!$filename and !$content);
	$InData->{'Data'}=$Data;
	$InData->{'Lang'}=$Data->{'lang'};
	$InData->{'BaseURL'}=$Defs::base_url;
	$InData->{'UploadedURL'}=$Defs::uploaded_url;
  my $config = {
    INCLUDE_PATH => ["$Defs::fs_base/templates"],  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
  };
  if(!$filename and $content) {
    my $stringprovider = TTTemplateStringProvider->new({content => $content});
    $config->{'LOAD_TEMPLATES'} = [ $stringprovider ];
    $filename = 'stringtemplate';
  }
	my $template = Template->new($config);
	my $output = '';
	$template->process($filename, $InData, \$output) or print STDERR $template->error(), "\n";
	return $output;
}

package TTTemplateStringProvider;
use base qw( Template::Provider );

use strict;
use warnings;

sub _init {
    my( $self, $args ) = @_;
    $self->SUPER::_init($args);
    my $content = $args->{'content'} || '';
    $self->{'stringtemplate'} = $content;
    return $self;
}

sub _load {
    my( $self, $name ) = @_;
    my $keyname = 'stringtemplate';
    my $time = time;
    my %data = (
      'time' =>  $time,
      'load' =>  $time,
      'name' =>  $keyname,
      'text' =>  $self->{$keyname} || '',
    );
    my $error = Template::Constants::STATUS_DECLINED if !$self->{$keyname};
    return \%data, $error;
}

1;
