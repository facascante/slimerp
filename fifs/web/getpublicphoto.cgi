#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/getpublicphoto.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use warnings;
use CGI;
use lib "..",".";
use Defs;
use Reg_common;
use Utils;
use ConfigOptions;
use SystemConfig;

main();	

sub main	{
    my $cgi = new CGI;
    
    my $memberID = $cgi->param('memberID');
    if ($memberID !~/^\d+$/) {
        nophoto();
} 
    my $dbh = connectDB();
    my %Data = ();
    $Data{db} = $dbh;
    
    # Find all the associations that this member belongs to.
    my $statement  = qq[SELECT intAssocID,intRealmID FROM tblMember_Associations AS MA
                        INNER JOIN tblMember AS M ON (M.intMemberID = MA.intMemberID) 
                        WHERE MA.intMemberID = $memberID
                        AND MA.intRecStatus = $Defs::RECSTATUS_ACTIVE
                        AND intPhoto = 1];
    
    my $sth = $dbh->prepare($statement);
    $sth->execute();
    my $photo = 0;    
    while (my ($assocID, $realmID) = $sth->fetchrow_array()) {
	$Data{'Realm'} = $realmID; 
	$Data{'clientValues'}{'assocID'} = $assocID;
        my $Permissions = getSystemConfig(\%Data);
        if (exists($Permissions->{'AssocConfig'}{'AllowMemberPhotoPublic'})) 
             {
            $photo = 1;
            $sth->finish();

                                my $path='';
                                {
                                        my $l=6 - length($memberID);
                                        my $pad_num=('0' x $l).$memberID;
                                        my (@nums)=$pad_num=~/(\d\d)/g;
                                        for my $i (0 .. $#nums-1) { $path.="$nums[$i]/"; }
                                }
                                my $filename="$Defs::fs_upload_dir/$path$memberID.jpg";
                                open (FILE, "<$filename") || die("Can't open file $filename\n");
                                my $img='';
                                while(<FILE>)  { $img.= $_; }
                                close (FILE);
                                print "Content-type: image/jpeg\n\n";
                                print $img;

            disconnectDB($dbh);
            #printphoto($memberID);
        }
    }
    nophoto() if !$photo;
}

sub nophoto {
    print "Content-type: text/html\n\n"; 
    exit;
}

