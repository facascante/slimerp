package MRTConfig;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = @EXPORT_OK = qw(handle_mrt_config);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use DBUtils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;
use Log;
use Data::Dumper;

sub handle_mrt_config {
  my($db, $action, $target) = @_;
  my $id = param('id') || 0;
  my ($body, $menu);

  if ($action eq 'UTILS_MRT_form') {
      ($body, $menu) = mrt_config_form($target);
  }
  elsif ($action eq 'UTILS_MRT_update') {
      ($body, $menu) = update_mrt_config($target);
  }
  elsif ($action eq 'UTILS_MRT_insert') {
      ($body, $menu) = insert_mrt_config($target); 
  }
  elsif ($action eq 'UTILS_MRT_delete') {
      ($body, $menu) = delete_mrt_config($target); 
  }
  else {
      ($body, $menu) = list_mrt_config($target);
  }
  return ($body, $menu);
}


sub list_mrt_config	{
    my ($target) = @_;
    my $data = query_data(qq[
        SELECT * FROM tblMemberRecordTypeConfig
        ORDER BY strName, intEntityTypeID DESC, intRealmID, intSubRealmID, intEntityID
    ]);

    my $count = 0;
    my $body = qq[
    <thead>
        <td> <b>Entity Type ID</b>
        <td> <b>Entity ID</b>
        <td> <b>Realm ID</b>
        <td> <b>Sub Realm ID</b>
        <td> <b>Config Name</b>
        <td> <b>Config Value</b>
    </thead> 
    ];

    for my $dref (@$data) {
        foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
        my $class = '';
        my $classborder = 'commentborder';
        if($count++%2 == 1) {
            $class = q[ class="commentshaded" ];
            $classborder = "commentbordershaded";
        }
        $body .= qq[
        <tr>
        <td class="$classborder">$dref->{intEntityTypeID}</td>
        <td class="$classborder">$dref->{intEntityID}</td>
        <td class="$classborder">$dref->{intRealmID}</td>
        <td class="$classborder">$dref->{intSubRealmID}</td>
        <td class="$classborder">$dref->{strName}</td>
        <td class="$classborder">$dref->{strValue}</td>
        <td class="$classborder">[<a href="$target?action=UTILS_MRT_form&amp;id=$dref->{intMemberRecordTypeConfigID}">Edit</a>]</td>
        <td class="$classborder">[<a href="$target?action=UTILS_MRT_delete&amp;id=$dref->{intMemberRecordTypeConfigID}">Delete</a>]</td>
        </tr>
        ];
    }
    if(!$body)  {
        $body .= qq[
        <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
        <tr>
        <td colspan="3" align="center"><b><br> No Member Record Type Config were found <br><br></b></td>
        </tr>
        </table>
        <br>
        ];
    }
    else  {
        $body = qq[
        <p><a href="$target?action=UTILS_MRT_form">Add New Config</a> </p>
        <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
        $body
        </table><br>
        ];
    }
    return ($body, '');
}

sub mrt_config_form {
    my ($target) = @_;
    my $fields = {};
    my $action = "UTILS_MRT_insert";
    my $btn_text = "Add";
    
    my $id = param('id');
    if ($id) {
        $fields = query_one(qq[
            SELECT * FROM tblMemberRecordTypeConfig
            WHERE intMemberRecordTypeConfigID = $id
            ]);
        $action = "UTILS_MRT_update";
        $btn_text = "Update";
        INFO Dumper($fields);
    }

    $fields->{'intEntityTypeID'} ||= 0;
    $fields->{'intEntityID'} ||= 0;
    $fields->{'intRealmID'} ||= 0;
    $fields->{'intSubRealmID'} ||= 0;
    $fields->{'strName'} ||= '';
    $fields->{'strValue'} ||= '';

    my $body = qq[
    <form action="$target?action=$action&amp;id=$id" method=POST>
    <table width="100%">
    <tr>
    <td class="formbg fieldlabel">Entity Type ID:</td>
    <td class="formbg"><input type="text" name="intEntityTypeID" value="$fields->{'intEntityTypeID'}"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Entity ID:</td>
    <td class="formbg"><input type="text" name="intEntityID" value="$fields->{'intEntityID'}"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Realm:</td>
    <td class="formbg"><input type="text" name="intRealmID" value="$fields->{'intRealmID'}" size="3"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Sub Realm:</td>
    <td class="formbg"><input type="text" name="intSubRealmID" value="$fields->{'intSubRealmID'}" size="3"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Config Name:</td>
    <td class="formbg"><input type="text" name="strName" value="$fields->{'strName'}"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Config Value</td>
    <td class="formbg"><input type="text" name="strValue" value="$fields->{'strValue'}"></td>
    </tr>
    <tr>
    <td class="formbg" colspan="2" align="center"><br>
    <input type="hidden" name="id" value="$id">
    <input type=submit value="$btn_text Config"><br>
    </td>
    </tr>
    </table>
    <input type="hidden" name="action" value="$action">
    </form>
    ];
    return ($body, '');
}

sub delete_mrt_config {
    my ($target) = @_;
    exec_sql(qq[
        DELETE FROM tblMemberRecordTypeConfig
        WHERE intMemberRecordTypeConfigID=?
        ], 
        param('id'));
    redirect_to_home($target);
}

sub update_mrt_config {
    my ($target) = @_;
    exec_sql(qq[
        UPDATE tblMemberRecordTypeConfig 
        SET intEntityTypeID=?, intEntityID=?, intRealmID=?, intSubRealmID=?, strName=?, strValue=?
        WHERE intMemberRecordTypeConfigID=?
        ], 
    
        param('intEntityTypeID') || undef, 
        param('intEntityID') || 0, 
        param('intRealmID') || 0, 
        param('intSubRealmID') || 0, 
        param('strName') || undef, 
        param('strValue') || undef, 
        param('id') || undef, 
    );

    redirect_to_home($target);
}

sub insert_mrt_config {
    my ($target) = @_;
    exec_sql(qq[ 
        INSERT INTO tblMemberRecordTypeConfig (
            intEntityTypeID, intEntityID, intRealmID, intSubRealmID, strName, strValue
        ) 
        VALUES (?, ?, ?, ?, ?, ?)
        ], 
        param('intEntityTypeID') || undef, 
        param('intEntityID') || 0, 
        param('intRealmID') || 0, 
        param('intSubRealmID') || 0, 
        param('strName') || undef, 
        param('strValue') || undef, 
    );
    redirect_to_home($target);
}

sub redirect_to_home {
    my ($target) = @_;
    my $query = new CGI;
    my $url = "$target?action=UTILS_MRT";
    print $query->redirect($url);
}

1;
