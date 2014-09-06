#
# $Header: svn://svn/SWM/trunk/web/admin/swolSetup.pm 10373 2014-01-05 22:23:52Z dhanslow $
#

package swolSetup;


## CREATED BY TC | 27/05/2010

## SPORT IDs FROM OLR
#HOCKEY = 1;
#CRICKET = 2;
#FOOTBALL = 3;
#LACROSSE = 4;
#SOCCER = 5;
#NETBALL = 6;
#BBALL = 7;
#RUGBY_LEAGUE = 8;
#RUGBY_LEAGUE = 9;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(setupSWOL confirmData displayMenu);
@EXPORT_OK = qw(setupSWOL confirmData displayMenu);


use lib "../..","..",".",'../web';
use DBI;
use CGI qw(:standard);
use Defs;
use MCache;
use Utils;
use strict;


sub setupSWOL {
  my ($db, $Data) = @_;
  my $body = '';
  my $nosql = 0;
  return qq[<h1>Something is a little broken here</h1>] unless ($Data->{'sport'} and $Data->{'swmid'});
  my $realmID = DataAdmin::dlookup($db,'intRealmID','tblAssoc',"intAssocID = $Data->{'swmid'}") || 0;
  unless ($nosql) {
    ## HOCKEY
    if ($Data->{'sport'} == $Defs::SPORT_HOCKEY) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 3195;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 12645;
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 5',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'None Specified',1);]);
      # tblDefCodes
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Juniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Seniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Veterans',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'1sts',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'2nds',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'3rds',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'4ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'5ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'6ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'7ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'8ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'9ths',$realmID,1);]);
    }
    ## FOOTBALL
    elsif ($Data->{'sport'} == $Defs::SPORT_FOOTBALL) { 
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 12607;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 12645;
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Division 5',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'None Specified',1);]);
      # tblDefCodes
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Juniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Seniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Veterans',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'1sts',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'2nds',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'3rds',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'4ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'5ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'6ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'7ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'8ths',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-21,'9ths',$realmID,1);]);
      $db->do(qq[UPDATE tblAssoc SET intProcessLogNumber=1 WHERE intAssocID=$Data->{'swmid'}]);
    }
    ## LACROSSE
    elsif ($Data->{'sport'} == $Defs::SPORT_LACROSSE) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 18180;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'First',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Second',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Third',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Fourth',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'None Specified',1);]);
      # tblDefCodes
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Juniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Seniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Veterans',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'All Age',$realmID,1);]);
    }
    ## SOCCER
    elsif ($Data->{'sport'} == $Defs::SPORT_SOCCER) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 12607;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 12645;
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'First',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Second',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Third',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'Fourth',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'None Specified',1);]);
      # tblDefCodes
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Juniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Seniors',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'Veterans',$realmID,1);]);
      $db->do(qq[INSERT INTO tblDefCodes (intAssocID,intType,strName,intRealmID, intRecStatus) VALUES ($Data->{'swmid'},-36,'All Age',$realmID,1);]);
    }
    ## NETBALL
    elsif ($Data->{'sport'} == $Defs::SPORT_NETBALL) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : -6;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
    ## BASKETBALL
    elsif ($Data->{'sport'} == $Defs::SPORT_BASKETBALL) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 19283;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
    ## RUGBY LEAGUE
    elsif ($Data->{'sport'} == $Defs::SPORT_LEAGUE) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 89;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
	elsif ($Data->{'sport'} == $Defs::SPORT_UNION) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 89;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }

 elsif ($Data->{'sport'} == $Defs::SPORT_BASEBALL) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : -58;

      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
elsif ($Data->{'sport'} == $Defs::SPORT_VOLLEYBALL) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : -9;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }

    ## GENERIC
    elsif ($Data->{'sport'} == 9) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 0;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
    ## TOUCH
    elsif ($Data->{'sport'} == $Defs::SPORT_TOUCH_FOOTBALL) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : 12873;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
    ## WATER POLO
    elsif ($Data->{'sport'} == $Defs::SPORT_WATER_POLO) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : -11;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }
    ## LAWN BOWLS
    elsif ($Data->{'sport'} == $Defs::SPORT_LAWN_BOWLS) {
      # tblCompSWOLConfig
      my $intAssocID = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : -23;
      insertSWOLCompConfig($db, $intAssocID, $Data->{'swmid'});
      # tblAssocStaff
      insertAssocStaff($db, $intAssocID, $Data->{'swmid'});
      insertAssocOfficials($db, $intAssocID, $Data->{'swmid'});
      # tblResults_PlayerPositions 
      insertPlayerPositions($db, $intAssocID, $Data->{'swmid'});
      insertTeamSheets($db, $intAssocID, $Data->{'swmid'});
      # tblAssoc_Grade
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'1',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'2',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'3',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'4',1);]);
      $db->do(qq[INSERT INTO tblAssoc_Grade (intAssocID,strGradeDesc,intRecStatus) VALUES ($Data->{'swmid'},'N/A',1);]);
    }

    ## ALL SPORT FUNCTIONS
    $db->do(qq[
      UPDATE
        tblAssoc
      SET
        strFirstSyncCode="$Data->{'fsc'}",
        strSWWUsername="$Data->{'swwu'}",
        strSWWPassword = "$Data->{'swwp'}",
        intSWOL = 1,
        intSWOL_SportID = $Data->{'sport'},
        intAllowSeasons = 1,
        intUploadType = 1
      WHERE
        intAssocID = $Data->{'swmid'}
      LIMIT 1;
    ]);
    $db->do(qq[
      UPDATE 
        tblCompAwards as A 
        INNER JOIN tblAssoc_Comp as C ON (C.intCompID = A.intCompID) 
      SET 
        A.strAwardName = C.strTitle
      WHERE 
        A.intAssocID IN ($Data->{'swmid'}) 
        AND A.strAwardName = '';
    ]);
    # tblUmpireLevelConfig
    $db->do(qq[UPDATE tblUmpireLevelConfig SET intSystemType = 1 WHERE intComp_AssocID = $Data->{'swmid'};]);
  }
	$db->do(qq[INSERT INTO tblAssocConfig VALUES (0, $Data->{'swmid'}, 'olrv6', 1, now());]);
  my $settings = ($Data->{'swmidcopy'}) ? $Data->{'swmidcopy'} : "Default";
 
      my $cache=new MCache();
        $cache->delete('swm',"AssocObj-".$Data->{'swmid'}) if $cache;

 $body = qq[
    <p>Setup complete.</p>
    <p>
      Sport: $Data->{'sport'} <br>
      SWMID: $Data->{'swmid'} <br>
      SETTINGS: $settings <br>
      FSC: $Data->{'fsc'} <br>
      SWWU: $Data->{'swwu'} <br>
      SWWP: $Data->{'swwp'} <br>
    </p>
    <p><i>Do not forget to update the <a href="http://www.sportingpulse.com/admin/assoc_admin.cgi">Sportzware Websites Admin</a> settings for Online Results.</i></p>
    <form name="confirm_swol" action="?" method="post">
      <input type="hidden" name="a" value="">
      <input type="hidden" name="action" value="UTILS_SWOL_setup">
      <input type="submit" value="Done">
    </form>
  ];
  return $body;
}

sub insertAssocStaff {
  my ($db, $assocID, $swmID) = @_;
  $db->do(qq[
    INSERT INTO
      tblResults_AssocStaff
    SELECT
      0,
      $swmID,
      strStaffDesc,
      intOrder,
      strGroup,
      0,
      NOW(),
      intRealmID
    FROM
      tblResults_AssocStaff
    WHERE
      intAssocID = $assocID
  ]);
}
sub insertTeamSheets {
  my ($db, $assocID, $swmID) = @_;
  $db->do(qq[
 INSERT INTO tblTeamSheetEntity 
        SELECT		0,
                        intTeamSheetID,
                        intRealmID,
                        intSubRealmID,
                        $swmID,0,0,0
    FROM
      tblTeamSheetEntity
    WHERE
      intAssocID = $assocID;
  ]);
}


sub insertAssocOfficials {
  my ($db, $assocID, $swmID) = @_;
  $db->do(qq[
    INSERT INTO
      tblResults_AssocOfficials
    SELECT
      0,
      $swmID,
      strStaffDesc,
      intOrder,
      strGroup,
      0,
      NOW()
    FROM
      tblResults_AssocOfficials
    WHERE
      intAssocID = $assocID
  ]);
}


sub insertPlayerPositions {
  my ($db, $assocID, $swmID) = @_;
  $db->do(qq[
    INSERT INTO 
      tblResults_PlayerPositions 
        SELECT 
          0, 
          $swmID, 
          intOrderID, 
          strShortDesc, 
          strLongDesc, 
          intLimit, 
          intGroup, 
          strGroupName, 
          0, 
          NOW() 
        FROM 
          tblResults_PlayerPositions 
        WHERE 
          intAssocID = $assocID
    ]);
}

sub insertSWOLCompConfig {
  my ($db, $assocID, $swmID) = @_;
  $db->do(qq[
    INSERT INTO
      tblCompSWOLConfig
    SELECT
      0,
      $swmID,
      0,
      strConfigArea,
      strKey,
      strValue,
      strValue_long,
      NOW()
    FROM
      tblCompSWOLConfig
    WHERE
      intAssocID = $assocID
  ]);
  my $st = qq[
    SELECT
      COUNT(strKey)
    FROM
      onlineresults_v3.tblAssocConfig
      INNER JOIN onlineresults_v3.tblAssoc ON (onlineresults_v3.tblAssoc.intAssocID = onlineresults_v3.tblAssocConfig.intAssocID)
    WHERE
      intRegoAssocID = $swmID 
      AND strConfigArea='TEAM_SHEET';
  ];
  my $query = $db->prepare($st);
  my $v3 = $query->fetchrow_array();
  if ($v3) {
    $db->do(qq[
      DELETE FROM
        tblCompSWOLConfig
      WHERE
        strConfigArea ='TEAM_SHEET'
        AND intAssocID = $swmID;
    ]);
    $db->do(qq[
      INSERT INTO
        tblCompSWOLConfig (
          intAssocID,
          strConfigArea,
          strKey,
          strValue,
          strValue_long
      )
      SELECT
        $swmID,
        'TEAM_SHEET',
        strKey,
        strValue,
        strValue_Long
      FROM
        onlineresults_v3.tblAssocConfig
        INNER JOIN onlineresults_v3.tblAssoc ON (onlineresults_v3.tblAssoc.intAssocID = onlineresults_v3.tblAssocConfig.intAssocID)
      WHERE
        intRegoAssocID = $swmID 
        AND strConfigArea='TEAM_SHEET';
    ]);
  }
}

sub confirmData {
  my ($db, $Data) = @_;
  my $body = '';
  unless ($Data->{'swmid'} and $Data->{'swwu'} and $Data->{'swwp'} and ($Data->{'swmidcopy'} or $Data->{'defaultcopyid'})) {
    return displayMenu('Please complete all fields')
  }
  my $st = qq[
    SELECT
      *
    FROM
      tblAssoc
    WHERE
      intAssocID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($Data->{'swmid'});
  my $swm1_href = $q->fetchrow_hashref();
  my $assocID = '';
  my $swol = '';
  my $swol_sport = $Data->{'defaultcopyid'};
  my $assoc_html = ''; 
  if ($Data->{'swmidcopy'}) {
    $q->execute($Data->{'swmidcopy'});
    my $swm2_href = $q->fetchrow_hashref();
    $assocID = $swm2_href->{'intAssocID'};
    $swol = $swm2_href->{'intSWOL'};
    $swol_sport = $swm2_href->{'intSWOL_SportID'};
    $assoc_html = qq[You are requesting to copy the SWOL Config options from: <b>$swm2_href->{'strName'}</b>];
  }
  unless ($swm1_href->{'intAssocID'}) {
    return displayMenu('You have not entered a valid SWM ID')
  }
  unless ($swm1_href->{'strFirstSyncCode'} eq '' or $swm1_href->{'strFirstSyncCode'} eq $Data->{'fsc'}) {
    return displayMenu('Sync codes do not match')
  }
  unless ($swm1_href->{'intSWOL_SportID'} > 0) {
    return displayMenu('SWOL Sport ID is not set')
  }
  unless (
    $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_HOCKEY     # HOCKEY
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_FOOTBALL  # AFL
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_LACROSSE  # LACROSSE
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_SOCCER  # SOCCER
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_NETBALL  # NETBALL
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_BASKETBALL  # BASKETBALL
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_LEAGUE  # LEAGUE
    or $swm1_href->{'intSWOL_SportID'} == 9  # GENERIC
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_TOUCH_FOOTBALL # TOUCH
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_WATER_POLO # WATER POLO
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_LAWN_BOWLS # LAWN BOWLS
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_BASEBALL #BASEBALL (obviously)
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_VOLLEYBALL 
    or $swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_UNION 
  ) {
    return displayMenu('SWOL Sport ID is not for a valid SWOL Sport')
  }
  if ($assocID and $Data->{'defaultcopyid'}) {
    return displayMenu('You have entered both and id to copy as well as selected default settings');
  }
  unless ($assocID or $Data->{'defaultcopyid'}) {
    return displayMenu("You have not entered a valid SWM ID to copy from")
  }
  unless ($swol == 1 or $Data->{'defaultcopyid'}) {
    return displayMenu('Copy association does not have SWOL turned on')
  }
  unless ($swm1_href->{'intSWOL_SportID'} == $swol_sport) {
    return displayMenu('SWOL Sport IDs are not for the same sport')
  }
  my $sport = '';
  $sport = "Hockey" if ($swm1_href->{'intSWOL_SportID'} == 1);
  $sport = "AFL" if ($swm1_href->{'intSWOL_SportID'} == 3);
  $sport = "Lacrosse" if ($swm1_href->{'intSWOL_SportID'} == 4);
  $sport = "Soccer" if ($swm1_href->{'intSWOL_SportID'} == 5);
  $sport = "Netball" if ($swm1_href->{'intSWOL_SportID'} == 6);
  $sport = "Basketball" if ($swm1_href->{'intSWOL_SportID'} == 7);
  $sport = "League" if ($swm1_href->{'intSWOL_SportID'} == 8);
  $sport = "Generic" if ($swm1_href->{'intSWOL_SportID'} == 9);
  $sport = "Touch" if ($swm1_href->{'intSWOL_SportID'} == 10);
  $sport = "Water Polo" if ($swm1_href->{'intSWOL_SportID'} == 11);
  $sport = "Lawn Bowls" if ($swm1_href->{'intSWOL_SportID'} == 12);
  $sport = "Baseball" if ($swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_BASEBALL);
  $sport = "Volleyball" if ($swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_VOLLEYBALL);
  $sport = "Rugby Union" if ($swm1_href->{'intSWOL_SportID'} == $Defs::SPORT_UNION);
  $assoc_html = qq[<p>You are requesting to copy the default SWOL Config options for: <b>$sport</b></p>] unless ($assoc_html);
  $body = qq[
  <p><b>Please confirm the following:</b></p>
  <p>You are requesting to setup SWOL for: <b>$swm1_href->{'strName'}</b></p>
  $assoc_html
  <p>You are setting SWOL up for: <b>$sport</b></p>
  <p><i>If you are uncertain about the above then <b>DO NOT</b> click on the below set-up button. If you are happy that the above details are correct then click confirm to proceed</p>
  <form name="confirm_swol" action="?action=UTILS_SWOL_setup&intAssocID=$Data->{'swmid'}" method="post">
    <input type="hidden" name="a" value="setup">
    <input type="hidden" name="action" value="UTILS_SWOL_setup">
    <input type="hidden" name="swmid" value="$Data->{'swmid'}">
    <input type="hidden" name="swmidcopy" value="$Data->{'swmidcopy'}">
    <input type="hidden" name="defaultcopyid" value="$Data->{'defaultcopyid'}">
    <input type="hidden" name="fsc" value="$Data->{'fsc'}">
    <input type="hidden" name="swwu" value="$Data->{'swwu'}">
    <input type="hidden" name="swwp" value="$Data->{'swwp'}">
    <input type="hidden" name="sport" value="$swm1_href->{'intSWOL_SportID'}">
    <input type="submit" value="Setup SWOL for $swm1_href->{'strName'}">
  </form>
  <form name="confirm_swol" action="?action=UTILS_SWOL_setup&intAssocID=$Data->{'swmid'}" method="post">
    <input type="hidden" name="action" value="UTILS_SWOL_setup">
    <input type="hidden" name="a" value="">
    <input type="submit" value="Cancel SWOL setup for $swm1_href->{'strName'}">
  </form>
  ];
  return $body;
}

sub displayMenu {
  my ($error,$Data, $assocID) = @_;
  $error = qq[<p class="error"><b>Error:</b> $error</p>] if ($error);
  my $hockey = ($Data->{'defaultcopyid'} == $Defs::SPORT_HOCKEY) ? 'SELECTED' : '';
  my $afl = ($Data->{'defaultcopyid'} == $Defs::SPORT_FOOTBALL) ? 'SELECTED' : '';
  my $lacrosse = ($Data->{'defaultcopyid'} == $Defs::SPORT_LACROSSE) ? 'SELECTED' : '';
  my $soccer = ($Data->{'defaultcopyid'} == $Defs::SPORT_SOCCER) ? 'SELECTED' : '';
  my $netball = ($Data->{'defaultcopyid'} == $Defs::SPORT_NETBALL) ? 'SELECTED' : '';
  my $basketball = ($Data->{'defaultcopyid'} == $Defs::SPORT_BASKETBALL) ? 'SELECTED' : '';
  my $league = ($Data->{'defaultcopyid'} == $Defs::SPORT_LEAGUE) ? 'SELECTED' : '';
  my $generic = ($Data->{'defaultcopyid'} == 9) ? 'SELECTED' : '';
  my $touch = ($Data->{'defaultcopyid'} == $Defs::SPORT_TOUCH_FOOTBALL) ? 'SELECTED' : '';
  my $water_polo = ($Data->{'defaultcopyid'} == $Defs::SPORT_WATER_POLO) ? 'SELECTED' : '';
  my $lawn_bowls = ($Data->{'defaultcopyid'} == $Defs::SPORT_LAWN_BOWLS) ? 'SELECTED' : '';
  my $baseball = ($Data->{'defaultcopyid'} == $Defs::SPORT_BASEBALL) ? 'SELECTED' : '';
  my $volleyball = ($Data->{'defaultcopyid'} == $Defs::SPORT_VOLLEYBALL) ? 'SELECTED' : '';
  my $union = ($Data->{'defaultcopyid'} == $Defs::SPORT_UNION) ? 'SELECTED' : '';
  return qq[
    $error
    <p><b>Note:</b> If data is to be imported then the conversion script needs to be run before using this utility</p>
    <form name="swol_setup" action="?action=UTILS_SWOL_setup&intAssocID=$Data->{'swmid'}" method="post">
    <table border="0">
      <tr>
        <td>SWM ID:</td>
        <td><input type="text" name="swmid" value="$Data->{'swmid'}"></td>
      </tr>
      <tr>
        <td>SWM ID to copy from:</td>
        <td>
          <input type="text" name="swmidcopy" value="$Data->{'swmidcopy'}"> 
          or
          Default
          <select name="defaultcopyid">
            <option value=""></option>
            <option value="$Defs::SPORT_HOCKEY" $hockey>Hockey</option>
            <option value="$Defs::SPORT_FOOTBALL" $afl>AFL</option>
            <option value="$Defs::SPORT_LACROSSE" $lacrosse>Lacrosse</option>
            <option value="$Defs::SPORT_SOCCER" $soccer>Soccer</option>
            <option value="$Defs::SPORT_NETBALL" $netball>Netball</option>
            <option value="$Defs::SPORT_BASKETBALL" $basketball>Basketball</option>
            <option value="$Defs::SPORT_LEAGUE" $league>League</option>
            <option value="$Defs::SPORT_UNION" $union>Rugby Union</option>
            <option value="9" $generic>Generic</option>
            <option value="$Defs::SPORT_TOUCH_FOOTBALL" $touch>Touch</option>
            <option value="$Defs::SPORT_WATER_POLO" $water_polo>Water Polo</option>
            <option value="$Defs::SPORT_LAWN_BOWLS" $lawn_bowls>Lawn Bowls</option>
            <option value="$Defs::SPORT_BASEBALL" $baseball>Baseball</option>
            <option value="$Defs::SPORT_VOLLEYBALL" $volleyball>Volleyball</option>
          </select>
          Settings
        </td>
      </tr>
      <tr>
        <td>First Sync Code:</td>
        <td><input type="text" name="fsc" value="$Data->{'fsc'}"></td>
      </tr>
      <tr>
        <td>SWW Username:</td>
        <td><input type="text" name="swwu" value="$Data->{'swwu'}"></td>
      </tr>
      <tr>
        <td>SWW Password:</td>
        <td><input type="text" name="swwp" value="$Data->{'swwp'}"></td>
      </tr>
      <tr><td>&nbsp;</td></tr>
      <tr>
        <td colspan="2">
  <input type="hidden" name="action" value="UTILS_SWOL_setup">  
	<input type="hidden" name="a" value="confirm">
          <input type="submit" value="SETUP">
        </td>
      </tr>
    </table>
    </form>
  ];
}


