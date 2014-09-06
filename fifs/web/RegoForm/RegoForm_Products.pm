#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Products.pm 11427 2014-04-29 07:09:10Z sliu $
#

package RegoForm_Products;
require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(getRegoProducts checkAllowedProductCount checkMandatoryProducts insertRegoTransaction);
@EXPORT_OK = qw(getRegoProducts checkAllowedProductCount checkMandatoryProducts insertRegoTransaction);

use strict;
use lib "..","../..";
use Products;
use Reg_common;
use AssocTime;
use TTTemplate;
use HTML::Entities;
use Utils;
use Date::Calc qw(Today Delta_YMD);

sub getRegoProducts {
    my $params = shift;
    my (
        $Data, 
        $assocID, 
        $formClubID,
        $realmID, 
        $defaultProductID, 
        $level, 
        $levelID, 
        $memdetails, 
        $multipersonType,
        $formID,
        $clubID,
        $filter_params,
        $parentBodyFormID,
        $isNodeForm,
        $program_id
    ) = @{$params}{qw/ Data assoc_ID form_club_ID realm_ID default_product_ID level level_ID member_details 
                       multiperson_type form_ID club_ID filter_params parent_body_form_ID is_node_form program_ID /};

    $levelID ||= -1;
    
    my $currencySymbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";
    $clubID ||= 0;

    $defaultProductID ||= 0;
    $parentBodyFormID ||= 0;

    my $productAttributes = Products::getFormProductAttributes($Data, $formID) || {};
    $multipersonType ||= ''; 
    my $cl  = setClient($Data->{'clientValues'});
    my $levelType = $Defs::LEVEL_ASSOC;
    $levelType = $Defs::LEVEL_CLUB if ($formClubID and $formClubID > 0);
    $levelType = $Defs::LEVEL_PROGRAM if ($program_id);

    my @query_params;
    my $clubWHERE = '';
    my $clubWHERE2 = '';
    
    if ($levelType == $Defs::LEVEL_PROGRAM and $program_id){
        @query_params = ($realmID, $assocID, $program_id, $levelID, $level, $assocID, $realmID, $assocID, $levelType, $assocID, $clubID, $formID);

        $clubWHERE = qq[ OR (PP.intID=? AND intLevel=$Defs::LEVEL_PROGRAM)];
    }
    elsif ($clubID and $clubID != $Defs::INVALID_ID) {
        @query_params = ($realmID, $assocID, $clubID, $levelID, $level, $assocID, $realmID, $assocID, $clubID, $levelType, $assocID, $clubID, $formID);

        $clubWHERE = qq[ OR (PP.intID=? AND intLevel=$Defs::LEVEL_CLUB)];

        $clubWHERE2 = qq[ AND ((P.intCreatedLevel=0) OR (P.intCreatedLevel=$Defs::LEVEL_CLUB AND P.intCreatedID=?) OR (P.intCreatedLevel>$Defs::LEVEL_CLUB))];
    }
    else {
        @query_params = ($realmID, $assocID, $levelID, $level, $assocID, $realmID, $assocID, $levelType, $assocID, $clubID, $formID);
        $clubWHERE2 = qq[ AND (P.intCreatedLevel <> $Defs::LEVEL_CLUB) ];
    }

    my %args = (
        dbh        => $Data->{'db'}, 
        levelID    => $levelID, 
        level      => $level, 
        assocID    => $assocID, 
        clubID     => $clubID, 
        realmID    => $realmID,
        formID     => $formID,
        isNodeForm => $isNodeForm,
        parentBodyFormID => $parentBodyFormID, 
    );

    $args{'added'} = 0;
    my $paidRegoProducts = getPaidRegoProducts(\%args);

    if ($isNodeForm) {
        $args{'added'} = 1;
        my $paidRegoProductsAdded = getPaidRegoProducts(\%args);
        foreach my $key (keys %$paidRegoProductsAdded) {
            $paidRegoProducts->{$key} = $paidRegoProductsAdded->{$key} if !exists $paidRegoProducts->{$key};
        }
    }

    my @paid_items = ();
    my %paid_product = ();

    foreach my $key (keys %$paidRegoProducts) {
        my $dref = $paidRegoProducts->{$key};
        $dref->{strProductNotes}=~s/\n/<br>/g;
        my $photolink = '';

        if($dref->{'intPhoto'}){
            my $hash = authstring($dref->{'intProductID'});
            my $pa   = $dref->{'intProductID'}.'f'.$hash;
            my $pID  = $dref->{'intProductID'};
            $photolink =qq[<img width ='20' height ='20' src ="getProductPhoto.cgi?pa=$pa&pID=$pID&client=$cl">];
        }

        my %itemdata = (
            Amount             => $dref->{'AmountCharged'} || 0,
            TransactionID      => $dref->{'intTransactionID'} || 0,
            ProductID          => $dref->{'intProductID'},
            Qty                => $dref->{'intQty'} || 0,
            AllowMultiPurchase => $dref->{'intAllowMultiPurchase'} || 0,
            Group              => $dref->{'strGroup'} || '',
            Status             => $dref->{'intStatus'},
            Name               => $dref->{'strName'} || '',
            ProductNotes       => decode_entities($dref->{'strProductNotes'}) || '',
            Photo              => $photolink,
        );
      push @paid_items, \%itemdata;
      $paid_product{$dref->{'intProductID'}} = 1;
    }

    %args = (
        dbh              => $Data->{'db'}, 
        queryParams      => \@query_params,
        clubWHERE        => $clubWHERE,
        clubWHERE2       => $clubWHERE2,
        defaultProductID => $defaultProductID,
        parentBodyFormID => $parentBodyFormID, 
    );

    $args{'added'} = 0;
    my $regoProducts = getAllRegoProducts(\%args);

    if ($isNodeForm) {
        $args{'added'} = 1;
        my $regoProductsAdded = getAllRegoProducts(\%args);
        foreach my $key (keys %$regoProductsAdded) {
            $regoProducts->{$key} = $regoProductsAdded->{$key} if !exists $regoProducts->{$key};
        }
    }

    my $i            = 0;
    my $count        = 0;
    my $anyAllowQty  = 0;
    my @unpaid_items = ();

    my $assoctime = assoctime($Data->{'db'}, $assocID, '',);

    my %product_seen;

    my @sorted = ();

    @sorted = sort {
        lc($regoProducts->{$a}{'strGroup'})    cmp lc($regoProducts->{$b}{'strGroup'})    ||
        lc($regoProducts->{$a}{'intSequence'}) <=> lc($regoProducts->{$b}{'intSequence'}) ||
        lc($regoProducts->{$a}{'strName'})     cmp lc($regoProducts->{$b}{'strName'})     ||
        lc($regoProducts->{$a}{'intLevel'})    <=> lc($regoProducts->{$b}{'intLevel'})
    } keys %$regoProducts;

    foreach my $key (@sorted) {
        my $dref = $regoProducts->{$key};
        $dref->{strProductNotes}=~s/\n/<br>/g;
        next if $product_seen{$dref->{'intProductID'}};
        next if $dref->{intInactive};
        my $filter_display = productAllowedThroughFilter($dref, $memdetails, $assoctime, $productAttributes, $filter_params);      
        $anyAllowQty ||= $dref->{'intAllowQtys'} || 0;
        my $amount = currency(getCorrectPrice($dref, $multipersonType)) || 0;
        my $paid = 0;
        my $unpaid = 0;
        next if ($paid_product{$dref->{'intProductID'}} and !$dref->{intAllowMultiPurchase});
        my $photolink = '';
         
        if($dref->{'intPhoto'}){
            my $hash = authstring($dref->{'intProductID'});
            my $pa = $dref->{'intProductID'}.'f'.$hash;
            $photolink =qq[<img width ='20' height ='20' src ="getProductPhoto.cgi?pa=$pa&pID=$dref->{'intProductID'}&client=$cl">];
        }

        my %itemdata = (
            Amount => $amount || 0,
            ProductID => $dref->{'intProductID'},
            AllowQty => $dref->{'intAllowQtys'} || 0,
            Qty => $dref->{'intQty'} || 0,
            AllowMultiPurchase => $dref->{'intAllowMultiPurchase'} || 0,
            Group => $dref->{'strGroup'} || '',
            TransactionID => $dref->{'intTransactionID'} || 0,
            Status => $dref->{'intStatus'},
            ProductNotes => decode_entities($dref->{'strProductNotes'}) || '',
            DefaultProduct => ($dref->{'intProductID'} == $defaultProductID) || 0,
            Mandatory => $dref->{'intIsMandatory'} || 0,
            Name => $dref->{'strName'} || '',
            Photo =>$photolink,
        );
        push @unpaid_items, \%itemdata if $filter_display;
        $count++;
        $product_seen{$dref->{intProductID}}=1;

    }
    return '' if !$count;

    my $AllowedCountText = '';
    my $AllowedCount = $Data->{'SystemConfig'}{'OnlineRego_productCount'} || 0;
    my $products = ($AllowedCount == 1) ? 'item' : 'items';
    $AllowedCountText = qq[You are only allowed to purchase $AllowedCount $products at a time] if $AllowedCount;
    my %PageData = (
        HideItemHeader => $Data->{'SystemConfig'}{'hideRegoFormItemsHeader'} || 0,
        HideQty => $Data->{'SystemConfig'}{'regoForm_HIDE_qty'} || !$anyAllowQty || 0,
        HideCost => $Data->{'SystemConfig'}{'regoForm_HIDE_cost'} || 0,
        HideAmountPaid => $Data->{'SystemConfig'}{'regoForm_HIDE_amountpaid'} || 0,
        HideNotes => $Data->{'SystemConfig'}{'regoForm_HIDE_Notes'} || 0,
        HideGroup => $Data->{'SystemConfig'}{'regoForm_HIDE_group'} || 0,
        AllowedCountText => $AllowedCountText || '',
        PaidItems => \@paid_items,
        UnPaidItems => \@unpaid_items,
        CurrencySymbol => $currencySymbol,
    );
    my $pagedata = '';
    $pagedata = runTemplate($Data, \%PageData, 'regoform/common/products.templ');
    return $pagedata || '';
}

sub getPaidRegoProducts {
    my ($params) = @_;

    my $dbh     = $params->{'dbh'};
    my $levelID = $params->{'levelID'};
    my $level   = $params->{'level'};
    my $assocID = $params->{'assocID'};
    my $clubID  = $params->{'clubID'};
    my $realmID = $params->{'realmID'};
    my $formID  = $params->{'formID'};
    my $added   = $params->{'added'}; #will only ever be set for a node form
    my $isNodeForm = $params->{'isNodeForm'};
    my $parentBodyFormID = $params->{'parentBodyFormID'};

    my $rfpAdded = ($added) ? 'Added' : '';
    my $rfpWhere = ' AND (RFP.intRegoFormID = ?';
    $rfpWhere   .= ' OR RFP.intRegoFormID = ?' if $parentBodyFormID;
    $rfpWhere   .= ')';
    $rfpWhere   .= (' AND RFP.intAssocID=? AND RFP.intClubID=?') if $added;

    my $sql = qq[
        SELECT DISTINCT 
            P.intProductID,
            P.strName,
            P.intAssocID,
            T.intStatus,
            T.intTransactionID,
            T.curAmount as AmountCharged,
            P.strGroup,
            P.intAllowMultiPurchase,
            P.strProductNotes,
            P.intInactive,
            T.intQty,
            P.intAllowQtys,
            P.intProductGender,
            P.intPhoto,
            RFP.intSequence
        FROM tblProducts as P
            INNER JOIN tblRegoFormProducts$rfpAdded AS RFP ON RFP.intProductID=P.intProductID
            INNER JOIN tblTransactions as T ON (T.intID=? AND T.intTableType=? AND T.intProductID=P.intProductID AND T.intAssocID=?)
        WHERE
            P.intRealmID=?
            AND T.intStatus=1
            AND (P.intAssocID=? OR P.intAssocID=0)
            $rfpWhere
        ORDER BY P.strGroup, RFP.intSequence, P.strName
    ];

    my @bindVars = ($levelID, $level, $assocID, $realmID, $assocID, $formID);
    push @bindVars, $parentBodyFormID if $parentBodyFormID;
    my $tempClubID = ($clubID > 0) ? $clubID : 0;
    push @bindVars, $assocID, $tempClubID if $added;

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);

    $q->execute();

    my $paidRegoProducts = $q->fetchall_hashref('intProductID');

    return $paidRegoProducts;
}

sub getAllRegoProducts {
    my ($params) = @_;

    my $dbh              = $params->{'dbh'};
    my $added            = $params->{'added'};
    my $queryParams      = $params->{'queryParams'};
    my $clubWHERE        = $params->{'clubWHERE'};
    my $clubWHERE2       = $params->{'clubWHERE2'};
    my $defaultProductID = $params->{'defaultProductID'};
    my $parentBodyFormID = $params->{'parentBodyFormID'};

    my $rfpAdded = ($added) ? 'Added' : '';

    my $rfpWhere = ' AND RFP.intRegoFormID IN (0, ?';

    if ($parentBodyFormID) {
        $rfpWhere .= ', ?';
        push @$queryParams, $parentBodyFormID;
    }

    $rfpWhere .= ')';

    my $sql = qq[
        SELECT DISTINCT 
            P.intProductID,
            P.strName,
            P.intAssocID,
            P.curDefaultAmount,
            P.intMinChangeLevel,
            P.intCreatedLevel,
            P.intPhoto,
            PP.curAmount,
            T.intStatus,
            T.intTransactionID,
            T.curAmount as AmountCharged,
            P.strGroup,
            P.intAllowMultiPurchase,
            P.strProductNotes,
            P.intInactive,
            T.intQty,
            P.intAllowQtys,
            P.intProductGender,
            PP.intPricingType,
            PP.curAmount_Adult1,
            PP.curAmount_Adult2,
            PP.curAmount_Adult3,
            PP.curAmount_AdultPlus,
            PP.curAmount_Child1,
            PP.curAmount_Child2,
            PP.curAmount_Child3,
            PP.curAmount_ChildPlus,
            IF(P.intProductID=$defaultProductID, 1, RFP.intIsMandatory) as intIsMandatory,
            T.intTransactionID,
            dtDateAvailableFrom,
            dtDateAvailableTo,
            RFP.intSequence
        FROM tblProducts as P
            LEFT JOIN tblRegoFormProducts$rfpAdded AS RFP ON RFP.intProductID = P.intProductID
            LEFT JOIN tblProductPricing as PP ON (
                PP.intProductID = P.intProductID
                AND PP.intRealmID = ?
                AND ((PP.intID = ? AND intLevel = $Defs::LEVEL_ASSOC) $clubWHERE)
            )
            LEFT JOIN tblTransactions as T ON (
                T.intID = ?
                AND T.intTableType = ?
                AND T.intProductID = P.intProductID
                AND T.intAssocID = ?
                AND T.intStatus = 0 
            )
        WHERE
            P.intRealmID = ?
            AND (P.intAssocID = ?  OR P.intAssocID=0)
            $clubWHERE2
            AND (P.intMinSellLevel <= ? or P.intMinSellLevel=0)
            AND ((RFP.intAssocID IN (0, ?, ?) $rfpWhere) OR (P.intProductID = $defaultProductID))
        ORDER BY P.strGroup, RFP.intSequence, P.strName, intLevel
    ];

    my $q = $dbh->prepare($sql);
    $q->execute( @$queryParams );

    my $regoProducts = $q->fetchall_hashref('intProductID');

    return $regoProducts;
}

sub checkAllowedProductCount {
    my ($Data, $ID, $tableType, $formID, $params, $assocID, $realmID) = @_;

    my $st = qq[SELECT COUNT(*) AS CountProds FROM tblRegoFormProducts WHERE  intRegoFormID = ?];

    my $qry=$Data->{'db'}->prepare($st);
    $qry->execute($formID);
    my $countProds = $qry->fetchrow_array() || 0;
    return '' if ! $countProds;

    $Data->{'SystemConfig'}{'OnlineRego_productCount'} ||= 0;
    $Data->{'SystemConfig'}{'OnlineRego_minimumProductCount'} ||= 0;
    return if (!$Data->{'SystemConfig'}{'OnlineRego_productCount'} and !$Data->{'SystemConfig'}{'OnlineRego_minimumProductCount'});
    $ID||=0;
    my $AllowedCount = $Data->{'SystemConfig'}{'OnlineRego_productCount'};
    $tableType||=0;

    my $count=0;
    for my $k (keys %{$params})  {
        if($k=~/prod_/) {
            if($params->{$k}==1)    {
                $count++;
             }
        }
        if($k=~/txn_/)  {
            if($params->{$k}>=1)    {
                $count++;
            }
        }
    }
    my $products = '';
    my $resultHTML = '';
    if ($Data->{'SystemConfig'}{'OnlineRego_productCount'}) {
        $products = ($AllowedCount == 1) ? 'item' : 'items';
        $resultHTML = qq[<p>You are only allowed to purchase $AllowedCount $products</p>];
        return $resultHTML if ($count > $AllowedCount);
    }

    my $paidCount = 0;
    if ($Data->{'SystemConfig'}{'OnlineRego_productCountCheckPaid'})        {
        my $st = qq[
            SELECT COUNT(T.intTransactionID)
            FROM tblTransactions as T
                INNER JOIN tblProducts as P ON (P.intProductID = T.intProductID)
                INNER JOIN tblRegoFormProducts AS RFP ON (RFP.intProductID=T.intProductID)
            WHERE 
                T.intID = ? 
                AND T.intTableType = ?
                AND T.intRealmID = ?
                AND T.intAssocID = ?
                AND P.intInactive=0
                AND (
                    RFP.intAssocID IN (0, T.intAssocID)
                    OR RFP.intRegoFormID = ?
                )
                AND P.intProductType NOT IN (2)
        ];
        my $query = $Data->{'db'}->prepare($st);

        $query->execute($ID, $tableType, $realmID || 0, $assocID || 0, $formID,);

        ($paidCount)=$query->fetchrow_array() || 0;

        if ($count)     {
            ## If items ticked for purchase then check total count
            $count += $paidCount;
            $resultHTML = qq[<p>You are only allowed to purchase (or have previously purchased) $AllowedCount $products</p>];
            return $resultHTML if ($count > $AllowedCount and $AllowedCount);
        }
        else    {
            $count = $paidCount;
        }
    }
    my $minimumCount = $Data->{'SystemConfig'}{'OnlineRego_minimumProductCount'} ||= 0;
    return '' if (! $minimumCount);

  $products = ($minimumCount == 1) ? 'item' : 'items';
  $resultHTML = qq[<p>You registration has not been selected because you have no chosen at least $minimumCount $products<br>Your Registration has not been selected because you have not chosen at least one item.
Please click back on your Internet browser to return to the items selection screen and choose at least one item and then click .confirm. again to complete your Registration.</p>];
    return $resultHTML if ($count < $minimumCount);

    return '';

}

sub checkMandatoryProducts      {
    my ($Data, $ID, $tableType, $params) = @_;
    return ('', 0) if (! $Data->{'SystemConfig'}{'AllowOnlineRego_mandatoryCheck'});
    $ID||=0;
    $tableType||=0;

    my @productsselected=();

    my $products_list = '';
    my @trans_list;
    my @products_list;

    my %products_purch = ();
    for my $k (keys %{$params})  {
        if($k=~/prod_/) {
            if($params->{$k}==1)    {
                my $prod=$k;
                $prod=~s/[^\d]//g;
                $products_purch{$prod} = 1;
                push @products_list, $prod;
            }
        }
        if($k=~/txn_/)  {
            if($params->{$k}>=1)    {
                my $txn=$k;
                $txn=~s/[^\d]//g;
                push @trans_list, $txn;
            }
        }
    }
    return ('', 0) if (!scalar(@trans_list) and !scalar(@products_list));

    my $trans_list = join(',', map { '?' } @trans_list );

    my %mandProds = ();
    if ($ID or $trans_list)        {
        $trans_list ||= 0;
        ## LETS GET THE PRODUCTS FOR THE LOGGED IN MEMBER (and any paid ones)
        my $st = qq[
                SELECT T.intProductID
                FROM tblTransactions as T
                    INNER JOIN tblProducts as P ON (P.intProductID=T.intProductID)
                WHERE T.intID = ?
                    AND T.intTableType = ?
                    AND (T.intTransactionID IN($trans_list) or T.intStatus=1)
        ];
                    #AND P.intInactive=0
        my $query = $Data->{'db'}->prepare($st);
        $query->execute($ID, $tableType, @trans_list);

        while (my $dref = $query->fetchrow_hashref())   {
            push @products_list, $dref->{intProductID};
            $products_purch{$dref->{'intProductID'}} = 1;
        }
    }

    $products_list ||= '0';

    my $DependentProducts = ();
    if (scalar @products_list) {
        $DependentProducts = Products::getProductDependencies($Data, @products_list);
    }

    foreach my $dp (keys %{$DependentProducts}) {
        $mandProds{$dp} = 1;# if ($dref->{intMandatoryProductID});
    }

    @products_list = ();
    foreach my $key (keys %mandProds)     {
        next if (! $key or $key ==0 or exists $products_purch{$key});
        push @products_list, $key;

    }
    unless (scalar @products_list) {
        @products_list = ( 0 );
    }

    $products_list = join(',', map { '?' } @products_list );

    my $resultHTML = qq[<p>In order to continue with your online transaction, you must select the following mandatory items</p><br>];

    my $st = qq[
        SELECT strName, strGroup
        FROM tblProducts as P
        WHERE P.intProductID IN ($products_list)
                        AND P.intInactive=0
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute(@products_list);
    my $mand_errors = 0;
    while (my $dref = $query->fetchrow_hashref())   {
        $mand_errors ++;
        $resultHTML .= qq[<p>* $dref->{strName}];
        $resultHTML .= qq[($dref->{strGroup})] if ($dref->{strGroup});
        $resultHTML .= qq[</p>];
    }
    $resultHTML .= qq[<br><p>Please press the <b>back</b> button on your browser</p>];

    return ($resultHTML, 1) if ($mand_errors);
    return ('',0);
}

sub insertRegoTransaction {
    my($Data, $intID, $params, $assocID, $level, $session, $teamID, $clubID, $isTemp)=@_;
    my $db=$Data->{'db'};
    $clubID ||= $Data->{'clientValues'}{'clubID'} || 0;
    $teamID ||= $Data->{'clientValues'}{'teamID'} || 0;
    my $compID ||= $Data->{'clientValues'}{'compID'} || 0;
    my $program_id = $params->{'programID'} || 0;
    $assocID ||= 0;
    $session ||= undef;
    my $multipersonType = $session ? ($session->getNextRegoType())[0] || '' : '';
    my $st = qq[
      SELECT intAllowPayment
      FROM tblAssoc
          WHERE intAssocID = ?
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute( $assocID );
    my $allowPayment = $query->fetchrow_array() || 0;
    $intID ||= 0;

    #Get products selected
    my @productsselected=();
    my @already_in_cart_items=();
    for my $k (%{$params})  {
      if($k=~/prod_/) {
        if($params->{$k}==1)  {
          my $prod=$k;
          $prod=~s/[^\d]//g;
          push @productsselected, $prod;
        }
      }
      if($k=~/txn_/)  {
        if($params->{$k}>=1)  {
          my $txn=$k;
          $txn=~s/[^\d]//g;
          push @already_in_cart_items, $txn;
        }
      }
    }
    my $realmID=$Data->{'Realm'} || 0;
    my $realmSubTypeID=$Data->{'RealmSubType'} || 0;
    #Get Product Prcing
      #my $products_list=join(',',@productsselected);
      #my $already_list=join(',',@already_in_cart_items);
    $clubID=0 if ($clubID == $Defs::INVALID_ID);
    $teamID=0 if ($teamID == $Defs::INVALID_ID);
    $compID=0 if ($compID == $Defs::INVALID_ID);
    my $st_add= qq[
        INSERT INTO tblTransactions (
          intStatus, 
          curAmount, 
          curPerItem, 
          intProductID, 
          intQty, 
          dtTransaction, 
          intID, 
          intTempID,
          intTableType, 
          intAssocID, 
          intRealmID, 
          intRealmSubTypeID, 
          intTXNClubID,
          intTXNTeamID,
          intTXNCompID
        )
        VALUES (?, ?, ?, ?, ?, SYSDATE(), ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ];
  my $q_add= $db->prepare($st_add);
  my @txns_added=();
  my $total_amount = 0;
    if (scalar(@productsselected) or scalar(@already_in_cart_items)) {
    my $st = '';
        if (scalar(@productsselected)) {

            my @query_params;
            my $clubWHERE = '';
            
            if ( $program_id && ($program_id != $Defs::INVALID_ID) ) {
                $clubWHERE = qq[ OR (PP.intID = ? AND intLevel=$Defs::LEVEL_PROGRAM)];
                @query_params = ($realmID, $assocID, $program_id, $realmID, @productsselected);
            }
            elsif ( $clubID and $clubID != $Defs::INVALID_ID ) {
                $clubWHERE
                    = qq[ OR (PP.intID = ? AND intLevel=$Defs::LEVEL_CLUB)];

                @query_params = ($realmID, $assocID, $clubID, $realmID, @productsselected);
            }
            else {
                @query_params = ($realmID, $assocID, $realmID, @productsselected);
            }

            my $products_list = join(',', map { '?' } @productsselected );

     $st=qq[
        SELECT 
          P.intProductID, 
          P.curDefaultAmount, 
          PP.curAmount,
          PP.intPricingType,
          PP.curAmount_Adult1,
          PP.curAmount_Adult2,
          PP.curAmount_Adult3,
          PP.curAmount_AdultPlus,
          PP.curAmount_Child1,
          PP.curAmount_Child2,
          PP.curAmount_Child3,
          PP.curAmount_ChildPlus

        FROM tblProducts AS P 
          LEFT JOIN tblProductPricing as PP ON (
            PP.intProductID = P.intProductID 
                        AND PP.intRealmID = ?
                        AND ((PP.intID = ? AND intLevel = $Defs::LEVEL_ASSOC)
                        $clubWHERE
                        ))
                WHERE P.intRealmID = ?
          AND P.intProductID IN ($products_list)
      ];
        my $query = $Data->{'db'}->prepare($st);
        $query->execute( @query_params );
      while(my $dref=$query->fetchrow_hashref())  {
        my $amount= getCorrectPrice($dref, $multipersonType);
        $total_amount += $amount;
      }
    }
        if (scalar(@already_in_cart_items)){

            my @query_params;
            my $clubWHERE;
            if ( $program_id && ($program_id != $Defs::INVALID_ID) ) {
                $clubWHERE = qq[ OR (PP.intID = ? AND intLevel=$Defs::LEVEL_PROGRAM)];
                @query_params = ($realmID, $assocID, $program_id, @already_in_cart_items);
            }
            elsif ( $clubID and $clubID != $Defs::INVALID_ID ) {
                $clubWHERE
                    = qq[ OR (PP.intID = ? AND intLevel=$Defs::LEVEL_CLUB)];

                @query_params = ($realmID, $assocID, $clubID, @already_in_cart_items);
            }
            else {
                @query_params = ($realmID, $assocID, @already_in_cart_items);
            }

            my $already_list = join(',', map { '?' } @already_in_cart_items );

      $st = qq[
        SELECT 
                    T.intTransactionID, 
                    T.intQty as CurrentQty,
                    T.intProductID,
                    T.curAmount as CurrentAmount,
                P.curDefaultAmount,
                P.intMinChangeLevel,
                P.intCreatedLevel,
                PP.curAmount,
                P.intCreatedID,
                PP.intPricingType,
                PP.curAmount_Adult1,
                PP.curAmount_Adult2,
                PP.curAmount_Adult3,
                PP.curAmount_AdultPlus,
                PP.curAmount_Child1,
                PP.curAmount_Child2,
                PP.curAmount_Child3,
                PP.curAmount_ChildPlus
        FROM 
                    tblTransactions as T
                    INNER JOIN tblProducts as P ON (T.intProductID=P.intProductID)
                    LEFT JOIN tblProductPricing as PP ON (
                        PP.intProductID = P.intProductID
                        AND PP.intRealmID = ?
                        AND ((PP.intID = ? AND intLevel = $Defs::LEVEL_ASSOC)
                        $clubWHERE
                        )
                    )
        WHERE 
                    intTransactionID IN ($already_list)
                ORDER BY PP.intLevel
      ];
      my $query = $Data->{'db'}->prepare($st);
      $query->execute(@query_params);
            my $st_upd = qq[
                UPDATE tblTransactions
                SET intQty = ?, curAmount=?, curPerItem=?
                WHERE intTransactionID=?
                    AND intStatus=0
                    AND intProductID=?
                LIMIT 1
            ];
      my $qry_update = $Data->{'db'}->prepare($st_upd);
            my %product_seen;
      while(my $dref=$query->fetchrow_hashref())  {
                next if $product_seen{$dref->{'intProductID'}};
          my $amount= getCorrectPrice($dref, $multipersonType);
          my $qty = $params->{'txnQTY_'.$dref->{'intTransactionID'}} || $params->{'prodQTY_'.$dref->{'intTransactionID'}} ||  0;
        
#Fix QTY (Prevent bad chars)
    $qty = fix_qty($qty); 
    my $totalamount= $amount * $qty;
                if ($amount != $dref->{'CurrentAmount'} or $qty != $dref->{CurrentQty}) {
              $qry_update->execute($qty, $totalamount, $amount, $dref->{intTransactionID}, $dref->{intProductID});
                }
        $total_amount += $dref->{curAmount};
                $product_seen{$dref->{intProductID}}=1;
      }
    }
  }

    if (scalar(@productsselected)) {

            my @query_params;
            my $clubWHERE = '';
            my $products_list = join(',', map { '?' } @productsselected );

            if ( $program_id && ($program_id != $Defs::INVALID_ID) ) {
                $clubWHERE = qq[ OR (PP.intID = ? AND intLevel=$Defs::LEVEL_PROGRAM)];
                @query_params = ($realmID, $assocID, $program_id, $realmID, @productsselected);
            }
            elsif ( $clubID and $clubID != $Defs::INVALID_ID ) {
                    $clubWHERE
                            = qq[ OR (PP.intID = ? AND intLevel=$Defs::LEVEL_CLUB)];

                    @query_params = ($realmID, $assocID, $clubID, $realmID, @productsselected);
            }
            else {
                    @query_params = ($realmID, $assocID, $realmID, @productsselected);
            }

    my $st=qq[
      SELECT 
        P.intProductID, 
        P.strName, 
        P.intAssocID, 
        P.curDefaultAmount, 
        P.intMinChangeLevel, 
        P.intCreatedLevel, 
        PP.curAmount, 
        P.intCreatedID,
        PP.intPricingType,
        PP.curAmount_Adult1,
        PP.curAmount_Adult2,
        PP.curAmount_Adult3,
        PP.curAmount_AdultPlus,
        PP.curAmount_Child1,
        PP.curAmount_Child2,
        PP.curAmount_Child3,
        PP.curAmount_ChildPlus
    FROM tblProducts as P 
        LEFT JOIN tblProductPricing as PP ON (
          PP.intProductID = P.intProductID 
                    AND PP.intRealmID = ?
                    AND ((PP.intID = ? AND intLevel = $Defs::LEVEL_ASSOC)
                    $clubWHERE
                    )
                )
            WHERE P.intRealmID = ?
        AND P.intProductID IN ($products_list)
        ORDER BY PP.intLevel
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute(@query_params);
            my %product_seen;
    while(my $dref=$query->fetchrow_hashref())  {
        next if $product_seen{$dref->{'intProductID'}}++;
      my $amount= getCorrectPrice($dref, $multipersonType);
      my $status = ($allowPayment and ($total_amount eq '0.00' or $total_amount == 0)) ? 1: 0;
      $status = 0 if $Data->{'SystemConfig'}{'RegoForm_DontPayZero'};
      my $qty = $params->{'txnQTY_'.$dref->{'intProductID'}} || $params->{'prodQTY_'.$dref->{'intProductID'}} || 1;
     #Fix QTY (Prevent bad chars)
        $qty = fix_qty($qty);
    # how about setting intID (RealID) = -2 so we can track these sort of tranaction later??
    my $intRealID = $isTemp? 0 : $intID;
    my $intTempID = $isTemp? $intID : 0;
my $totalamount= $amount * $qty;


    if ( $Data->{'SystemConfig'}{'rego_txn_commit_with_entity'} ){
        
        my $entity_type_id = -1;
        my $entity_id = -1;
        
        if ( $program_id && ($program_id != $Defs::INVALID_ID) ) {
            $entity_type_id = $Defs::LEVEL_PROGRAM;
            $entity_id = $program_id;
        }
        elsif ( $clubID && $clubID != $Defs::INVALID_ID) {
            $entity_type_id = $Defs::LEVEL_CLUB;
            $entity_id = $clubID;
        }
        else{
            # Should be assoc?
            $entity_type_id = $Defs::LEVEL_ASSOC;
            $entity_id = $assocID;
        }

        my $transaction_add_sql = qq[
            INSERT INTO tblTransactions (
              intStatus, 
              curAmount, 
              curPerItem, 
              intProductID, 
              intQty, 
              dtTransaction, 
              intID, 
              intTempID,
              intTableType, 
              intAssocID, 
              intRealmID, 
              intRealmSubTypeID, 
              intTXNClubID,
              intTXNTeamID,
              intTXNCompID,
              intTXNEntityTypeID,
              intTXNEntityID
            )
            VALUES (?, ?, ?, ?, ?, SYSDATE(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ];
        $q_add = $db->prepare($transaction_add_sql);

        $q_add->execute(
            $status,
            $totalamount,
            $amount,
            $dref->{'intProductID'},
            $qty,
            $intRealID,
            $intTempID,
            $level,
            $assocID,
            $realmID,
            $realmSubTypeID,
            $clubID,
            $teamID,
            $compID,
            $entity_type_id,
            $entity_id,
        );
    }
    else {
        $q_add->execute(
            $status,
            $totalamount,
            $amount,
            $dref->{'intProductID'},
            $qty,
            $intRealID,
            $intTempID,
            $level,
            $assocID,
            $realmID,
            $realmSubTypeID,
            $clubID,
            $teamID,
            $compID
        );
    }
            
      my $tx_ID=$q_add->{mysql_insertid} || 0;
      if ($allowPayment and $status and ($total_amount == 0 or $total_amount eq '0.00'))  {
        my $regoFormID = $Data->{'RegoFormID'} || 0;
        $st = qq[
          INSERT INTO tblTransLog
          (dtLog, intAmount, intRealmID, intStatus, intPaymentType, intRegoFormID)
          VALUES (NOW(), 0, ?, 1, 0, ?)
        ];
        my $qry=$Data->{'db'}->prepare($st);
        $qry->execute( $Data->{'Realm'}, $regoFormID );
        my $transLogID = $qry->{'mysql_insertid'};

        $st = qq[
          INSERT INTO tblTXNLogs
          (intTXNID, intTLogID)
          VALUES (?, ?)
        ];
        $qry=$Data->{'db'}->prepare($st);
        $qry->execute( $tx_ID, $transLogID );
        $st = qq[
          UPDATE tblTransactions
            SET intTransLogID = ?, intStatus = $Defs::TXN_PAID, dtPaid=NOW()
          WHERE intTransactionID = ?
        ];
        $qry=$Data->{'db'}->prepare($st);
        $qry->execute( $transLogID, $tx_ID );
                Products::product_apply_transaction($Data,$transLogID);
      }
      push @txns_added, $tx_ID if $tx_ID;
    }
  }
  push @txns_added, @already_in_cart_items;
  return \@txns_added || [];
}

sub fix_qty {
    my ($qty) = @_;
    $qty = int($qty);
    #Ensuring reasonable value
    $qty=1 if($qty<=0 or $qty>5000);
    return $qty;
}


sub assoctime   {
    my ($db, $assocID, $datestring) = @_;

    my $timezone = '';
    if($assocID)    {
        my $st = qq[
            SELECT
                strTimeZone
            FROM tblAssoc
            WHERE intAssocID = ?
        ];
        my $q=$db->prepare($st);
        $q->execute($assocID);
        ($timezone) = $q->fetchrow_array();
        $q->finish();
    }
    my $time = timeatAssoc(
        $timezone || '', 
        $datestring || ''
    );
    return $time;
}   

sub productAllowedThroughFilter {
    my ($dref, $memdetails, $assoctime, $productAttributes, $params) = @_;

    # Returns 1 if product passes filters
    # else 0 means product doesn't pass
    $dref->{strProductNotes}=~s/\n/<br>/g;

    if($dref->{'dtDateAvailableFrom'} and $dref->{'dtDateAvailableFrom'}ne '0000-00-00 00:00:00')   {
        return 0 if $dref->{'dtDateAvailableFrom'} gt $assoctime;
    }

    if($dref->{'dtDateAvailableTo'} and $dref->{'dtDateAvailableTo'} ne '0000-00-00 00:00:00')  {
        return 0 if $dref->{'dtDateAvailableTo'} lt $assoctime;
    }

    if ($memdetails) {

        if ( $memdetails->{'Gender'} and $dref->{'intProductGender'} ) {
            return 0 if $dref->{'intProductGender'} != $memdetails->{'Gender'};
        }

        if ( $productAttributes->{ $dref->{'intProductID'} } ) {

            if ( $memdetails->{'DOB'} and $productAttributes->{$dref->{'intProductID'}} ) {

                my $dt_DOB = $memdetails->{'DOB'};
                $dt_DOB =~ s#-#/#g;
                my($d,$m,$y) = split('/',$dt_DOB);
                $m ||= 0;
                $d ||= 0;
                $y ||= 0;
                $d='0'.$d if length($d) ==1;
                $m='0'.$m if length($m) ==1;
                my $dob = "$y-$m-$d";

                if($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MAX}
                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MAX}[0] ne 'NULL' ) {
                    return 0 if ($dob gt $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MAX}[0]);
                }

                if($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MIN}
                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MIN}[0] ne 'NULL' ) {
                    return 0 if ($dob lt $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MIN}[0]);
                }

                if ( $y and $m and $d ) {
                    my ( $today_year, $today_month, $today_day ) = Today();
                    my ( $age_year, $age_month, $age_day ) = Delta_YMD( $y, $m, $d, $today_year, $today_month, $today_day );

                    if( $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MAX}
	                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MAX}[0] ne 'NULL' ) {
	                    return 0 if ( $age_year >= $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MAX}[0] );
	                }

	                if( $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MIN}
	                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MIN}[0] ne 'NULL' ) {
	                    return 0 if ( $age_year < $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MIN}[0] );
	                }
                }
		    }

            if($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_MEMBER_TYPES} ) {
                my $found = 0;
                for my $i (@{$productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_MEMBER_TYPES}}) {

                    $found = 1 if($i == $Defs::MEMBER_TYPE_PLAYER and $params->{'ynPlayer'});
                    $found = 1 if($i == $Defs::MEMBER_TYPE_COACH and $params->{'ynCoach'});
                    $found = 1 if($i == $Defs::MEMBER_TYPE_UMPIRE and $params->{'ynMatchOfficial'});
                    $found = 1 if($i == $Defs::MEMBER_TYPE_OFFICIAL and $params->{'ynOfficial'});
                    $found = 1 if($i == $Defs::MEMBER_TYPE_MISC and $params->{'ynMisc'});
                    $found = 1 if($i == $Defs::MEMBER_TYPE_VOLUNTEER and $params->{'ynVolunteer'});
                }
                return 0 if !$found;
            }

            if ($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_PROGRAM_NEW}
                and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_PROGRAM_NEW}[0] ne 'NULL' ) {
                return 0 if ($params->{'program_new'} != $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_PROGRAM_NEW}[0]);
            }
            
            if ($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_PROGRAM_RETURNING}
                and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_PROGRAM_RETURNING}[0] ne 'NULL' ) {
                return 0 if ($params->{'program_returning'} != $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_PROGRAM_RETURNING}[0]);
            }
        }
    }

    return 1;
}
1;
