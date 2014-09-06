package MatrixManage;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(
    list_matrix
    display_matrix
    insert_matrix
    del_matrix
);
@EXPORT_OK = qw(
    list_matrix
    display_matrix
    insert_matrix
    del_matrix
);

use lib "..","../..";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use TTTemplate;
use HTML::FillInForm;

sub list_matrix {
    my(
        $db,
    ) = @_;


    my $st = qq[
        SELECT xxx
        FROM xxxx
        WHERE xxxx

    ];
    my $query = $db->prepare($st);
    $query->execute();
    my @matrixData = ();
    while(my $dref= $query->fetchrow_hashref()) {
        push @matrixData, $dref;
    }

    my $body = runTemplate(
        { db => $db, },
        { 'matrix' => \@matrixData},
        "admin/matrix/list.templ"
    );
    return $body;
}


sub display_matrix {
    my(
        $db,
        $matrixId
    ) = @_;


    my $dref = {};
    if(!$matrixId)  {
        my $st = qq[
            SELECT xxx
            FROM xxxx
            WHERE 
                matrixId = ?
        ];
        my $query = $db->prepare($st);
        $query->execute($matrixId);
        $dref= $query->fetchrow_hashref() || {};
    }

    my $templateout = runTemplate(
        { db => $db, },
        { 'matrix' => $dref },
        "admin/matrix/detail.templ"
    );
    my %htmlValues = (
        d_option1 => $dref->{'strOption1'} || '',
        d_option2 => $dref->{'strOption2'} || '',

    );

    my $body = HTML::FillInForm->fill(
      \$templateout,
      \%htmlValues,
    );

    return $body;
}


sub insert_matrix {
    my ($db )=@_;
    my $val1 =param('val1') || '';
    my $val2 =param('val1') || '';

    my $st=qq[
        INSERT INTO XXXX
        (
            XXXX,
            XXXXX
        )
        VALUES (
            ?,
            ?
        )
    ];
    my $q = $db->prepare($st);
    $q->execute(
        $val1,
        $val2,
    );
    my $error = '';
    return $error;
}

sub del_matrix {
    my ($db, $matrixId)=@_;
    return 'Invalid ID' if !$matrixId;

    my $st=qq[
        DELETE FROM XXXX
        WHERE XXXX
    ];
    my $q = $db->prepare($st);
    $q->execute($matrixId);
    return '';
}




