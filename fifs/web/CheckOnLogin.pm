#
# $Header: svn://svn/SWM/trunk/web/CheckOnLogin.pm 9003 2013-07-19 00:25:22Z fkhezri $
#

package CheckOnLogin;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(checkOnLogin);

use strict;
use Reg_common;
use Notifications;
use PaymentApplication qw(haveApplied);
use Payments;
use PaymentSplitUtils;

sub checkOnLogin	{
	my ($Data)=@_;
 
	my $realmID=$Data->{'Realm'} || 0;
	my $assocID=$Data->{'clientValues'}{'assocID'} || 0;
    my $clubID=$Data->{'clientValues'}{'clubID'} || 0;
    my $subtypeID=$Data->{'RealmSubType'} || 0;
	my $entityID = getID($Data->{'clientValues'});
	my $entityTypeID = $Data->{'clientValues'}{'currentLevel'};

	my $numduplicatesstr='';
	my $clrRequests ='';
    my $nab = 0;
    my $paymentsettings = getPaymentSettings($Data, $Defs::PAYMENT_ONLINEPAYPAL);
    my $paymentSplitSettings = getPaymentSplitSettings($Data);
    if($paymentSplitSettings->{'psBanks'}){
    $nab = 1 if($paymentsettings and $paymentsettings->{'gatewayType'} == $Defs::GATEWAY_NAB);

    $nab = 1 if ($Data->{'SystemConfig'}{'AllowNABSignup'}  and $entityTypeID == $Defs::LEVEL_ASSOC);
    $nab = 1 if ($Data->{'SystemConfig'}{'AssocConfig'}{'AllowNABSignup'} and $entityTypeID == $Defs::LEVEL_ASSOC);
    $nab = 1 if ($Data->{'SystemConfig'}{'AllowNABSignupClub'} and $entityTypeID == $Defs::LEVEL_CLUB);
    $nab = 1 if ($Data->{'SystemConfig'}{'AssocConfig'}{'AllowNABSignupClub'} and $entityTypeID == $Defs::LEVEL_CLUB);
    my $paypal = 0;
    $paypal = 1 if(!$Data->{'SystemConfig'}{'DisallowPaypalSignup'} and $paymentsettings and $paymentsettings->{'gatewayType'} == $Defs::GATEWAY_PAYPAL);
    my ($appID, $name, $date) = haveApplied($Data, $entityTypeID, $entityID, $Defs::PAYMENT_ONLINENAB);
    warn "appliaed ?: $appID ,nab : $nab , paypal: $paypal ";
    #if (!$appID){
        # if nab gateway is set AND not applied 
            #AND also paypal not set
                # AND it's either club or Assoc
        if( ( (!$appID and $nab) 
                    and  !$paypal
            ) 
                     and (
                        $entityTypeID == $Defs::LEVEL_ASSOC
                         or $entityTypeID == $Defs::LEVEL_CLUB
                    )
        ){
            addNotification(
                $Data,
                $entityTypeID,
                $entityID,
                {
                    type => 'Payment Application',
                    title => $Data->{'lang'}->txt('Collect your fees online-Find out more. ',0),
                    url =>  "$Data->{'target'}?client=XXX_CLIENT_XXX&amp;a=BA_",
                },
            );
        }
         else  {
            deleteNotification(
                $Data,
                $entityTypeID,
                $entityID,
                0,
                'Payment Application',
                0,
            );
        }
    }
         else  {
            deleteNotification(
                $Data,
                $entityTypeID,
                $entityID,
                0,
                'Payment Application',
                0,
            );
        }
=c    }
    else    {
            deleteNotification(
                $Data,
                $entityTypeID,
                $entityID,
                0,
                'Payment Application',
                0,
            );
      }
=cut
    if( $Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC )	{
		my $st_dupl=qq[
			SELECT COUNT(*)
			FROM tblMember 
				INNER JOIN tblMember_Associations ON (tblMember.intMemberID= tblMember_Associations.intMemberID)
			WHERE intAssocID = ?
				AND tblMember.intStatus=$Defs::MEMBERSTATUS_POSSIBLE_DUPLICATE
				AND tblMember.intRealmID = ?
		];
		my $q= $Data->{'db'}->prepare($st_dupl);
		$q->execute(
			$assocID,
			$realmID,
		);
		my ($numduplicates)=$q->fetchrow_array() || 0;
		$q->finish();
		if ($numduplicates) {
			addNotification(
				$Data,	
				$entityTypeID,
				$entityID,
				{
					type => 'duplicates',
					title => $Data->{'lang'}->txt('You have [_1] duplicate to resolve.', $numduplicates),
					url => 	"$Data->{'target'}?client=XXX_CLIENT_XXX&amp;a=DUPL_L",
				},
			);
		}
		else	{
			deleteNotification(
				$Data,	
				$entityTypeID,
				$entityID,
				0,
				'duplicates',
				0,
			);
		}
	}
}



1;
