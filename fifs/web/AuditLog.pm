#
# $Header: svn://svn/SWM/trunk/web/AuditLog.pm 9863 2013-11-13 02:40:56Z apurcell $
#

package AuditLog;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(auditLog displayAuditLog);
@EXPORT_OK = qw(auditLog displayAuditLog);

use strict;

use lib "..";
use CGI qw(param unescape escape);
use Defs;
use Utils;
use Reg_common;
use DeQuote;
use AuditLogObj;
use GridDisplay;

sub displayAuditLog {
	my($Data)=@_;
  my $offset_IN = param('offset') || -1;
  my %levels = (
    $Defs::LEVEL_PERSON => 'personID',
    $Defs::LEVEL_CLUB => 'clubID',
    $Defs::LEVEL_ASSOC => 'assocID',
    $Defs::LEVEL_ZONE => 'zoneID',
    $Defs::LEVEL_REGION => 'regionID',
    $Defs::LEVEL_STATE => 'stateID',
    $Defs::LEVEL_NATIONAL => 'natID',
    $Defs::LEVEL_INTZONE => 'intzonID',
    $Defs::LEVEL_INTREGION => 'intregID',
    $Defs::LEVEL_INTERNATIONAL => 'interID' 
  );
  my $body = '';
  my $log = new AuditLogObj(db => $Data->{'db'});
  my ($auditlogdata, $total_records) = $log->getlog(
    EntityID => $Data->{'clientValues'}{$levels{$Data->{'clientValues'}{'currentLevel'}}}, 
    EntityTypeID => $Data->{'clientValues'}{'currentLevel'},
    Offset => $offset_IN || 0,
  );
  my $count = 0;
  my $details_count = 0;
  my $subBody = '';
	my @rowdata = ();
  for my $i (@{$auditlogdata}) {
		my $who = $i->{'UserName'} || '';
		push @rowdata, {
			id => $i->{'intAuditLogID'},
			dtUpdated => $i->{'dtUpdated'},
			dtUpdated_RAW => $i->{'dtUpdatedRaw'},
			strUsername => $who,
			strSection => $i->{'strSection'} || '',
			strType => $i->{'strType'} || '',
		};
		
		if ( $i->{'details'} ){
		    foreach my $details_ref ( @{$i->{'details'}} ) {
		        push @rowdata, {
                    id => $i->{'intAuditLogID'} . '_' . $details_ref->{'intAuditLogDetailsID'},
                    strUsername => $who,
                    strField => $details_ref->{'strField'} || '',
                    strPreviousValue => $details_ref->{'strPreviousValue'} || '',
                };
		        $details_count++;
		    }
		}
  }
	my @headerdata = (
		{
      name => 'Date',
      field => 'dtUpdated',
		},
		{
      name => 'Username',
      field => 'strUsername',
		},
		{
      name => 'Section',
      field => 'strSection',
		},
		{
      name => 'Type',
      field => 'strType',
		},
	);
	
	if ($details_count){
	    push @headerdata, {
	        name => 'Field',
            field => 'strField',
	    };
	    push @headerdata, {
            name => 'Old Value',
            field => 'strPreviousValue',
        };
	}
	
    if (@rowdata) {
		$body .= showGrid(
			Data => $Data,
			columns => \@headerdata,
			rowdata => \@rowdata,
			gridid => 'grid',
			width => '99%',
			height => 700,
		);
	}
	else	{
		$body='<div class="warningmsg">'.$Data->{'lang'}->txt('I cannot find any records of changes').'</div>';
	}
	return ($body,$Data->{'lang'}->txt('Audit Log'));
}

sub auditLog  {
  my ($id, $Data, $type, $section, $fields) = @_;
  return if ! $Data->{'db'};
  my $entity = getID($Data->{'clientValues'}) || 0;
  $entity = $id if ($entity == -1);
  my $log = new AuditLogObj(db => $Data->{'db'});
  $log->log(
    id => $id || 0,
    username => $Data->{'UserName'} || '',
	userID => $Data->{'clientValues'}{'userID'} || 0,
    type => $type,
    section => $section,
    login_entity_type => $Data->{'clientValues'}{'authLevel'} || 0,
    login_entity => $Data->{'clientValues'}{'_intID'} || 0,
    entity_type => $Data->{'clientValues'}{'currentLevel'} || 0,
    entity => $entity || 0,
    fields => $fields,
  );
  return 1;
}

1;
