
#
# $Header: svn://svn/SWM/trunk/web/AccreditationDisplay.pm 9520 2013-09-13 00:58:01Z dhanslow $
#

package AccreditationDisplay;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw( handleAccreditationDisplay );
@EXPORT_OK = qw( handleAccreditationDisplay );

use strict;
use CGI qw(param unescape escape);

use lib '.';
use Reg_common;
use Defs;
use Utils;
use FormHelpers;
use HTMLForm;
use AuditLog;
use FieldLabels;
use GridDisplay;
use DefCodes;

sub handleAccreditationDisplay {
  my ($action, $Data, $memberID) = @_;
  my $resultHTML = '';
  my $heading = '';
  unless ($Data->{'SystemConfig'}{'NationalAccreditation'} or $Data->{'SystemConfig'}{'AssocConfig'}{'NationalAccreditation'}) {
    $resultHTML = qq[<div class="warningmsg">Access Denied</div>];
    return ($resultHTML, 'Accreditation');
  }
  if ($action eq 'M_NACCRED_LIST') {
    ($resultHTML, $heading) = _listAccreditations($Data, $memberID);
  }
  elsif ($action eq 'M_NACCRED_DISPLAY') {
    ($resultHTML, $heading) = _displayAccreditation($Data, $memberID, 'display', $action);
  }
  elsif ($action eq 'M_NACCRED_NEW') {
    ($resultHTML, $heading) = _displayAccreditation($Data, $memberID, 'add', $action);
  }
  elsif ($action eq 'M_NACCRED_EDIT') {
    ($resultHTML, $heading) = _displayAccreditation($Data, $memberID, 'edit', $action);
  }
  elsif ($action eq 'M_NACCRED_DELETE') {
    ($resultHTML, $heading) = _deleteAccreditation($Data, $memberID);
  }
  $heading||='Accreditation';
  return ($resultHTML, $heading);
}

sub _listAccreditations {
  my ($Data, $memberID) = @_;
  my $db = $Data->{'db'};
  my $accreditation_title = $Data->{'SystemConfig'}{'ACCRED_Custom_Name'} || 'Accreditation';
  my $realmID = $Data->{'Realm'};
  my $st = qq[
    SELECT
      A.intAccreditationID,
      A.intQualificationID,
      Q.strName,
      LEVEL.strName AS intLevel,
      PROVIDER.strName AS intProvider,
      DATE_FORMAT(A.dtApplication,'%d/%m/%Y') AS dtApplication,
      DATE_FORMAT(A.dtStart,'%d/%m/%Y') AS dtStart_FORMAT,
      DATE_FORMAT(A.dtExpiry,'%d/%m/%Y') AS dtExpiry_FORMAT,
      A.dtStart,
      A.dtExpiry,
      A.intReaccreditation,
      STATUS.strName AS intStatus, 
      A.strCourseNumber,
      A.strNotes,
      Q.intEntityType,
      Q.intEntityID,
      Q.intMinLevel,
      TYPE.strName AS intType
    FROM
      tblAccreditation AS A
      INNER JOIN tblQualification AS Q ON (A.intQualificationID = Q.intQualificationID)
      LEFT JOIN tblDefCodes AS LEVEL ON (LEVEL.intCodeID = A.intLevel)
      LEFT JOIN tblDefCodes AS PROVIDER ON (PROVIDER.intCodeID = A.intProvider)
      LEFT JOIN tblDefCodes AS STATUS ON (STATUS.intCodeID = A.intStatus)
      LEFT JOIN tblDefCodes AS TYPE ON (TYPE.intCodeID = Q.intType)
    WHERE
      A.intMemberID = ?
      AND A.intRealmID = ?
      AND A.intRecStatus <> $Defs::RECSTATUS_DELETED
    ORDER BY
      A.dtExpiry DESC,
      A.dtStart DESC,
      A.dtApplication DESC
  ];
  my $q = $db->prepare($st);
  $q->execute($memberID, $realmID);
  my @rowdata = ();
  my $ID = getID($Data->{clientValues}, undef);
  while (my $dref = $q->fetchrow_hashref()) {
    my $displayLink = "$Data->{'target'}?client=$Data->{'client'}&a=M_NACCRED_DISPLAY&accredID=$dref->{intAccreditationID}";
    $dref->{'intReaccreditation'} = ($dref->{'intReaccreditation'} == 1 ) ? 'Yes' : 'No';
    $dref->{'dtStart_FORMAT'} = '' if ($dref->{'dtStart_FORMAT'} eq '00/00/0000');
    $dref->{'dtExpiry_FORMAT'} = '' if ($dref->{'dtExpiry_FORMAT'} eq '00/00/0000');
    push @rowdata, {
      SelectLink => $displayLink,
      id => $dref->{'intAccreditationID'},
      strName => $dref->{'strName'},
      intLevel => $dref->{'intLevel'},
      intProvider => $dref->{'intProvider'},
      dtStart => $dref->{'dtStart_FORMAT'},
      dtExpiry => $dref->{'dtExpiry_FORMAT'},
      intReaccreditation => $dref->{'intReaccreditation'},
      intStatus => $dref->{'intStatus'},
      strCourseNumber => $dref->{'strCourseNumber'},
      intType => $dref->{'intType'},
    };
  }
  my @headerdata = ();
  @headerdata = (
    {type => 'Selector', field => 'SelectLink',},
    {name => "Type", field => 'intType',},
    {name => "Name", field => 'strName',},
  );
  push @headerdata, {name => "Level", field => 'intLevel'};
  push @headerdata, {name => "Provider", field => 'intProvider'};
  push @headerdata, {name => "Start", field => 'dtStart'};
  push @headerdata, {name => "End", field => 'dtExpiry'};
  push @headerdata, {name => "CourseNumber", field => 'strCourseNumber'};
  push @headerdata, {name => "Status", field => 'intStatus'};
  push @headerdata, {name => "RA", field => 'intReaccreditation'};
  my $table= showGrid(
    Data => $Data,
    columns => \@headerdata,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
    height => 400,
  );
  my $addLink = _generateAddLink($Data);
  $table = $addLink . $table;
  return ($table, 'List '.$accreditation_title."s");
}

sub _displayAccreditation {
  my ($Data, $memberID, $option, $action) = @_;
  my $accredID = param('accredID') || 0;
  my $db = $Data->{'db'};
  my $realmID = $Data->{'Realm'};
  my $resultHTML = '';
  my $title = '';
  my $actionButtonText = 'Update Accreditation';
  my $fields = _loadAccredDetails($Data->{'db'}, $accredID) || ();
  my ($defcodes, $defcodesorder) = getDefCodes(
      dbh        => $Data->{'db'}, 
      realmID    => $Data->{'Realm'},
      subRealmID => $Data->{'RealmSubType'},
      assocID    => $Data->{'clientValues'}{'assocID'},
  );
  my $qualifications = _loadQualifications($db, $Data, $defcodes);
  my $editLink = _generateEditLink($Data, $fields);
  my $deleteLink = _generateDeleteLink($Data, $fields);
  my $links = '';
  if ($editLink or $deleteLink) {
    $links = qq[
      <div class="changeoptions">
        $editLink
        $deleteLink
      </div>
    ];
  }
  my $accreditation_title = $Data->{'SystemConfig'}{'ACCRED_Custom_Name'} || 'Accreditation';
  if ($option eq 'display') {
    $title = $accreditation_title.' Details';
  }
  elsif ($option eq 'edit') {
    $title = 'Edit '.$accreditation_title;
  }
  elsif ($option eq 'add') {
    $title = 'New '.$accreditation_title;
    $actionButtonText = 'Add '.$accreditation_title;
  }
  my %FieldDefinitions = (
    fields=> { 
      intQualificationID => {
        label => ($Data->{SystemConfig}{ACCRED_Qualification_name}) ? $Data->{SystemConfig}{ACCRED_Qualification_name} : 'Qualification',
        value => $fields->{intQualificationID},
        type  => 'lookup',
        options => $qualifications,
        firstoption => ['','Select Qualification'],
        compulsory => 1,
      },
      intSport => {
        label => 'Sport',
        value => $fields->{intSport},
        type  => 'lookup',
        options => $defcodes->{-501},
        order => $defcodesorder->{-501},
        firstoption => ['','Select Sport'],
      },
      intLevel => {
        label => ($Data->{SystemConfig}{HIDE_NACCRED_Level}) ? '' : 'Level',
        value => $fields->{intLevel},
        type  => 'lookup',
        options => $defcodes->{-502},
        order => $defcodesorder->{-502},
        firstoption => ['','Select Level'],
        compulsory => 1,
      },
      intProvider => {
        label => 'Provider',
        value => $fields->{intProvider},
        type  => 'lookup',
        options => $defcodes->{-503},
        order => $defcodesorder->{-503},
        firstoption => ['','Select Provider'],
      },
      dtApplication => {
        label => ($Data->{SystemConfig}{HIDE_NACCRED_ApplicationDate}) ? '' : 'Application Date',
        value => $fields->{dtApplication_FORMAT},
        type  => 'date',
        format => 'dd/mm/yyyy',
        validate => 'DATE',
      },  
      dtStart => {
        label => ($Data->{SystemConfig}{HIDE_NACCRED_StartDate}) ? '' : 'Start Date',
        value => $fields->{dtStart_FORMAT},
        type  => 'date',
        format => 'dd/mm/yyyy',
        validate => 'DATE',
        compulsory => ($Data->{SystemConfig}{COMPULSORY_NACCRED_StartDate}) ? 1 : 0,
      },  
      dtExpiry => {
        label => 'End Date',
        value => $fields->{dtExpiry_FORMAT},
        type  => 'date',
        format => 'dd/mm/yyyy',
        validate    => 'DATE',
      },  
      intReaccreditation => {
        label => ($Data->{SystemConfig}{HIDE_NACCRED_Reaccreditation}) ? '' : 'Reaccreditation',
        value => $fields->{intReaccreditation},
        type => 'checkbox',
        displaylookup => {1=>'Yes', 0=>'No'},
      },  
      strCourseNumber => {
        label => ($Data->{SystemConfig}{HIDE_NACCRED_CourseNumber}) ? '' : 'Course Number',
        value => $fields->{strCourseNumber},
        type => 'text',
      },
      intStatus => {
        label => 'Status',
        value => $fields->{intStatus},
        type => 'lookup',
        options => $defcodes->{-504},
        order => $defcodesorder->{-504},
        firstoption => ['','Select Status'],
      },  
      strNotes => {
        label => ($Data->{SystemConfig}{SHOW_NACCRED_Notes}) ? $Data->{SystemConfig}{SHOW_NACCRED_Notes}  : '',
        value => $fields->{strNotes},
        type => 'textarea',
      },
      strCustomStr1 => {
        label => ($Data->{SystemConfig}{SHOW_NACCRED_CustomStr1}) ? $Data->{SystemConfig}{SHOW_NACCRED_CustomStr1}  : '',
        value => $fields->{strCustomStr1},
        type => 'text',
      },
    },
    order => [qw(
      intQualificationID
      intReaccreditation
      intLevel
      intProvider
      dtApplication
      dtStart
      dtExpiry
      strCourseNumber
      strCustomStr1
      intStatus
      strNotes
    )],
    options => {
      labelsuffix => ':',
      hideblank => 1,
      target => $Data->{'target'},
      formname => 'n_form',
      submitlabel => $actionButtonText,
      introtext => 'auto',
      NoHTML => 1,
      updateSQL => qq[
        UPDATE tblAccreditation
        SET --VAL--
        WHERE intAccreditationID = $accredID
      ],
      addSQL => qq[
        INSERT INTO tblAccreditation
        ( intMemberID, intRealmID, intDataEntryPassportID, --FIELDS-- )
        VALUES ( $memberID, $realmID, $Data->{clientValues}{passportID}, --VAL-- )
      ],
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Accreditation'
      ],
      auditEditParams => [
        $accredID,
        $Data,
        'Update',
        'Accreditation'
      ],
      LocaleMakeText => $Data->{'lang'},
    },
    carryfields =>  {
      client => $Data->{'client'},
      a => $action,
      accredID => $accredID || 0
    },
  );

   #   strCourseNumberDDL => {
   #     label => ($Data->{SystemConfig}{SHOW_NACCRED_CourseNumberDDL}) ? 'Course Number' : '',
   #     value => $fields->{strCourseNumber},
   #     type  => 'lookup',
   #     options => $defcodes->{-506},
   #     order => $defcodesorder->{-506},
   #     firstoption => ['','Select Course Number'],
   #     compulsory => 1,
   #   },

  if ($Data->{SystemConfig}{SHOW_NACCRED_CourseNumberDDL}) {
    $FieldDefinitions{fields}{strCourseNumber}{type} = 'lookup';
    $FieldDefinitions{fields}{strCourseNumber}{options} = $defcodes->{-506};
    $FieldDefinitions{fields}{strCourseNumber}{order} = $defcodesorder->{-506};
    $FieldDefinitions{fields}{strCourseNumber}{firstoption} = ['','Select Course Number'];
  }

my %configchanges = ();
    if ( $Data->{'SystemConfig'}{'AccreditationFormReLayout'} ) {
        %configchanges = eval( $Data->{'SystemConfig'}{'AccreditationFormReLayout'} );
    }


  ($resultHTML, undef) = handleHTMLForm(\%FieldDefinitions, undef, $option, '', $Data->{'db'},\%configchanges );
  $resultHTML = $links . $resultHTML if ($links and $option eq 'display');
  return ($resultHTML, $title);
}

sub _deleteAccreditation {
  my ($Data, $memberID) = @_;
  my $accredID = param('accredID') || 0;
  my $st = qq[
    UPDATE tblAccreditation
    SET intRecStatus = $Defs::RECSTATUS_DELETED
    WHERE intAccreditationID = ?
  ];
  my $q = $Data->{db}->prepare($st);
  my $msg = '';
  if ($accredID) {
    $q->execute($accredID);
    auditLog($memberID, $Data, 'Delete', 'Accreditation');
    $msg = qq[<div class="OKmsg">Record deleted successfully</div>];

  }
  else {
    $msg = qq[<div class="warningmsg">Unable to delete Accreditation</div>];
  }
  return ($msg, 'Delete Accreditation');
}

sub _loadAccredDetails {
  my ($db, $accredID) = @_;
  my $st = qq[
    SELECT
      A.*,
      DATE_FORMAT(A.dtApplication,'%d/%m/%Y') AS dtApplication_FORMAT,
      DATE_FORMAT(A.dtStart,'%d/%m/%Y') AS dtStart_FORMAT,
      DATE_FORMAT(A.dtExpiry,'%d/%m/%Y') AS dtExpiry_FORMAT,
      Q.intEntityType,
      Q.intEntityID
    FROM
      tblAccreditation AS A
      INNER JOIN tblQualification AS Q ON (Q.intQualificationID = A.intQualificationID)
    WHERE
      A.intAccreditationID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($accredID);
  my $fields_ref = $q->fetchrow_hashref();
  return $fields_ref;
}

sub _loadQualifications {
  my ($db, $Data, $defcodes) = @_;
  my $st = qq[
    SELECT
      *
    FROM
      tblQualification
    WHERE
      intRealmID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($Data->{Realm});
  my %qualifications = ();
  while (my $fields_ref = $q->fetchrow_hashref()) {
    my $ID = getID($Data->{clientValues}, $fields_ref->{intEntityType});
    next if ($ID != $fields_ref->{intEntityID});
    my $type = $defcodes->{-505}{$fields_ref->{intType}} . ': ' || '';
    $qualifications{$fields_ref->{intQualificationID}} = $type . $fields_ref->{strName};
  }
  return \%qualifications;;
}

sub _generateAddLink {
  my ($Data) = @_;
  my $st = qq[
    SELECT
      * 
    FROM
      tblQualification
    WHERE
      intRealmID = ?
      AND intRecStatus <> $Defs::RECSTATUS_DELETED
  ];
  my $q = $Data->{db}->prepare($st);
  $q->execute($Data->{Realm});
  my $addLinkAllowed = '';
  while (my $href = $q->fetchrow_hashref()) {
    my $ID = getID($Data->{clientValues}, $href->{intEntityType});
    $addLinkAllowed = 'ok' if ($ID == $href->{intEntityID});
    $addLinkAllowed = '' if $Data->{'ReadOnlyLogin'};
  }
  if ($addLinkAllowed) {
    my $accreditation_title = $Data->{'SystemConfig'}{'ACCRED_Custom_Name'} || 'Accreditation';

    return qq[
      <div class="changeoptions">
        <span class="button-small generic-button"><a href="$Data->{'target'}?client=$Data->{'client'}&a=M_NACCRED_NEW">Add $accreditation_title</a></span>
      </div>
    ];
  }
  else {
    return '';
  }
}

sub _generateEditLink {
  my ($Data, $fields) = @_;
  my $ID = getID($Data->{clientValues}, $fields->{intEntityType});
  if ($ID == $fields->{intEntityID} and !$Data->{'ReadOnlyLogin'}) {
    return qq[
      <span class="button-small generic-button"><a href="$Data->{'target'}?client=$Data->{'client'}&a=M_NACCRED_EDIT&accredID=$fields->{intAccreditationID}">Edit Accreditation</a></span>
    ];
  }
  else {
    return '';
  }
}

sub _generateDeleteLink {
  my ($Data, $fields) = @_;
  my $ID = getID($Data->{clientValues}, $fields->{intEntityType});
  if ($ID == $fields->{intEntityID} and $Data->{clientValues}{authLevel} == $Defs::LEVEL_NATIONAL and !$Data->{'ReadOnlyLogin'}) {
    return qq[
      <span class="button-small generic-button"><a href="$Data->{'target'}?client=$Data->{'client'}&a=M_NACCRED_DELETE&accredID=$fields->{intAccreditationID}" onClick="return confirm('Are you sure that you wish to DELETE this Accreditation ?')">Delete Accreditation</a></span>
    ];
  }
  else {
    return '';
  }
}

sub ActiveNationalAccredSummary {
  my ($Data, $memberID) = @_;
  my $statement=qq[
    SELECT
      DC2.strName AS Type,
      Q.strName AS strName,
      DC1.strName AS Level,
      DATE_FORMAT(A.dtStart, "%d/%m/%Y") AS dtDate1,
      DATE_FORMAT(A.dtExpiry, "%d/%m/%Y") AS dtDate2
    FROM 
      tblAccreditation AS A
      LEFT JOIN tblDefCodes AS DC1 ON (A.intStatus = DC1.intCodeID)
      LEFT JOIN tblQualification AS Q ON (A.intQualificationID = Q.intQualificationID)
      LEFT JOIN tblDefCodes AS DC2 ON (Q.intType = DC2.intCodeID)
    WHERE 
      A.intRecStatus = 1
      AND A.intMemberID = ?
      AND A.dtStart <= SYSDATE()
      AND A.dtExpiry >= SYSDATE()
    ORDER BY
      A.dtStart,
      A.dtExpiry 
  ];
  my $query = $Data->{'db'}->prepare($statement);
  $query->execute($memberID);
  my @rowdata = ();
  while (my $dref=$query->fetchrow_hashref())  {
    push @rowdata, $dref;
  }
  return \@rowdata;
}

1;
