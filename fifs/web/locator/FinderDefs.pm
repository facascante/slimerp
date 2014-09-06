#
# $Header: svn://svn/SWM/trunk/web/locator/FinderDefs.pm 10138 2013-12-03 20:24:41Z tcourt $
#

package FinderDefs;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(getFinderDefs);
@EXPORT_OK = qw(getFinderDefs);

no warnings;

$TARGET_FILE = 'finder.cgi';
$TEMPLATES_FOLDER = 'orgfinder';

$REALM_DEFAULT = 0;
$REALM_AFL = 2;
$REALM_RUGBY_LEAGUE = 3;
$REALM_HOCKEY = 5;
$REALM_TOUCH = 11;
$REALM_MOTORCYCLING = 38;

%Settings = (
  $REALM_DEFAULT => {
    Limit => 40,
    Brand => "SportingPulse",
    Title => 'Club Finder',
    Style => 'style.css',
    Error => 'error.templ',
    NoResults => 'noresults_default.templ',
    SearchResults => 'searchresults_default.templ',
    DefaultHeader => 'default_search_hdr.png',
    DefaultCopyright => '&copy Copyright SportingPulse (ANZ) Pty Ltd 2013. All rights reserved.',
  },
  $REALM_RUGBY_LEAGUE => {
    Brand => "Play Rugby League",
    Title => 'Club Finder',
    Style => 'playrugbyleague.css',
    NoResults => 'noresults_arld.templ',
    DefaultHeader => 'prlsearch_hdr.jpg',
  },
  $REALM_AFL => {
    Brand => "FootyWeb",
    Title => 'Club Finder',
    NoResults => 'noresults_afl.templ',
  }
);

sub getFinderDefs {
  my($realmID) = @_;
  my %FinderDefs = ();
  foreach my $key (%{$Settings{$REALM_DEFAULT}})  {
    $FinderDefs{$key}=$Settings{$realmID}{$key} || $Settings{$REALM_DEFAULT}{$key};
  }
  $FinderDefs{'directory'} = $TEMPLATES_FOLDER;
  $FinderDefs{'target'} = $TARGET_FILE;
  return \%FinderDefs;
}


1;
