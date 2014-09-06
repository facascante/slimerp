#! /usr/bin/perl

use strict;
use lib '.', '..', '../..';

use CGI qw(param unescape escape);
use Lang;
use Defs;
use Utils;
use SystemConfig;
use JSON;
use Reg_common;
use MemberRecordType;
use Postcodes;
use EntityUtils;
use DBUtils;
use Log;
use Data::Dumper;
use Singleton;

main();

sub main {
    # GET INFO FROM URL
    my $cgi = new CGI;
    my %params = $cgi->Vars();
    my $client = $params{'client'} || '';
    my %clientValues = getClient($client);

    my %Data   = ();
    my $lang   = Lang->get_handle() || die "Can't get a language handle!";
    $Data{'lang'} = $lang;
    $Data{'cache'}  = new MCache();
    $Data{'clientValues'} = \%clientValues;

    # AUTHENTICATE
#    if ($Defs::DEBUG) {
        $Data{'db'} = get_dbh();
#    } else {
#        my $db = allowedTo( \%Data );
#    }

    ( $Data{'Realm'}, $Data{'RealmSubType'} ) = getRealm( \%Data );
    getDBConfig( \%Data );
    $Data{'SystemConfig'} = getSystemConfig( \%Data );
    $Data{'LocalConfig'}  = getLocalConfig( \%Data );
    my $assocID = getAssocID( \%clientValues ) || '';

    $clientValues{'currentLevel'} = safe_param( 'cl', 'number' )
      if (  safe_param( 'cl', 'number' )
        and safe_param( 'cl', 'number' ) <= $clientValues{'authLevel'} );

    # DO DATABASE THINGS
    my $DataAccess_ref = getDataAccess( \%Data );
    $Data{'DataAccess'} = $DataAccess_ref;

    my $resultHTML  = q{};

    $Data{'clientValues'} = \%clientValues;
    $client = $Data{'client'} = setClient( \%clientValues );
    $Data{'unesc_client'} = unescape($client);

    $resultHTML = get_ajax_data(\%Data, \%params);

    print $cgi->header();
    print $resultHTML;
}


sub get_ajax_data {
    my ($data, $params) = @_; 
    my $dbh = get_dbh();

    return '' if not exists $params->{'key'};

    my $key = $params->{'key'};
    DEBUG "get_ajax_data with key: '$key' params: ", Dumper($params);

    if (lc $key eq 'entity') {
        my $entity_type_id = $params->{'entity_type_id'};
        my $result = get_entity_list($data, $entity_type_id);
        $result = JSON::to_json($result);
        DEBUG "ajax result: $result";
        return $result;

    } elsif (lc $key eq 'state') {
        my $postcode = $params->{'postcode'};
        my $state = get_state_from_postcode($postcode);
        $state = qq/ {"state": "$state"} /;
        DEBUG "ajax result: $state";
        return $state;

    } elsif (lc $key eq 'postcode') {
        my $search_key = $params->{'q'};
        my $limit = $params->{'limit'} || 20;
        my $result = get_wildsearch($search_key, $limit, $data);
        $result = { 
            'count' => scalar @{$result},
            'items' => $result,
        };
        DEBUG "ajax result: ", Dumper($result);
        return JSON::to_json($result);
    } elsif (lc $key eq 'mrt') {
        my $entity_type = $params->{'entity_type_id'};
        my $entity_id = $params->{'entity_id'};
        my $result = get_mrt_select_options($data, {
                entity_type => $entity_type, 
                entity_id   => $entity_id, 
                linkable    => 1,
            });

        $result = hash_to_kv_list($result);
        my $json = JSON::to_json($result);
        return $json;
    }

    return '{}';
}


