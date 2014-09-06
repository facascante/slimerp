#
# $Header: svn://svn/SWM/trunk/web/AuditLogObj.pm 9863 2013-11-13 02:40:56Z apurcell $
#

package AuditLogObj;

use strict;

use lib '..','../..';
use Defs;
use Log;

sub new {
    my $this   = shift;
    my $class  = ref($this) || $this;
    my %params = @_;
    my $self   = {};
    bless $self, $class;
    $self->{'db'} = $params{'db'};
    return undef if !$self->{'db'};
    return $self;
}

sub log {
    my $self   = shift;
    my %params = @_;
    return undef if ( !$params{'username'} );
    my $st = qq[
    INSERT INTO tblAuditLog (
      intAuditLogID,
      intID,
      strUsername,
      intPassportID,
      strType,
      strSection,
      intLoginEntityTypeID,
      intLoginEntityID,
      intEntityTypeID,
      intEntityID,
      dtUpdated
    )
    VALUES (
      0,
      ?,
      ?,
      ?,
      ?,
      ?,
      ?,
      ?,
      ?,
      ?,
      now()
    )
  ];
    my $q = $self->{'db'}->prepare($st);
    $q->execute(
        $params{'id'},
        $params{'username'}          || '',
        $params{'passportID'}        || 0,
        $params{'type'}              || '',
        $params{'section'}           || '',
        $params{'login_entity_type'} || 0,
        $params{'login_entity'}      || 0,
        $params{'entity_type'}       || 0,
        $params{'entity'}            || 0
    );
    my $logID = $q->{mysql_insertid} || 0;

    if ( $params{'fields'} ) {
        my $details_sql = qq[
        INSERT INTO tblAuditLogDetails (
          intAuditLogID,
          strField,
          strPreviousValue
        )
        VALUES (
          ?,
          ?,
          ?
        )
      ];
        my $details_stmt = $self->{'db'}->prepare($details_sql);

        foreach my $field ( keys %{ $params{'fields'} } ) {
            my $old_value = $params{'fields'}->{$field}->{'old_value'};
            my $new_value = $params{'fields'}->{$field}->{'new_value'};
            
            if ( !defined $old_value ) {
                $old_value = '';
            }

            $details_stmt->execute( $logID, $field, $old_value );
        }
    }

    return $logID;
}

sub getlog {
    my $self   = shift;
    my %params = @_;
    return undef unless ( 
        $params{'EntityTypeID'}
        and $params{'EntityID'} );
    my $st = qq[
      SELECT
        intAuditLogID,
        intID,
        strUsername,
                intPassportID,
        strType,
        strSection,
        intLoginEntityTypeID,
        intLoginEntityID,
        dtUpdated AS dtUpdatedRaw,
        DATE_FORMAT(dtUpdated,"%d/%m/%Y %H:%i") as dtUpdated
      FROM
        tblAuditLog
      WHERE
        intEntityTypeID = ?
        AND intEntityID = ?
      ORDER BY
        intAuditLogID DESC
      LIMIT 500
    ];
    
    my $details_sql = qq[
      SELECT
        ALD.intAuditLogDetailsID,
        AL.intAuditLogID,
        strField,
        strPreviousValue
      FROM
        tblAuditLogDetails as ALD
        INNER JOIN tblAuditLog as AL on (
          ALD.intAuditLogID = AL.intAuditLogID
        )
      WHERE
        AL.intEntityTypeID = ?
        AND AL.intEntityID = ?
      ORDER BY
        intAuditLogID DESC
      LIMIT 500
    ];
    
    my $q = $self->{'db'}->prepare($st);
    $q->execute( $params{'EntityTypeID'}, $params{'EntityID'} );
    
    my $details_stmt = $self->{'db'}->prepare($details_sql);
    $details_stmt->execute( $params{'EntityTypeID'}, $params{'EntityID'} );
    my $details_ref = $details_stmt->fetchall_hashref([ qw(intAuditLogID intAuditLogDetailsID) ]);
    
    my @audit_log   = ();
    my $i           = 0;
    my $min_offset  = $params{'Offset'} || 0;
    my $max_offset  = $min_offset + 20;
    my %passportIDs = ();

    while ( my $dref = $q->fetchrow_hashref() ) {
        $passportIDs{ $dref->{'intPassportID'} } = 1 if $dref->{'intPassportID'};
        $self->_get_log_text($dref);
        
        my $id = $dref->{'intAuditLogID'};
        if ($details_ref->{$id}) {
            foreach my $details_id (keys %{$details_ref->{$id}}) {
                push @{$dref->{'details'}}, $details_ref->{$id}->{$details_id};               
            }
        }
        push @audit_log, $dref if ( $i > $min_offset and $i <= $max_offset );
        $i++;
    }

    #if(scalar keys %passportIDs)   {
    #my $passport = new Passport(
      #db => $self->{'db'},
    #);
        #my @authlist = keys %passportIDs;
    #my $PassportData = $passport->bulkdetails_hash(\@authlist);
        #for my $logrow (@audit_log)    {
            #if($logrow->{'intPassportID'}) {
                #my $name = 
                    #$PassportData->{$logrow->{'intPassportID'}}{'FirstName'} 
                    #. ' ' 
                    #. $PassportData->{$logrow->{'intPassportID'}}{'FamilyName'};
                #$logrow->{'PassportName'} = $name if $name;
            #}
        #}
  #}

    return ( \@audit_log, $i );
}

sub _get_log_text {
    my $self = shift;
    my ($recorddata) = @_;
    return $recorddata;
}

1;