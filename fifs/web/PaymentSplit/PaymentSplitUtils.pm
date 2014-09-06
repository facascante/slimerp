#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitUtils.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitUtils;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getPaymentSplitSettings);
@EXPORT_OK = qw(getPaymentSplitSettings);

use strict;

use Payments;
use Reg_common;


sub getPaymentSplitSettings {
    my ($Data) = @_;

    my %psSettings = ();
    $psSettings{'psRun'}    = 0;
    $psSettings{'psSplits'} = 0;
    $psSettings{'psBanks'}  = 0;
    $psSettings{'psProds'}  = 0;

    my $allowSplits = $Data->{'SystemConfig'}{'AllowPaymentSplits'} || 0;
    my $ruleID      = $Data->{'SystemConfig'}{'PaymentSplitRuleID'} || 0;

    if ($allowSplits and $ruleID) {
	    my $paymentSettings = getPaymentSettings($Data);

        if ($paymentSettings) {
            my $authLevel    = $Data->{'clientValues'}{'authLevel'}    || 0;
            my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0;

            # allow Bank Account entry
            $psSettings{'psBanks'} = 1 if ($currentLevel <= $Defs::LEVEL_NATIONAL and $currentLevel >= $Defs::LEVEL_CLUB);

						## Ability to turn payments off for an entire SubRealms clubs
            $psSettings{'psBanks'} = 0 if ($Data->{'SystemConfig'}{'PaymentsOffClubs'} and $authLevel <= $Defs::LEVEL_CLUB);


            # allow splits in products maintenance
            $psSettings{'psProds'} = 1 if ($authLevel >= $Defs::LEVEL_CLUB);

            # allow Payment Split Run into menu?
	        my $isPayPal = ($paymentSettings->{'paymentType'} == $Defs::PAYMENT_ONLINEPAYPAL);
            #$psSettings{'psRun'} = 1 if (!$isPayPal and $currentLevel == $Defs::LEVEL_NATIONAL);

            # allow Payment Splits to be entered?
            if ($authLevel >= $Defs::LEVEL_ASSOC) {
                if ($currentLevel == $Defs::LEVEL_ASSOC) {
                    if ($paymentSettings->{'gatewayLevel'} <= 5) { 
                        # will be either 5 or 100
                        # means that it is an assoc gateway
                        my $client = setClient($Data->{'clientValues'}) || '';
                        my %tempClientValues = getClient($client);
                        $tempClientValues{'assocID'} = 0;
                        $tempClientValues{'clubID'}  = 0;
                        my ($natPaymentSettings, undef) = getPaymentSettings($Data, 0, 0, \%tempClientValues);
			 #$natPaymentSettings->{'gatewayType'} = $paymentSettings->{'gatewayType'};
                        $psSettings{'psSplits'} = 1 if ($paymentSettings->{'gatewayType'} == $natPaymentSettings->{'gatewayType'});
                    }
                    else {
                        # means that the assoc is going thru the national gateway
                        $psSettings{'psSplits'} = 1;
                    }
                }
            }
			elsif ($authLevel == $Defs::LEVEL_CLUB)	{

                        $psSettings{'psSplits'} = 1;
			}
        }
    }
    return \%psSettings;
}

 
1;
