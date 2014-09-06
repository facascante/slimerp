package ServerDefs;
require Exporter;
@ISA = qw(Exporter);
#use DBIx::Profile;

no warnings;

$DevelMode = 1;
## DB ACCESS INFO

#$DB_DSN = "DBI:mysql:prod_regoSWM_endOfJan12";
#$DB_DSN = "DBI:mysql:prod_regoSWM_endOfJan12";
#$DB_DSN = "DBI:mysql:prod_regoSWM_earlyMay12";
#$DB_DSN = "DBI:mysql:prod_regoSWM_endJune12";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20120902";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20120930";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20121014";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20121125";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20130201";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20130224";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20130331";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20130428";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20130526";
$DB_DSN = "DBI:mysql:prod_regoSWM_20130623";
#$DB_DSN = "DBI:mysql:prod_regoSWM_20130803";
$DB_USER = "root";
$DB_PASSWD = '';
$DB_DSN_REPORTING = $DB_DSB;;

$Sphinx_Host = '127.0.0.1';
$Sphinx_Port = 9312;

$OLR_DB = 'onlineresults_newer';
$OLR_DB_V3 = 'onlineresults_v3';
$OLR_DB_V5 = 'onlineresults_v3';
$SWOL_URL = 'http://tc.devel.pnp-local.com.au/tim/regoSWM/trunk/web/results/onlineresults.cgi';
$SWOL_URL_v6 = 'http://tc.devel.pnp-local.com.au/tim/regoSWM/trunk/web/results/onlineresults.cgi';

$version='5.0';
$base_url = 'http://tc.devel.pnp-local.com.au/tim/regoSWM/trunk/web';
$duplicate_url= 'http://tc.devel.pnp-local.com.au/tim/regoSWM/trunk/web';
$sync_logs = 'http://tc.devel.pnp-local.com.au/tim/regoSWM/sync/logs/';
$helpurl='http://support.sportingpulse.com';
$sitename="SportingPulse";
$page_title='SWM';

#Passport Defs
$PassportURL = 'http://dh.devel.pnp-local.com.au/passport/trunk/web/';
$PassportSignature = 'swmkey';
$PassportPublicKey = 'swmpubkey';
$PassportMembershipKey = 'fn0534753405758047578'; #Used for passport talking to SWM

$accounts_email='dhanslow@sportingpulse.com';
$admin_email_name="Admin";
$admin_email='warren@sportingpulse.com';
$donotreply_email_name="Admin";
$donotreply_email='DoNotReply@sportingpulse.com';
#$global_mail_debug='m.cowling@sportingpulse.com';
$global_mail_debug='dhanslow@sportingpulse.com';
$fs_base="/home/tcourt/src/regoSWM/trunk";
$sync_logs_dir = $fs_base.'/synclogs/';
$fs_webbase="$fs_base/web";
$null_email = 'DoNotReply@sportingpulse.com';
$null_email_name = 'SportingPulse';


$sync_logs_dir = $fs_base.'/synclogs/';
$fs_upload_dir="/mnt/reg_uploaded";
$uploaded_url="$base_url/../uploaded";
$formimage_url="$base_url/formsimg";
$fs_formdir="$fs_base/forms";
$fs_customreports_dir="$fs_base/customreports";
$salesimage_url = "$base_url/salesimg";
$fs_salesimage_dir = "$fs_base/salesimg";
$FIXTURE_IMPORT_FILES_PATH = $fs_upload_dir.'/fixture_import/';
$SWOL_teamsheet_template_path = "$fs_base/templates/teamsheets";

$mail_log_file="$fs_base/mail.log";

$cookie_domain="pnp-local.com.au";
