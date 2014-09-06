package DBUtils;

require Exporter;
@ISA =  qw(Exporter);

@EXPORT = @EXPORT_OK = qw(
    prepare_stat 
    exec_sql 
    exec_stat 
    query_data
    query_stat
    query_one 
    query_value 
    query_json_data
    db_save_data
);

use strict;
use lib "..", "../..";
use Defs;
use DBI;
use Devel::StackTrace;

use Data::Dumper;
use Log;
use Singleton;

sub clean_sql {
    my ( $sql ) = @_;
    (WARN "empty SQL: $sql" and return '') if (not $sql or $sql =~ /^\s*$/ );
    $sql =~ s/^\s+//;
    $sql =~ s/\s+$//;
    $sql =~ s/\t/    /g;
    return "\n\n$sql\n";
}

sub prepare_stat {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql ) = @_;
    DEBUG '[', caller, "] prepare SQL: $sql";
    return get_dbh()->prepare($sql);
}

sub exec_sql {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql, @data ) = @_;
    my @sql_list = split(';', $sql);
    my $sth;

    for my $s (@sql_list) {
        $s = clean_sql($s);
        next if $s eq '';

        DEBUG '[', caller, "] execute SQL $s \nwith data: (@data)";
        $sth = get_dbh()->prepare($s);
        my $result = $sth->execute(@data);

        if ($result) {
            DEBUG "last inserted id: ", $sth->{mysql_insertid} if $s =~ /insert /i;
        }
        DEBUG "-"x60;
    }

    return $sth;
}

sub exec_stat {
    my ( $sth, @data ) = @_;

    DEBUG '[', caller, "] execute SQL with data: (@data)";
    my $result = $sth->execute(@data);

    if ($result) {
        DEBUG "last inserted id: ", $sth->{mysql_insertid};
    }
    else {
        ERROR "execute statement error: ", $sth->errstr;
    }
    DEBUG "-"x60;
    return $sth;
}

sub query_stat {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql, @data ) = @_;

    $sql = clean_sql($sql);
    return undef if $sql eq '';

    DEBUG '[', caller, "] Query SQL: $sql, with data: (@data)";
    my $sth = get_dbh()->prepare($sql);
    $sth->execute(@data) or ERROR "execute SQL: $sql, error: ", $sth->errstr;

    DEBUG "last inserted id: ", $sth->{mysql_insertid} if ( $sql =~ /INSERT/i );
    DEBUG "result count: ", $sth->rows;
    DEBUG "-"x60;
    return $sth;
}

sub query_data {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql, @data ) = @_;

    $sql = clean_sql($sql);
    return [] if $sql eq '';

    DEBUG '[', caller, "] Query SQL: $sql, with data: (@data)";
    my $sth = get_dbh()->prepare($sql);
    $sth->execute(@data) or ERROR "execute SQL: $sql, error: ", $sth->errstr;

    my @result = ();
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @result, $row;
    }

    DEBUG "result count: ", scalar @result;
    DEBUG "-"x60;
    return \@result;
}

sub query_one {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql, @data ) = @_;

    $sql = clean_sql($sql);
    return {} if $sql eq '';

    DEBUG '[', caller, "] Query SQL: $sql, with data: (@data)";
    my $sth = get_dbh()->prepare($sql);
    $sth->execute(@data) or ERROR "execute SQL: $sql, error: ", $sth->errstr;

    my $result = $sth->fetchrow_hashref();
    #DEBUG "result: ", Dumper($result);
    DEBUG "-"x60;
    return $result;
}

sub query_value {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql, @data ) = @_;

    $sql = clean_sql($sql);
    return undef if $sql eq '';

    DEBUG '[', caller, "] Query SQL: $sql, with data: (@data)";
    my $sth = get_dbh()->prepare($sql);
    $sth->execute(@data) or ERROR "execute SQL: $sql, error: ", $sth->errstr;

    my @ary = $sth->fetchrow_array;
    my $result = (scalar @ary > 0) ? $ary[0] : undef;

    DEBUG "Result: $result "."-"x40;
    return $result;
}

sub query_json_data {
    shift if (@_ > 0 and ref($_[0]));
    my ( $sql, @data ) = @_;
    my $result = query_data( $sql, @data );

    return JSON::to_json( $result );
}

sub print_stack_trace {
    my $trace = Devel::StackTrace->new;
    return $trace->as_string; # like carp
}

# a generic method to save a hashref record to database
# and return key field
sub db_save_data {
    my ($tablename, $data, $extra) = @_;
    my $key_field = $extra->{'key'} || '';

    my @fields = keys %$data;
    # filter out the key field from field list
    if ($key_field) {
        @fields = grep { $_ ne $key_field } @fields;
    }

    # bind params for SQL
    my @values = @$data{@fields};

    if ($key_field and $data->{$key_field}) {
        # update data
        my $field_placeholders = join(', ', map {"$_ = ?"} @fields);

        my $SQL = qq[
        UPDATE $tablename
        SET $field_placeholders
        WHERE $key_field = ?
        ];

        DEBUG '[', caller, "] saving data", Dumper($data), "\nby $SQL \nwith data: (@values, $data->{$key_field})";
        my $sth = get_dbh()->prepare($SQL);
        $sth->execute(@values, $data->{$key_field}) or ERROR $sth->errstr;
        return $key_field ? $data->{$key_field} : 0;
    }
    else {
        # insert data

        my $field_list = join(', ', @fields);
        my $value_placeholders = '?,'x@values;
        chop($value_placeholders);
        my $SQL = qq[
            INSERT INTO $tablename ( $field_list ) 
            VALUES ( $value_placeholders )
        ];

        DEBUG '[', caller, "] saving data", Dumper($data), "\nby $SQL \nwith data: (@values)";
        my $sth = get_dbh()->prepare($SQL);
        $sth->execute(@values) or ERROR $sth->errstr;

        my $new_id = $sth->{mysql_insertid};
        return $new_id;
    }
}

1;
# vim: set et sw=4 ts=4:
