#
# $Header: svn://svn/SWM/trunk/web/Lookup.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Lookup;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(lookup_handle getLookups);
@EXPORT_OK = qw(lookup_handle getLookups);

use lib qw(. ..);
use DBI;
use strict;
use CGI qw(:standard escape);
use Defs;
use Utils;
use DeQuote;
use FormHelpers;



# Example 

#my %config=(
	#select_sh => qq[
		#SELECT strCode, strName
		#FROM tblLookup
		#WHERE intLookupID=fred
	#],
	#update_sh => qq[
		#UPDATE tblLookup 
			#SET --VAL--
		#WHERE intLookupID=--ID--
	#],
	#insert_sh => qq[
		#INSERT INTO tblLookup
		#(intTest, --FIELD--)
		#VALUES (3, --VAL--)
	#],
	#key_field => 'intLookupID',
	#fields => [
		##Name, FieldName, size, maxsize, type
		#['strCode', 'Code', 4, 4, 'text'],
		#['strName', 'Name', 14, 14, 'text'],
	#],
	#form_fields =>qq[
		#<input type="hidden" name="fred" value="1">
	#],
#);


sub lookup_handle	{
  my($db, $target, $action, $config_ref)=@_;
  my $ID_IN=param('KF') || 0;
  $action=$action || param('lktask') || 'LK_list';

  my $body='';
  if($action eq 'LK_update') {
    my $oldaction=param('oldaction') || '';
		$body=update_sub($db, $oldaction, $ID_IN, $target, $config_ref); 
  }
  elsif($action eq 'LK_list') {
		$body=list_sub($db, $action, $target, $config_ref); 
  }
  elsif($action eq 'LK_del') {
		$body=del_sub($db, $action, $ID_IN, $target, $config_ref); 
  }
  else  {
    $body=details_sub($db, $action, $ID_IN, $target, $config_ref);
  }

  return $body;
}

# *********************SUBROUTINES BELOW****************************



sub details_sub	{
	my ($db, $action, $intLookupID, $target, $config_ref) = @_;

	my $dref;
	my($add, $edit,$view)=(0,0,0);
	if($action eq 'LK_add')	{$add=1;}
	elsif($action eq 'LK_edit')	{$edit=1;}
	else	{$view=1;}
	my %fieldNames=();
	for my $i	(@{$config_ref->{'fields'}})	{
			$fieldNames{$i->[0]}=1 if $i->[0];
	}


    my $txt;
    if (defined $config_ref->{lang}) {
        $txt = sub { $config_ref->{lang}->txt(@_) };
    }
    else {
        $txt = sub { @_ };
    }

	if ($edit or $view) {
		my $statement = $config_ref->{'detail_sh'} || '';
		$statement=~s/--ID--/$intLookupID/;
	  my $query = $db->prepare($statement) or query_error($statement);
	  $query->execute() or query_error($statement);

		$dref= $query->fetchrow_hashref();
		$query->finish();
		foreach my $key (keys %{$dref})	{ if(!defined $dref->{$key})	{$dref->{$key}='';} }
	}
	elsif ($add) {
		for my $i (keys %fieldNames)	{ $dref->{$i}=''; }
	}
	my $title;
    
    if ($txt->($config_ref->{'title'})) {
        ($title) = $txt->($config_ref->{'title'});
    }

	$title=qq[<div class="pageHeading">$title</div>] if $title;
	my $body = qq[
	<form action="$target" method=post>
		$title
		<table class="lkTable">
	];

	for my $row	(@{$config_ref->{'fields'}})	{
		next if !$row->[0];

        my ($label) = $txt->($row->[1]);

		my $display=$dref->{$row->[0]} || '';
		if($edit or $add) {
			$dref->{$row->[0]}='' if $dref->{$row->[0]} eq '00/00/0000';
			if($row->[4] eq 'text')	{
				$display=  txt_field('DB_'.$row->[0], $dref->{$row->[0]}, $row->[2], $row->[3]);
			}
			elsif($row->[4] eq 'dropdown')	{
				$display = drop_down('DB_'.$row->[0], $row->[2], $row->[3], $dref->{$row->[0]});
			}
			elsif($row->[4] eq 'checkbox')	{
				$display=  checkbox('DB_'.$row->[0], $dref->{$row->[0]}, $row->[2]);
			}
		}
		$body.=qq[
				<tr>
					<td class="label" >$label: </td>
					<td class="value">$display</td>
				</tr>
		];
	}
	if(!$view)	{
        my ($update) = $txt->('Update');
  	$body .= qq[
      <tr>
        <td><br></td>
        <td colspan="2"><br><br>
          <input type=submit value="$update " class = "button proceed-button"><br><br>
        </td>
      </tr>
		];
	}
  $body .= qq[
    </table>
    <input type="hidden" name="lktask" value="LK_update">
    <input type="hidden" name="oldaction" value="$action">
		<input type="hidden" name="KF" value="$intLookupID">
		].($config_ref->{'form_fields'} || '').qq[
  </form>
  ];
	return $body;
}


sub update_sub {
	my ($db, $action, $intID, $target, $config_ref) = @_;

	my $output=new CGI;
  #Get Parameters
  my %fields = $output->Vars;
	#Get rid of non DB fields
	for my $key (keys %fields)	{
		if($key!~/^DB_/)	{delete $fields{$key};}
	}
	#Cater for the fact that if a checkbox is unticked it submites nothing
	for my $row	(@{$config_ref->{'fields'}})	{
		next if !$row->[0];
		if($row->[4] eq 'checkbox')	{
			if(! exists $fields{'DB_'.$row->[0]})	{ $fields{'DB_'.$row->[0]}=$row->[3] || 0; }
		}
	}
	my %CompulsoryValues=();
	if(exists $config_ref->{'compulsory'} and $config_ref->{'compulsory'})	{
		%CompulsoryValues=%{$config_ref->{'compulsory'}};
	}
	deQuote($db, \%fields);
	my($valuelist,$fieldlist)='';
	if(!$intID and exists $config_ref->{increment})	{
		foreach my $field (keys %{$config_ref->{increment}})	{
			my $statement=	$config_ref->{increment}{$field} || '';
			my $query = $db->prepare($statement) or query_error($statement);
			$query->execute() or query_error($statement);
			my $val= $query->fetchrow_array() || 0;
			$query->finish();
			$val++;
			$fields{$field}=$val;
		}
	}
	for my $key (keys %fields)	{
		my $newkey=$key;
		$newkey=~s/DB_//g;
		#debug "intID: $intID";
    if($newkey=~/^dt/ and $fields{$key} ne "''")  {
      my ($error,$newdate)=fix_date($fields{$key});
      if($error)  {
        next;
      }
      else  {$fields{$key}="'$newdate'";}
		}
    if(exists $CompulsoryValues{$newkey} and $fields{$key} and $fields{$key} ne "''") {
				delete $CompulsoryValues{$newkey};
		}
		elsif(	$fields{$key} eq '0' and $CompulsoryValues{$newkey} and $config_ref->{'compulsoryallowzero'} and  $config_ref->{'compulsoryallowzero'}{$newkey} )	{
			delete $CompulsoryValues{$newkey};
    }
		if($intID)	{
			#Update
			if($valuelist ne '')	{$valuelist.=', ';}
			$valuelist.=qq[$newkey=$fields{$key}];
		}
		else	{
			#Insert
			if($valuelist ne '')	{$valuelist.=', ';}
			if($fieldlist)	{$fieldlist.=', ';}
			$valuelist.=qq[$fields{$key}];
			$fieldlist.=qq[$newkey];
		}
	}
	my $statement='';
	if($intID)	{
		$statement=$config_ref->{'update_sh'};
		$statement=~s/--VAL--/$valuelist/;
		$statement=~s/--ID--/$intID/;
	}
	else	{
		$statement=$config_ref->{'insert_sh'};
		$statement=~s/--FIELD--/$fieldlist/;
		$statement=~s/--VAL--/$valuelist/;
	}
  my $missing_fields=join("<br>\n",values %CompulsoryValues);
  if($missing_fields) {
    my $return_string='';
    if($missing_fields) {
      $return_string.=qq[
      <p class="errors">Error: Missing Information!</p>
      <p class="errors">The following fields need to be filled in</p>
      <p class="errors">$missing_fields</p>
      ];
    }
    $return_string.=qq[<br>
      <p class="errors">Click your browser&quot;s 'back' button to return to the previous page</p><br>
    ];
    return $return_string;
  }

	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute() or query_error($statement);
	if(!$intID)	{$intID=$query->{mysql_insertid};}
	return $config_ref->{'update_message'} || ''  if exists $config_ref->{'update_message'} ;
	return lookup_handle($db, $target, 'LK_list', $config_ref); 
}

sub list_sub	{
	my ($db, $action, $target, $config_ref) = @_;
	my $body='';
	my $statement=$config_ref->{'select_sh'};
	return '' if !$statement;
	$statement=~s/SELECT/SELECT $config_ref->{key_field}, /;
	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute() or query_error($statement);

    my $txt;
    if (defined $config_ref->{lang}) {
        $txt = sub { $config_ref->{lang}->txt(@_) };
    }
    else {
        $txt = sub { @_ };
    }

	my $count=0;
	while(my $dref= $query->fetchrow_arrayref())	{
		$count++;
		if(!$body)	{
			my $title;
            if ($txt->($config_ref->{'title'})) {;
                ($title) = $txt->($config_ref->{'title'});
            }
			$body.=qq[
		<div class="pageHeading">$title</div>
    <table class="lkTable">
			];
		}

		my $class = "";

		if ($count % 2 == 0) { $class = "listbar1"; }
		else { $class = "listbar2"; }

		my $line='';
		for my $i (1 .. $#$dref)	{
			my $val=$dref->[$i];
			if(exists $config_ref->{'select_list_hashref'} and exists $config_ref->{'select_list_hashref'}{$i-1})	{
				$val=$config_ref->{'select_list_hashref'}{$i-1}{$val};
			}
			$line.=qq[<td class="$class" align="left">$val</td>\n];
		}
		my $extra_link='';
		if($config_ref->{'extralistlink'} and $config_ref->{'extralistlinkname'})	{
			my $extralink_link = $config_ref->{'extralistlink'} ;
			$extralink_link =~s/--ID--/$dref->[0]/g;
			$extra_link=qq[<td class="$class" align="left"><a href="$extralink_link">$config_ref->{'extralistlinkname'}</a></td>];
		}
		my $editlink;
        
        unless ($config_ref->{'noeditlink'}) {
            $editlink =  qq[<td class="$class" align="left">];

            $editlink .= HTML_link(
                $txt->('Edit'),
                "$target?" . $config_ref->{'qry_string'},
                { lktask => 'LK_edit', KF => $dref->[0] },
            );

            $editlink .= '</td>';
        }
		
		if($line)	{
			$body.=qq[
				<tr>
					$line
					$extra_link
					$editlink
				</tr>
			];
		}
	}
    if(!$body)  {
        $body .= <<"EOS";
<table  class="lkTable">
  <tr>
    <td class="commentheading">
      <table cellpadding="2" cellspacing="0" border="0" width="100%">
        <tr>
          <td colspan="3" align="center"><br><b>
EOS

        $body .= join( q{}, $txt->('None Available') );
    
        $body .= <<"EOS";
          </b><br><br></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td align="center" colspan="3">
EOS

        $body .= HTML_link(
            $txt->('Add new record'),
            "$target?" . $config_ref->{'qry_string'},
            { lktask => 'LK_add' },
        );
    
        $body .= <<"EOS";
    </td>
  </tr>
</table>
<br>
EOS
    }
	else {
        $body .= <<"EOS";
<table cellpadding="2" cellspacing="0" border="0" width="100%">
  <tr><td colspan="3">&nbsp;</td></tr>
  <tr>
    <td align="center" colspan="3">
EOS

        $body .= HTML_link(
            $txt->('Add new record'),
            "$target?" . $config_ref->{'qry_string'},
            { lktask => 'LK_add' },
        );

        $body .= <<"EOS";
    </td>
  </tr>
</table>
EOS
	}

	return $body;
}

sub del_sub {
	my ($db, $action, $intID, $target, $config_ref) = @_;

	my $statement='';
	if($intID)	{
		$statement=$config_ref->{'delete_sh'};
		$statement=~s/--ID--/$intID/;
	}
 
	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute() or query_error($statement);
	return lookup_handle($db, $target, 'LK_list', $config_ref); 
}


sub fix_date  {
  my($date,%extra)=@_;
  if(exists $extra{NODAY} and $extra{NODAY})  {
    my($mm,$yyyy)=$date=~m:(\d+)/(\d+):;
    if(!$mm or !$yyyy)  { return ("Invalid Date",'');}
    if($yyyy <100)  {$yyyy+=2000;}
    return ("","$yyyy-$mm-01");
  }
  my($dd,$mm,$yyyy)=$date=~m:(\d+)/(\d+)/(\d+):;
  if(!$dd or !$mm or !$yyyy)  { return ("Invalid Date",'');}
  if($yyyy <100)  {$yyyy+=2000;}
  return ("","$yyyy-$mm-$dd");
}

1;
