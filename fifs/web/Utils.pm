#
# $Header: svn://svn/SWM/trunk/web/Utils.pm 11573 2014-05-15 02:25:10Z sliu $
#

package Utils;

require Exporter;
@ISA =  qw(Exporter);

@EXPORT = @EXPORT_OK = qw(
commify connectDB disconnectDB debug db_error query_error authstring getDBSysDate HTML_link untaint_param untaint_number DB_Insert safe_param getQueryPreparedAndBound getSimpleSQL getSelectSQL getDeleteSQL getUpdateSQL htmlDumper pair_to_hash print_stack_trace now_str encode decode hash_list_to_hash
hash_to_kv_list);

use strict;
use lib "..", "../..";
use Defs;
use DBI;

use Devel::StackTrace;
use CGI qw(param);
use JSON;
use Data::Dumper;
use Log;
use SQL::Abstract;
use MIME::Base64::URLSafe;

# PUT COMMAS IN NUMBERS

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}


# CONNECT TO DATABASE

sub connectDB {
    my($option) = @_;
    my $dsn = ($option and $option eq 'reporting' and $Defs::DB_DSN_REPORTING)
    ? $Defs::DB_DSN_REPORTING
    : $Defs::DB_DSN;

    #DEBUG '[', caller, "] connect DB $dsn";
    my $db = DBI->connect($dsn, $Defs::DB_USER, $Defs::DB_PASSWD);

    if (!defined $db) { return "Database Error"; }
    else  { return $db; }

}


# DISCONNECT FROM DATABASE

sub disconnectDB {
    my($db)=@_; 
    if(defined $db) {
        $db->disconnect;
    }
}


# PRINT A MESSAGE TO STDERR

sub debug {
    my($msg, $stack) = @_;
    print STDERR $msg."\n";
    if($stack)  {
        require Devel::StackTrace;
        my $trace = Devel::StackTrace->new;
        print STDERR $trace->as_string; # like carp
    }
}

# QUERY ERROR

sub query_error {
    my($error)=@_;
    my $currenttime=scalar localtime();
    if(!defined $error) {$error="";}
    # THIS ROUTINE SHOULD BE CALLED WHEN THERE IS A PROBLEM WITH ONE OF THE DATABASE COMMANDS.
    warn($DBI::errstr);
    print "Content-type: text/html\n\n";
    print "<h2>An Error has Occurred, Sorry.</h2><BR>\n";
    print "$error<BR>\n";
    warn("$currenttime $error");
    warn("$DBI::errstr");
    #$dbh->disconnect();
    exit(0);
}


# DB CONNECT ERROR

sub db_error  {
    # THIS ROUTINE SHOULD BE CALLED WHEN THE PROGRAM CANNOT CONNECT TO THE DATABASE.
    warn($DBI::errstr);
    print "Content-type: text/html\n\n";
    print "<h2><FONT COLOR=#ff0000>Cannot connect to the database for some reason.</FONT><BR>\n</h2>";
    exit 0;
}


sub authstring (@)      {
    use MD5;
    my $m;
    $m = new MD5;
    $m->reset();
    $m->add($Defs::SECRET_SALT, @_);
    return $m->hexdigest();
}

sub is_tainted {
    my $var = shift;
    my $blank = substr( $var, 0, 0 );
    return not eval { eval "1 || $blank" || 1 };
}


sub getDBSysDate {
    my ($dbh) = @_;
    my $sql   = qq[SELECT SYSDATE()];
    my $query = $dbh->prepare($sql); 
    $query->execute();
    my ($dbSysDate) = $query->fetchrow_array();
    return $dbSysDate;
}

sub HTML_link {
    my ($label, $address, $params) = @_;

    return $label unless $address;

    my $cgi = new CGI;

    my $target;
    my $onClick;
    my $hrefonly;

    my @query_string;
    while (my($key, $value) = each %{ $params }) {
        next if (!$key and !$value);
        $target = $value, next if $key eq '-target';
        $onClick = $value, next if $key =~ /^-onclick$/i;
        $hrefonly = $value, next if $key eq '-hrefonly';
        push @query_string, "$key=$value";
    }

    my $seperator = (! @query_string) ? q{} : ($address =~ /\?/) ? '&' : '?';

    my $query_string = join('&', @query_string);

    my $r_params;

    $r_params->{-href} = "$address$seperator$query_string";

    return $r_params->{-href} if $hrefonly;

    $r_params->{-target} = $target if $target;
    $r_params->{-onClick} = $onClick if $onClick;

    return $cgi->a( $r_params, $label );
}

sub query_stat {
    my ($dbh, $sql, @data) = @_;  

    $sql =~ s/\t/    /g;
    my $sth = $dbh->prepare($sql);

    DEBUG '[', caller, "] Query SQL: $sql, Data: (@data)";
    $sth->execute(@data);
    DEBUG "last inserted id: ", $sth->{mysql_insertid} if ($sql =~ /INSERT/i);
    DEBUG "result count: ", $sth->rows;
    return $sth;
}

sub query_data {
    my ($dbh, $sql, @data) = @_;  

    DEBUG '[', caller, "] Query SQL: $sql, Data: (@data)";
    $sql =~ s/\t/    /g;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@data);

    my @result = ();  
    while (my $row = $sth->fetchrow_hashref()) {
        push @result, $row; 
    }    

    DEBUG "result count: ", scalar @result;
    return \@result;
}

sub untaint_param {
    my($field) = @_;

    return untaint_number( CGI::param($field) );
}

sub untaint_number {
    my ($value) = @_;
    return undef if !defined $value;
    $value =~ /^([0-9.]+)$/;
    $value = $1 || 0;

    return $value;
}

sub DB_Insert {

    use DeQuote;

    my($db, $table, $fields, $ignore_flag) = @_;

    my $statement;

    my $ignore = $ignore_flag ? 'IGNORE' : q{};


    for (ref $fields) {
        if (/^ARRAY$/) {
            foreach my $value (@{ $fields }) {

                next if $value eq 'NOW()';

                deQuote($db, \$value);
            }

            $statement =
            "INSERT $ignore INTO $table VALUES (" .
            join(',', @{ $fields }) .
            ')';

        }
        elsif (/^HASH$/) {
            foreach my $value (values %{ $fields }) {

                next if $value eq 'NOW()';

                deQuote($db, \$value);
            }

            $statement =
            "INSERT $ignore INTO $table (" .
            join(',', keys %{ $fields }) .
            ') VALUES (' .
            join(',', values %{ $fields }) . ')';
        }
        else {
            return;
        }
    }

    my $query = $db->prepare($statement);
    $query->execute() or query_error($statement);

    return $db->{mysql_insertid};

}

sub safe_param  {
    my ($field, $type) = @_;

    my $value = CGI::param($field);

    return undef if !defined $value;
    $type ||= 'word';

    if($type eq 'number') {
        $value =~ /^([\d.\-]+)$/;
        $value = $1 || undef;
    }
    elsif($type eq 'word')  {
        $value =~ /^([\d\w.\-]+)$/;
        $value = $1 || undef;
    }
    elsif($type eq 'action')  {
        $value =~ /^([\da-zA-Z\_]+)$/;
        $value = $1 || undef;
    }

    return $value;
}

sub getQueryPreparedAndBound {
    my ($dbh, $sql, $params) = @_;
    return undef if !$dbh;
    return undef if !$sql;
    my $q = $dbh->prepare($sql);
    my $count = 0;
    foreach (@$params) {
    $count++;
        $q->bind_param($count, $_);
    }
    return $q;
}

sub getSimpleSQL {
    my ($fields, $tableName, $whereField, $limit) = @_;

    my $sql = "SELECT $fields FROM $tableName where $whereField=?";
    $sql   .= " LIMIT $limit" if $limit;

    return $sql;
}

sub getSelectSQL {
    my ($source, $fields, $where, $order) = @_;
    my $sqlObj = SQL::Abstract->new();#new(bindtype=>'columns');
    my ($sql, @bindVals) = $sqlObj->select($source, $fields, $where, $order);
    return ($sql, @bindVals);#, $sqlObj);
}

sub getDeleteSQL {
    my ($tableName, $where) = @_;
    my $sqlObj = SQL::Abstract->new();
    my ($sql, @bindVals) = $sqlObj->delete($tableName, $where);
    return ($sql, @bindVals);
}

sub getUpdateSQL {
    my ($tableName, $fields, $where) = @_;
    my $sqlObj = SQL::Abstract->new();
    my ($sql, @bindVals) = $sqlObj->update($tableName, $fields, $where);
    return ($sql, @bindVals);
}

sub htmlDumper {
    my ($title, $var) = @_;
    my $dumper = Dumper($var);

    if ($Defs::DEBUG_INFO) {
        return qq[
        <b> $title </b> <br/>
        <pre> $dumper </pre>
        ];
    } else {
        return "";
    }
}

# convert an array of {"id" => x, "name" => y} 
# to a hash { x => y }
sub pair_to_hash {
    my ($pair_array) = @_;
    my $result = {};

    for my $item (@{$pair_array}) {
        $result->{$item->{'id'}} = $item->{'name'};
    }

    return $result;
}

sub print_stack_trace {
    my $trace = Devel::StackTrace->new;
    return $trace->as_string; # like carp
}

sub now_str {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time); 
    return sprintf("%02d/%02d/%04d", $mday, $mon+1, $year+1900);
}

sub encode {
    my $data = urlsafe_b64encode( $_[0] );
    $data =~ tr|abcdefghijklmnopqrstuvwxyz|zyxwvutsrqponmlkjihgfedcba|;
    return $data;
}

sub decode {
    my $data = $_[0];
    $data =~ tr|zyxwvutsrqponmlkjihgfedcba|abcdefghijklmnopqrstuvwxyz|;
    $data = urlsafe_b64decode($data);
    return $data;
}

# convert a list of hash to a single hash by given key and value fields
# given:  key_field = k1 and value_field = k2
# convert: [ {k1=>v11, k1=>v12}, {k1=>v21, k2=>v22}, ... ]
# to: { v11 => v12, v21 => v22 }
# Mostly used in HTMLForm SELECT options
sub hash_list_to_hash {
    my ($list, $key_field, $value_field) = @_;

    my $result = {};
    for my $item ( @$list ) {
        $result->{ $item->{$key_field} } = $item->{$value_field};
    }

    return $result;
}

#
# convert a hash to a key-value list in form [ {k=>..., v=>...}, ...]
#
sub hash_to_kv_list {
    my ($hash) = @_;
    my @result = ();
    for my $key (keys %$hash) {
        push @result, {k=>$key, v=>$hash->{$key}},
    }

    return \@result;
}
1;
# vim: set et sw=4 ts=4:
