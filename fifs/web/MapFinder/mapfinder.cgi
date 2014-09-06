#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/MapFinder/mapfinder.cgi 11183 2014-03-31 21:28:14Z akenez $
#

use strict;
use lib "../dashboard", ".", "..", "../../","../comp","../sportstats","../SMS","../RegoForm";
use CGI qw(:standard escape);
use Utils;
use Defs;
use MapFinderDefs;
use MapFinder;
use SystemConfig;
use Reg_common;
use Lang;
use EOIDisplay;
use TTTemplate;
use TagManagement;

require AssocObj;

main();

sub main	{
  my $realmID     = safe_param('r','number')  || 0;
  my $subrealmID  = param('sr') || 0;
	my $iframe      = safe_param('if','number') || 0;
	my $action      = param('a')  || '';
	my $search_type = safe_param('type','number') || 2;
  my $resultHTML = '';
  my $db = connectDB();
  my $MapFinderDefs = getMapFinderDefs({
      'realmID' => $realmID,
      'subrealmID' => $subrealmID,
      'type' => $search_type,
  });

  my $search_IN = param('search_value') || '';
  my $search_term_type = param('stt') || 'pc';
  my @search_days = param('days');
  my $clubLevelAssoc = param('club_level_only_assoc') || -1;
  $clubLevelAssoc = '' if $clubLevelAssoc =~/[^\d,]/;
  my $assocLevelAssoc = param('assoc_level_only_assoc') || -1;
  $assocLevelAssoc = '' if $assocLevelAssoc =~/[^\d,]/;
  my $assocID = param('aID') || -1;
  my $alternate = safe_param('alternate','number') || 0;
  
  $subrealmID = 0 if ($subrealmID !~ /^([\d.,]+)$/);

  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  my %Data=(
    db => $db,
    Realm => $realmID,
    RealmSubType => $subrealmID,
    target => $MapFinderDefs->{'target'},
		lang => $lang,
  );
  my $SystemConfig = getSystemConfig(\%Data);
  $Data{'SystemConfig'} = $SystemConfig;
  getDBConfig(\%Data);
	my $content = '';
	my $json_file= '';
	
    if ($Data{'SystemConfig'}{'AllowMapFinderAssocPostcodeLookup'}) {
        if (($assocID && $assocID > 0) && !$search_IN) {
            my $assoc_obj = new AssocObj(
                'db'      => $db,
                'ID'      => $assocID, # I know, you need to supply the assocID twice
                'assocID' => $assocID, # That is how they wrote it ages ago!
            );
            $assoc_obj->load();
            
            my $assoc_post_code = $assoc_obj->getValue('strPostalCode');
            $search_IN = $assoc_post_code if $assoc_post_code;
        }
    }
    

    my $template = (!$alternate) ? $MapFinderDefs->{'Page'} : $MapFinderDefs->{'AlternatePage'} || $MapFinderDefs->{'Page'};

	$template = "/$template";
  my $extra_wrapper_class = '';
  if ($action eq 'EOI_DTA') {
    my ($eoicontent, undef) = handleEOI('EOI_DTA', \%Data);
		$content = $eoicontent;
    	$extra_wrapper_class = 'eoi';
 	}
  else {
		if($search_IN)	{
			($content, $json_file) = search_results(
				\%Data, 
				$MapFinderDefs, 
				$db,
				$search_IN,
				$search_type, 
				$clubLevelAssoc,
				$assocLevelAssoc,
                $assocID,
				$search_term_type,
                \@search_days,
                0, #data only
                $alternate
			);
		}
		$json_file ||= '[]';
  } 
	my $TagManagement=qq[<script type="text/javascript">].getTagManager(\%Data).qq[</script>];;
	my $advanced_search_box = getAdvancedSearchBox(\%Data, $MapFinderDefs);
  disconnectDB($db);
	if(!$realmID)	{
		$template = $MapFinderDefs->{'Error'};
  }
	
	my %SearchTypeName = (
		1 => 'Club',
		2 => 'Association/League',
		3 => 'Programs',
	);
	my $search_type_name = $SearchTypeName{$search_type} || '';
	my %selected_days = map {$_ => 1} @search_days;

    my $copyright_Data = $MapFinderDefs->{'DefaultCopyright'};
    my $footer_Data = $MapFinderDefs->{'Footer'};
    my $global_Nav_Data = $MapFinderDefs->{'GlobalNav'};    
    my $header_Data = $MapFinderDefs->{'DefaultHeader'};

    if($iframe)  {
        $copyright_Data = '';
        $footer_Data = '';
        $global_Nav_Data = '';
        $header_Data = 'blank.png';
    }

    if ($action eq 'EOI_DTA') {
        $json_file = '[]';
    }

	$resultHTML = runTemplate(
		\%Data,
		{
			'TagManagement' => $TagManagement,
			'Title' => $MapFinderDefs->{'Brand'},
			'CSS' => $MapFinderDefs->{'ExtraStyle'} || '',
			'Header' => $header_Data,
			'GlobalNav' => $global_Nav_Data,
			'Copyright' => $copyright_Data,
			'Footer' => $footer_Data,
			'content' => $content,
			'realmID' => $realmID,
			'subRealmID' => $subrealmID,
			'assocID' => $assocID,
			'type' => $search_type,
			'SearchOrgType' => $search_type_name,
			'json_file' => $json_file,
			'ExtraWrapperClass' => $extra_wrapper_class || '',
			'AdvancedSearchBox' => $advanced_search_box || '',
			'ShowDays' => $MapFinderDefs->{'ShowDays'},
			'SelectedDays' => \%selected_days,
			'search_value' => $search_IN,
		},
		$MapFinderDefs->{'directory'} . '/' . $template,
	);
  print qq[Content-type: text/html\n\n];
  print $resultHTML;
}
