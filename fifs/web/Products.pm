#
# $Header: svn://svn/SWM/trunk/web/Products.pm 11295 2014-04-14 04:46:56Z mstarcevic $
#

package Products;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getProducts handle_products get_product get_product_list product_apply_transaction getProductDependencies getFormProductAttributes updateProductTXNPricing checkProductClubSplit getItemCost getCorrectPrice);
@EXPORT_OK = qw(getProducts handle_products get_product get_product_list product_apply_transaction getProductDependencies getFormProductAttributes updateProductTXNPricing checkProductClubSplit getItemCost getCorrectPrice);

use strict;
use lib  '.', '..';#, "..", ".";
use Defs;
use Reg_common;
use CGI qw(escape unescape param radio_group popup_menu);
use DeQuote;
use FormHelpers;
use HTMLForm qw(_date_selection_picker _date_selection_dropdown _time_selection_box generate_clientside_validation);
use MemberPackages;
use AuditLog;
use Utils;
use MemberFunctions;
use GridDisplay;
use ProductPhoto;

require InstanceOf;
require Seasons;
require PaymentApplication;
require AgeGroups;


sub getCorrectPrice {
    my($dref, $multipersonType) = @_;
    $multipersonType=~s/\s//g;
    my $amount= 0 ;
    $multipersonType ||= '';
    $dref->{'curAmount'} ||= 0;
    $dref->{'intPricingType'} ||= 0;
    $dref->{'curAmount_'.$multipersonType} ||= 0;
    $dref->{'curAmount_'.$multipersonType} = 0 if $dref->{'curAmount_'.$multipersonType} eq '0.00';
    $dref->{'curAmount'} = 0 if $dref->{'curAmount'} eq '0.00';
    $dref->{'curDefaultAmount'} = 0 if $dref->{'curDefaultAmount'} eq '0.00';
    if($dref->{'intPricingType'} == 1 and $multipersonType)  {
      $amount = $dref->{'curAmount_'.$multipersonType} || 0;
    }
    else  {
      $amount = $dref->{'curAmount'} || $dref->{'curDefaultAmount'} || 0;
    }
    return $amount;
}

sub getItemCost {

    my ($Data, $entityID, $entityLevel, $multipersonType, $productID) = @_;

     my $st=qq[
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
        FROM tblProducts as P
            LEFT JOIN tblProductPricing as PP ON (
                PP.intProductID = P.intProductID
                AND PP.intRealmID = ?
                AND (
                    (PP.intID = ? AND intLevel = ?)
                    OR
                    (intLevel = $Defs::LEVEL_NATIONAL)
                )
            )
        WHERE
            P.intRealmID = ?
            AND P.intProductID = ?
        ORDER BY PP.intLevel ASC
        LIMIT 1
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($Data->{'Realm'}, $entityID, $entityLevel, $Data->{'Realm'}, $productID);
    my $dref=$query->fetchrow_hashref();
    my $amount= getCorrectPrice($dref, $multipersonType);
    return $amount;
}

sub checkProductClubSplit   {

    my ($Data, $productID)=@_;

    my $st = qq[
        SELECT
            COUNT(intSplitID) as NumSplits
        FROM
            tblProducts as P
            INNER JOIN tblPaymentSplitItem as PS ON (
                PS.intSplitID=P.intPaymentSplitID
            )
        WHERE
            PS.intLevelID=3
            AND P.intProductID=?
            AND P.intPaymentSplitID>0
    ];
    my $query = $Data->{'db'}->prepare($st) or query_error($st);
    $query->execute($productID) or query_error($st);
    
    my $countProdSplits = $query->fetchrow_array() || 0;

	return $countProdSplits;

}

sub getProducts	{
	my($Data, $allowInactive)=@_;

	$allowInactive ||= 0;

	my $realmID=$Data->{'Realm'} || 0;
    my $entityTypeID = $Data->{'clientValues'}{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);
	my $authLevel = $Data->{'clientValues'}{'authLevel'}||=$Defs::INVALID_ID;
	my $clubID=$Data->{'clientValues'}{'clubID'} || $Defs::INVALID_ID;
	$clubID ||= 0;

	my $WHEREClub = '';
	if ($clubID) { 	#and $authLevel == $Defs::LEVEL_CLUB)	{
		$WHEREClub = qq[
			AND ((intCreatedLevel = 0 or intCreatedLevel > 3) or (intCreatedLevel = $Defs::LEVEL_CLUB and intCreatedID = $clubID))
		];
	}

	my $inactive = $allowInactive ? '' : qq[ AND intInactive = 0];
	my $st=qq[
		SELECT intProductID, strName, strGroup
		FROM tblProducts
		WHERE intRealmID=$realmID	
			AND (intEntityID IN ($entityID, 0)
			AND intProductType NOT IN ($Defs::PROD_TYPE_MINFEE)
            AND intProductSubRealmID IN (0, $Data->{'RealmSubType'})
			$inactive
			$WHEREClub
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
	my $body='';
	my %Products=();
	while (my ($id,$name, $group)=$query->fetchrow_array())	{
		$name = qq[$group - $name] if $group;
		$Products{$id}=$name||'';
	}
	return \%Products;
}

sub handle_products {
	my($Data, $action)=@_;

	my $id=param('lki') || 0;
	
	my $body='';
	my $title = "Products";
	my $breadcrumbs = '';
	
	if($action eq 'PR_U')	{
		($body, $id) =update_products($Data, $id);
		$action = 'PR_E' if $id;
	}
	elsif($action eq 'PR_C')	{
		($body, $title) = copy_product($Data, $id);
		$action = 'PR_L';
	}
	if($action eq 'PR_E')	{
		my $tbody = '';
		($tbody, $title, $breadcrumbs)=detail_products($Data,$id);
		$body .= $tbody;
	}
	else	{
		$body.=list_products($Data);
	}
	$title ||= "Products";
	return ($body,$title, $breadcrumbs);
}


sub list_products	{
	my($Data) = @_;
	my $realmID = $Data->{'Realm'} || 0;
    my $target = $Data->{'target'};
    my $client = setClient($Data->{'clientValues'});
    
    my $current_level = $Data->{'clientValues'}{'currentLevel'};
    
    my $entityTypeID = $Data->{'clientValues'}{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

    my $output = new CGI;
    my $view_products_status = $output->cookie("SWOMPRODREC") || '';
    my $current_group = $output->cookie("SWOMGROUP") || '';
 my $statuscookie=qq[
                jQuery("#id_filterstatus").change(function() {
                    SetCookie('SWOMPRODREC',jQuery('#id_filterstatus').val(),30);
                });
            ];
            $Data->{'AddToPage'}->add('js_bottom','inline',$statuscookie);


 my $groupcookie=qq[
                jQuery("#id_filtergroup").change(function() {
                    SetCookie('SWOMGROUP',jQuery('#id_filtergroup').val(),30);
                });
            ];
            $Data->{'AddToPage'}->add('js_bottom','inline',$groupcookie);


	my $st=qq[
		SELECT  
			P.intProductID, 
			P.strName, 
			P.intEntityID, 
			P.curDefaultAmount, 
			P.intMinChangeLevel, 
			P.intMinSellLevel, 
			P.intCreatedLevel, 
			P.intCreatedID, 
			PP.curAmount, 
			PP.intPricingType,
			PP.curAmount_Adult1,
			PP.curAmount_Adult2,
			PP.curAmount_Adult3,
			PP.curAmount_AdultPlus,
			PP.curAmount_Child1,
			PP.curAmount_Child2,
			PP.curAmount_Child3,
			PP.curAmount_ChildPlus,
			P.strGroup, 
			P.intInactive, 
			IF((P.intCreatedLevel = $Defs::LEVEL_CLUB), 
				CONCAT(C.strName, ' (CLUB)'), 
					IF(P.intEntityID=0, 'National','')
			) as CreatedName
		FROM 
			tblProducts as P 
			LEFT JOIN tblProductPricing as PP 
				ON (
					PP.intProductID = P.intProductID 
						AND intID = $entityID 
						AND intLevel = $current_level 
						AND PP.intRealmID = $realmID
				)
			LEFT JOIN tblClub as C 
				ON (C.intClubID = P.intCreatedID and P.intCreatedLevel=$Defs::LEVEL_CLUB)
		WHERE 
			P.intRealmID= $realmID
			AND P.intProductType NOT IN ($Defs::PROD_TYPE_MINFEE)
			AND P.intEntityID IN (0, $entityID)
            AND P.intProductSubRealmID IN (0, $Data->{'RealmSubType'})
            AND (
                (P.intCreatedLevel = 0) 
                OR (
                    P.intCreatedLevel = $current_level 
                    AND P.intCreatedID = $entityID
                ) 
                OR P.intCreatedLevel > $current_level
            )
		    ORDER BY 
			    P.strGroup, 
			    P.strName
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
	my $body = '';
	my $i = 0;
	my $strGroup = '';
  my %GroupNames = ();
	my @rowdata=();
	while (my $dref = $query->fetchrow_hashref())	{
        $GroupNames{$dref->{'strGroup'}} += 1;
		my $link = qq[$target?client=$client&amp;lki=$dref->{'intProductID'}&amp;a=PR_E];
		$link = '' if $Data->{'ReadOnlyLogin'};
		
        if ($current_level != $dref->{'intCreatedLevel'} or $dref->{'intCreatedID'} != $entityID) {
            $link = 'Locked' if $dref->{intMinChangeLevel} > $current_level;
            $link = 'Locked' if $dref->{intMinSellLevel} > $current_level;
        }
        my $copy_link = 'Not created at this level';
        if ($current_level == $dref->{'intCreatedLevel'}) { 
            $copy_link = qq[<a href="$target?client=$client&amp;lki=$dref->{'intProductID'}&amp;a=PR_C" onclick="return confirm('Are you sure you want to make a copy of product &quot;$dref->{strName}&quot;?');">Copy</a>];
        }
		my $active = ! $dref->{intInactive} || 0;
		my $shade=$i%2==0? 'class="rowshade" ' : '';
		$i++;
		my $amount=currency($dref->{'curAmount'}||$dref->{'curDefaultAmount'} || 0);

		   push @rowdata, {
      id => $dref->{'intProductID'} || next,
      strGroup => $dref->{'strGroup'},
      strName => $dref->{'strName'},
      amount => $amount,
      active => $active,
      CreatedName=> $dref->{'CreatedName'},
      CopyLink => $copy_link,
      SelectLink =>$link,
    };

	}

 my $list_instruction= $Data->{'SystemConfig'}{"ListInstruction_$Defs::LEVEL_CLUB"}
    ? qq[<div class="listinstruction">$Data->{'SystemConfig'}{"ListInstruction_$Defs::LEVEL_CLUB"}</div>]
    : '';

 		my @headers = (
    	{
      	type => 'Selector',
      	field => 'SelectLink',
    	},
    	{
      	name =>   $Data->{'lang'}->txt('Group'),
      	field =>  'strGroup',
    	},
    	{
      	name =>   $Data->{'lang'}->txt('Name'),
      	field =>  'strName',
    	},
    	{
      	name =>   $Data->{'lang'}->txt('Price'),
      	field =>  'amount',
    	},
    	{
    	  name =>   $Data->{'lang'}->txt('Active ?'),
    	  field =>  'active',
				type => 'tick',
    	},
    	{
    	  name =>   $Data->{'lang'}->txt('Created By'),
    	  field =>  'CreatedName',
    	},
    	{
    	  name =>   $Data->{'lang'}->txt('Copy Product'),
    	  field =>  'CopyLink',
				type=>'HTML',
    	},
  	);

 my $filterfields = [
    {
      field => 'active',
      elementID => 'id_filterstatus',
      allvalue => '2',
    },
    {
      field => 'strGroup',
      elementID => 'id_filtergroup',
    },
  ];

	 my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    filters => $filterfields,
    gridid => 'grid',
    width => '98%',
    height => 700,
		groupby => 'strGroup',
		groupby_collection_name => 'products',
  );

  $body = qq[
    $grid
  ];

	my $allowadds = 1;
	my $addlink = qq[<span class = "button-small generic-button"><a href="$target?client=$client&amp;a=PR_E">Add</a></span></a>];

	$addlink = '' if !$allowadds;
    my $group_ddl = '';
    foreach my $group (sort (keys %GroupNames)) {
      my $selected = ($current_group eq $group) ? 'SELECTED' : '';
      $group_ddl .= qq[<option $selected>$group</option>];
    }
	my $checked_active= $Data->{'ViewProductStatus'} == 1 ? ' selected ' : '';
    my $checked_inactive= $Data->{'ViewProductStatus'} == 0 ? ' selected ' : '';
    my $checked_all = $Data->{'ViewProductStatus'} == 2 ? ' selected ' : '';
    my $line = qq[
        <div class="showrecoptions">
        <script language="JavaScript1.2" type="text/javascript" src="js/jscookie.js"></script>
        <form action="#" onsubmit="return false;" name="recoptions">
          Showing
          <select id="id_filterstatus" name="actstatus" size="1" style="font-size:10px;">
            <option $checked_active value="1">Active</option>
            <option $checked_inactive value="0">Inactive (Archived)</option>
            <option $checked_all value="2">All</option>
          </select> 
          records for Group 
          <select id="id_filtergroup" name="actgroup" size="1" style="font-size:10px;">
            <option value=''>All</option>
            $group_ddl
          </select>
        </form>
        </div>
  ];
	$body = qq[
		<p>Choose a value from the list below to edit. Some options may be locked by your national/international body and cannot be edited. $addlink</p>
    $list_instruction
		<div class = "grid-filter-wrap">
			$line
			$body
		</div>
		<p>$addlink</p>
	];
	return $body;
}


sub detail_products  {
    my($Data, $id)=@_;

    my $cl  = setClient($Data->{'clientValues'});
    my $unesc_cl = unescape($cl);
    
    my $current_level = $Data->{'clientValues'}{'currentLevel'};
    my $original_level = $current_level;
    
	my $authLevel = $Data->{'clientValues'}{'authLevel'};

    my $entityTypeID = $Data->{'clientValues'}{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);
	my $l = $Data->{'lang'};

    my $dref = get_product($Data,$id);
	my $name=$dref->{'strName'} || '';
    my $hasPhoto = $dref->{'intPhoto'}||0;
    my $amount = currency($dref->{'curAmount'} || $dref->{'curDefaultAmount'} || $dref->{'curAmount_Adult1'} || 0);
		my $currency_symbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";
    my $compulsory=qq[<img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/>];
    #$body = qq[<p>Enter the name of the product in the box provided and its default cost, then press the Update button.</p>
		my $fulledit = (
			$id == 0 
			or ($current_level == $dref->{intCreatedLevel} and $dref->{'intCreatedID'} == $entityID) 
			or ($current_level == $Defs::LEVEL_NATIONAL)
		) ? 1 : 0;

	my $hasSplits=0;
	if ($dref->{intEntityID} or $id == 0) {
		my $paymentSplitSettings = PaymentSplitUtils::getPaymentSplitSettings($Data);
        if ($paymentSplitSettings->{'psProds'}) {
            my $paymentSplits = PaymentSplitObj->getList($entityID, $entityID, $Data->{'db'});
            for my $paymentSplit(@{$paymentSplits}) {
				$hasSplits++;
            }
		}
	}
	
	my %validation;
    
    $validation{'name'} = {
        'compulsory' => 1,
    };
    
    $validation{'strGSTText'} = {
        'compulsory' => 1,
    };
			


		my $pricinginfo = '';
    my $body = qq[ <p>Fields marked with $compulsory are compulsory.</p> <br>] ;

    my $links_list = '';

    if ($current_level != $dref->{intCreatedLevel} and $entityID!= $dref->{'intCreatedID'} and $dref->{intProductID}) {
        $body .= qq[<p><b>You do not have permission to modify all the information relating to this product.</b></p>];
    }
    else {
        $links_list = qq[
            <ul>
                <li><a href = "#prod-details">Details</a></li>
                <li><a href = "#prod-pricing">Pricing</a></li>
                <li><a href = "#prod-mandatory">Mandatory</a></li>
                <li><a href = "#prod-actions">Actions</a></li>
                <li><a href = "#prod-filter">Filter</a></li>
                <li><a href = "#prod-available">Availability</a></li>
                <li><a href = "#prod-renew">Renewal</a></li>
            </ul>
        ];
    }
    

my $warning_note = $Data->{'SystemConfig'}{'ProductEditNote'} || '';

    $body .= qq[$warning_note
                <form action="$Data->{'target'}" name='product_form' id='product_formID' method="post">
								<div id ="prodtabs" style="float:left;width:98%;">
                                    $links_list
								<div id="prod-details" class="prodtabletab">
                <div class="sectionheader">Details</div>
								<table>
                ];

#'

    my $multiPurchase = $dref->{intAllowMultiPurchase} ? 'checked' : '';
    my $allowQtys= $dref->{intAllowQtys} ? 'checked' : '';
    my $inactive= $dref->{intInactive} ? 'checked' : '';
#    $Defs::page_title = $name ? "SWM - Update Product - $name" : 'SWM - Add Product';
    if ($fulledit)	{
	my ($Seasons, undef) =Seasons::getSeasons($Data);	
	
        $body .= qq[
                    <tr>
                    <td class="label"><label for="$name">Name: </label></td>
                    <td class="data"><input type="text" name="name" value="$name" size="40" maxlength="50">$compulsory</td>
                    </tr>
                    <tr>
                    <td class="label"><label for="intProductSeasonID">Product Reporting Season: </label></td>
					<td class="data">].drop_down('intProductSeasonID',$Seasons,undef,$dref->{'intProductSeasonID'},1,0).qq[&nbsp;&nbsp;<span class="formfieldinfo">(Used in Reporting as a filter for Products purchased)</span></td>
                    </tr>

	];
	my $selected='';


	$body .= qq[ <tr>
                    <td class="label"><label for="intInactive">Archive Product: </label></td>
                    <td class="data"><input type="checkbox" name="intInactive" $inactive value="1"></td>
                    </tr>
                    <tr>
                    <td class="label"><label for="strGroup">Grouping Category: </label></td>
                    <td class="data"><input type="text" name="strGroup" value="$dref->{strGroup}" size="40" ></td>
                    </tr>
                    <tr>
                    <td class="label"><label for="intAllowMultiPurchase">Allow Multiple time purchasing: </label></td>
                    <td class="data"><input type="checkbox" name="intAllowMultiPurchase" $multiPurchase value="1"> <span class="formfieldinfo">Allows this product to be purchased several times (eg in Feb &amp; July)</span></td>
                    <td class="extra" rowspan="2" class="formfieldinfo"><div style="padding:4px;border:1px solid silver">Note: this does not relate to registering multiple people. <br/>Allow Multiple Adult/Children is configured in the Registration Form setup.</td> 
                    </tr>
                    <tr>
                    <td class="label"><label for="intAllowQtys">Allow Multiple Quantity Purchasing: </label></td>
                    <td class="data"><input type="checkbox" name="intAllowQtys" $allowQtys value="1"><span class="formfieldinfo"> Allows this product to be purchased in multiples (eg 2 x socks)</span></td>
                    </tr>
		];
		$pricinginfo .=qq[
                    <tr>
											<td class="label"><label for="strGSTText">Tax Description: </label>$compulsory</td>
											<td class="data"><input type="text" name="strGSTText" value="$dref->{strGSTText}" size="40" ></td>
                    </tr>
		];
	
	my $minChangeLevel = qq[ <select name="intMinChangeLevel"> ];
	$selected = '';

	$selected = (! $dref->{intMinChangeLevel}) ? "SELECTED" : '';
	$minChangeLevel .= qq[ <option value="0" $selected>--Select Level--</option>];
	
	$selected = ($dref->{intMinChangeLevel} == $Defs::LEVEL_CLUB) ? "SELECTED" : '';
	$minChangeLevel .= qq[ <option value="$Defs::LEVEL_CLUB" $selected>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</option>];

	if ($dref->{intEntityID} == 0)	{
		$selected = ($dref->{intMinChangeLevel} == $Defs::LEVEL_NATIONAL) ? "SELECTED" : '';
		$minChangeLevel .= qq[ <option value="$Defs::LEVEL_NATIONAL" $selected>$Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL}</option>];
	}
	$minChangeLevel .= qq[</select>];
	$pricinginfo.= qq[
                    <tr>
                    <td class="label"><label for="intAllowQtys">Minimum System Login to change price: </label></td>
                    <td class="data">$minChangeLevel</td>
                    </tr>
	];

	my $minSellLevel = qq[ <select name="intMinSellLevel"> ];
	$selected = '';

	$selected = (! $dref->{intMinSellLevel}) ? "SELECTED" : '';
	$minSellLevel .= qq[ <option value="0" $selected>--Select Level--</option>];
	
	$selected = ($dref->{intMinSellLevel} == $Defs::LEVEL_CLUB) ? "SELECTED" : '';
	$minSellLevel .= qq[ <option value="$Defs::LEVEL_CLUB" $selected>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</option>];

	$selected = ($dref->{intMinSellLevel} == $Defs::LEVEL_ASSOC) ? "SELECTED" : '';
	$minSellLevel .= qq[ <option value="$Defs::LEVEL_ASSOC" $selected>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}</option>];

	$minSellLevel .= qq[</select>];
	$pricinginfo.= qq[
                    <tr>
                    <td class="label"><label for="intAllowQtys">Minimum System Login to Sell Product: </label></td>
                    <td class="data">$minSellLevel</td>
                    </tr>
	];


	$body .= qq[
                    <tr>
                    <td class="label"><label for="strProductNotes">Notes: </label>
                    <td class="data"><textarea name="strProductNotes" rows = "5"   cols = "45"  >$dref->{strProductNotes}</textarea></td>
										<td><span class="formfieldinfo">(Add any information here that purchasers should see before they complete their transaction)</span></td>
                    </tr>
                    ];
 	my $client = unescape($cl);
	my $hideWebCamTab ='';
    # this will disbale photo upload untill all the otehr necessary elements are in place
    my $allow_photo_upload = 0;
    if($allow_photo_upload) {
 
	my $photolink = '';
	# only let upload photo if it's not a new product without ID
        if($id) {
		my $hash = authstring($id);
		my $pa = $id.'f'.$hash;
                $photolink =qq[<img src ="getProductPhoto.cgi?pa=$pa&pID=$id&client=$client">];
        
		my $pID = "&pID=$id;";
		my $photo =  q[
                                        <div id="photoupload_result">].$photolink.q[</div>
                                        <div id="photoupload_form"></div>
                                        <input type="button" value = " Upload Photo " id = "photoupload" class="button generic-button">
                                        <input type="hidden" name = "d_PhotoUpload" value = "].($photolink ? 'valid' : '').q[">
                                        <script>
                                        jQuery('#photoupload').click(function() {
                                                        jQuery('#photoupload_form').html('<iframe src="productphoto.cgi?client=].$client.$pID.$hideWebCamTab.q[" style="width:750px;height:650px;border:0px;"></iframe>');
                                                        jQuery('#photoupload_form').dialog({
                                                                        width: 800,
                                                                        height: 700,
                                                                        modal: true,
                                                                        title: 'Upload Photo'
                                                        });
                                        });
                                        </script>
                                ];
		$body .= qq[
                    <tr>
                    <td class="label"><label>Photo:</label></td>
                    <td class="">$photo</td>:
		    <td></td>
                    </tr>
                    ];
	}
}

}
    else  {
#        $Defs::page_title = "SWM - Update Product: $name";

        $body .= qq[
                    <tr>
                    <td class="label">Name: </td>
                    <td class="data">$name<input type="hidden" name="strGSTText" value="invalid"type="hidden"></td>
                    </tr>
                    <input type="hidden" name="name" type="hidden" value="$name"></td>
                    </tr>
                    <tr>
                    <td class="label">Group: </td>
                    <td class="data">$dref->{strGroup}</td>
                    </tr>
                    ];

    }
		my $lang = $Data->{'lang'};
		my %txt = (
			firstadult => $lang->txt('First Adult'),
			secondadult => $lang->txt('Second Adult'),
			thirdadult => $lang->txt('Third Adult'),
			plusadult => $lang->txt('Subsequent Adult'),

			firstchild => $lang->txt('First Child'),
			secondchild => $lang->txt('Second Child'),
			thirdchild => $lang->txt('Third Child'),
			pluschild => $lang->txt('Subsequent Child'),
		);
		my %amounts = ();
		my @nums = (qw( 1 2 3 Plus));
		for my $i (0 .. $#nums)	{
			for my $j (qw( Adult Child ))	{
				my $k = "curAmount_$j".$nums[$i];
				my $prev_amount = ($i == 0)
					? $amount
					: $amounts{"curAmount_$j".$nums[$i-1]};
				#$dref->{$k} = '' if $dref->{$k} eq '0.00';
				$amounts{$k} = currency($dref->{$k} || $prev_amount || 0);
			}
		}
		
		foreach my $field (qw/ curAmountMin  curAmountMax /){
		    $amounts{$field} = currency($dref->{$field} || $amount || 0);
		}
		
		my $single_active = '';
		my $ranged_active = '';
		my $multi_active = '';
		my $single_block_active = '';
		my $ranged_block_active = '';
		my $multi_block_active = '';
		
		if( $dref->{'intPricingType'} == $Defs::PRICING_TYPE_MULTI)	{
			$multi_active = ' CHECKED ';
		}
		elsif( $dref->{'intPricingType'} == $Defs::PRICING_TYPE_RANGED) {
		    $ranged_active = ' CHECKED ';
		}
		else {
			$single_active = ' CHECKED ';
			$dref->{'intPricingType'} = $Defs::PRICING_TYPE_SINGLE;
		}
		
		my $allow_ranged_price = 0;
		my $allow_multi_price  = ! $Data->{'SystemConfig'}{'HideMultiPricing'};
		
		if (defined $Data->{'SystemConfig'}{'AllowRangedProductAddLevel'} 
            && $current_level >= $Data->{'SystemConfig'}{'AllowRangedProductAddLevel'} ){
            
            if ($id && $dref->{'intCreatedLevel'} >= $current_level ){
                # Are from the same level or above
                $allow_ranged_price = 1;
            }
            elsif ( $id == 0 ){
                # New product, let them use it
                $allow_ranged_price = 1;
            }
                
        }
        
        my $single_placeholder = '';
        my $single_size = 6;
        
        # Is this a ranged product that we are not allowed to edit the range of?
        if ( !$allow_ranged_price && $dref->{'intOriginalPricingType'} == $Defs::PRICING_TYPE_RANGED) {
            $validation{'amount'} = {
                'compulsory' => 1,
                'validate' => 'BETWEEN:' . $amounts{'curAmountMin'} . '-' . $amounts{'curAmountMax'},
            };
            $allow_multi_price = 0;
            $single_active = ' CHECKED ';
            $single_placeholder = ' placeholder="' . $currency_symbol . $amounts{'curAmountMin'} . ' to ' . $currency_symbol . $amounts{'curAmountMax'} . '" ';
            $single_size = 18;
            $dref->{'intPricingType'} = $Defs::PRICING_TYPE_SINGLE;
        }
		
        $body .= qq[
    					</table>
    				</div>
    				<div id="prod-pricing" class="prodtabletab">
    				<div class="sectionheader">Pricing</div>
    				<table>
    					$pricinginfo
    					<tr>
    						<td class="label">Price: </td>
    						<td class="data">
    								<input type="radio" name="intPricingType" value="$Defs::PRICING_TYPE_SINGLE" id="pricingtype_single" $single_active onChange = "showPriceBlock('singlepricerow');"><label for="pricingtype_single" >Single price (price is the same across all registrations, including family registrations).</label><br>
        ];
        
        if ($allow_multi_price) {
            $body .= qq[
    								<input type="radio" name="intPricingType" value="$Defs::PRICING_TYPE_MULTI" id="pricingtype_multiple" $multi_active onChange="showPriceBlock('multipricerow');"><label for="pricingtype_multiple">Multiple prices (changes in the case of multiple, family, registrations.)</label><br>
            ];
        }
        if ($allow_ranged_price) {
            $body .= qq[
                            <input type="radio" name="intPricingType" value="$Defs::PRICING_TYPE_RANGED" id="pricingtype_ranged" $ranged_active onChange="showPriceBlock('rangedpricerow');"><label for="pricingtype_ranged">Ranged prices (Price is the same across all registrations, but if lower levels set their own price, it must be within a range)</label><br>
            ];
        }
        $body .= qq[

						</td>
					</tr>
					<tr id="singlepricerow" class="pricetype-rows" style="$single_block_active">
						<td class="label">Single Pricing: </td>
						<td class="data">$currency_symbol<input type="text" name="amount" value="$amount" size="$single_size" maxlength="8" $single_placeholder></td>
					</tr>
         ];


     if ($allow_multi_price) {
        $body .= qq[
					<tr id="multipricerow" class="pricetype-rows" style="$multi_block_active">
						<td class="label">Multiple Pricing: </td>
						<td class="data">
							<table>
								<tr>
									<td>$txt{'firstadult'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_Adult1" value="$amounts{'curAmount_Adult1'}" size="6" maxlength="8"></td>
									<td>$txt{'firstchild'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_Child1" value="$amounts{'curAmount_Child1'}" size="6" maxlength="8"></td>
									<td rowspan=4 width="350px">Even if you are only accepting one type (adult or children) please add pricing to both columns to ensure that the correct amount is visible in all areas of the system and for safety if this product is added to an adult form.</td>
								</tr>
								<tr>
									<td>$txt{'secondadult'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_Adult2" value="$amounts{'curAmount_Adult2'}" size="6" maxlength="8"></td>
									<td>$txt{'secondchild'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_Child2" value="$amounts{'curAmount_Child2'}" size="6" maxlength="8"></td>
								</tr>
								<tr>
									<td>$txt{'thirdadult'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_Adult3" value="$amounts{'curAmount_Adult3'}" size="6" maxlength="8"></td>
									<td>$txt{'thirdchild'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_Child3" value="$amounts{'curAmount_Child3'}" size="6" maxlength="8"></td>
								</tr>
								<tr>
									<td>$txt{'plusadult'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_AdultPlus" value="$amounts{'curAmount_AdultPlus'}" size="6" maxlength="8"></td>
									<td>$txt{'pluschild'}</td>
									<td>$currency_symbol<input type="text" name="curAmount_ChildPlus" value="$amounts{'curAmount_ChildPlus'}" size="6" maxlength="8"></td>
								</tr>

							</table>
						</td>
					</tr>
		];
    }
    
    if ($allow_ranged_price) {
        $body .= qq[
                    <tr id="rangedpricerow" class="pricetype-rows" style="$ranged_block_active">
                        <td class="label">Ranged Pricing: </td>
                        <td class="data">
                            <table>
                                <tr>
                                    <td>Default Price</td>
                                    <td>$currency_symbol<input type="text" name="curAmount_Range_Default" value="$amount" size="6" maxlength="8"></td>
                                </tr>
                                <tr>
                                    <td>Minimum Price</td>
                                    <td>$currency_symbol<input type="text" name="curAmountMin" value="$amounts{'curAmountMin'}" size="6" maxlength="8"></td>
                                    <td>Maximum Price</td>
                                    <td>$currency_symbol<input type="text" name="curAmountMax" value="$amounts{'curAmountMax'}" size="6" maxlength="8"></td>
                                </tr>
                            </table>
                        </td>
                    </tr>
        ];
    }


    my $splitRow   = '';
    my %splits     = ();
    if ( $dref->{intEntityID}>-1 or $id == 0) {
		my $hasSplits=0;
        my $paymentSplitSettings = PaymentSplitUtils::getPaymentSplitSettings($Data);
        if ($paymentSplitSettings->{'psProds'}) {
            my $splitID   = '';
            my $splitName = '';
            my $paymentSplits = PaymentSplitObj->getList($entityID, $entityTypeID, $Data->{'db'});
             $paymentSplits = PaymentSplitObj->getList(getID($Data->{'clientValues'}), $current_level, $Data->{'db'}) if($current_level>$Defs::LEVEL_ASSOC);
	 for my $paymentSplit(@{$paymentSplits}) {
                $splitName = $paymentSplit->{'strSplitName'};
								next if ($splitName =~ /Club/ and $Data->{'SystemConfig'}{'dontAllowClubsSplits'});
				$hasSplits++;
                $splitID = $paymentSplit->{'intSplitID'};
								print STDERR $splitName;
                $splits{$splitID} = $splitName;
            }
						$splits{''} = '';

            my $splitRef = \%splits;
			if ($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB
				and $id
				and $dref->{'intCreatedLevel'} != $current_level
			)
			{	
				#and $dref->{'intCreatedLevel'} != $Defs::LEVEL_CLUB
				$splitRef=undef;
			}
	
			if (ref $splitRef)	{
				my $paymentSplitCompulsory = (
					(
						$id==0 
						or $dref->{'intCreatedLevel'} == $Defs::LEVEL_CLUB
					) 
					and $hasSplits
					and ! $Data->{'SystemConfig'}{'AssocConfig'}{'dontAllowClubsSplits'} 
					and $current_level == $Defs::LEVEL_CLUB) ? $compulsory : '';
            	$splitRow = qq[
            	    <tr>
            	        <td class="label">Payment Split: </td>
            	        <td>].drop_down('intSplitID',$splitRef,undef,$dref->{'intPaymentSplitID'},1,0).qq[$paymentSplitCompulsory&nbsp;&nbsp;<span class="formfieldinfo">(Where the money is sent to upon successful online transaction)</span></td>
            	    </tr>
            	];
            	
            	if ($paymentSplitCompulsory){
            	    $validation{'intSplitID'} = {
                        'compulsory' => 1,
                    };
            	}
            	
			}
        }
    }

    $body .= qq[
        $splitRow
    ];


		my $prodlevel =  $dref->{'intCreatedLevel'} || $current_level || 0;
    if(
			$id == 0 
			or ($current_level == $dref->{intCreatedLevel} 
						and $dref->{'intCreatedID'} == $entityID
				 )
		)  {

        my $Products=getProducts($Data);
        $Products->{0}='&nbsp;'; #Provide blank option

        my $DependentProducts = getProductDependencies($Data,$id);

        $body .= qq[
									</table>
									</div>
									<div id="prod-mandatory" class="prodtabletab">
										<div class="sectionheader">Mandatory Products</div>
										<p>Select a mandatory product. The purchases will automatically be required to buy the mandatory product as well as the product here. A typical example is a joining fee. So any person can select which registration product they wish to purchase, but everyone must also pay the joining fee.</span><br><br></p>
									<table>
                    <tr>
                    <td class="label">Mandatory Products:
										</td>
                    <td class="data">
                    <div style="margin-bottom:10px;width:400px;max-height:210px;border:1px solid #B5B8C8;overflow:auto;">
                    ];
        
        foreach my $key (sort {$Products->{$a} cmp $Products->{$b}} keys %{$Products}) {
            next if $key == $id || $key == 0;
            $body .= qq[<input type="checkbox" name="intDependentProductIDs" value="$key" ];
            if(defined($DependentProducts->{$key})) {
                $body .= qq[checked];
            }
            $body .= qq[/>$Products->{$key}<br/>];
        }

				$body .=qq[
							</div>
						</td>
					</tr>
				];
        my $checkedFinancial = $dref->{intSetMemberFinancial} ? 'checked' : '';
        my $checkedActive = $dref->{intSetMemberActive}? 'checked' : '';
        my($memberExpiry,undef) = split(/\s+/,$dref->{'dtMemberExpiry'}||'',-1);
        my($productExpiry,undef) = split(/\s+/,$dref->{'dtProductExpiry'}||'',-1);
				my $seasonPlayerFinancial = $dref->{intSeasonPlayerFinancial} ? 'checked' : '';
				my $seasonCoachFinancial = $dref->{intSeasonCoachFinancial} ? 'checked' : '';
				my $seasonUmpireFinancial = $dref->{intSeasonUmpireFinancial} ? 'checked' : '';
				my $seasonOther1Financial = $dref->{intSeasonOther1Financial} ? 'checked' : '';
				my $seasonOther2Financial = $dref->{intSeasonOther2Financial} ? 'checked' : '';
				my $other1 = $Data->{'SystemConfig'}{'Seasons_Other1'} || '';
				my $other2 = $Data->{'SystemConfig'}{'Seasons_Other2'} || '';

        my $memberPackageID = 0;
        if (param('intProductMemberPackageID')) {
            $memberPackageID = param('intProductMemberPackageID') || $dref->{'intProductMemberPackageID'} || 0;
        }
        else {
            $memberPackageID = $dref->{'intProductMemberPackageID'};
        }
        
        my $MemberPackages = getMemberPackages($Data);
        
        my $mp_select = qq[<select name="intProductMemberPackageID"><option value=""></option>];
        foreach my $key (sort {$MemberPackages->{$a} cmp $MemberPackages->{$b}} keys  %{$MemberPackages}) {
            my $selected = ($key == $memberPackageID) ? 'selected' : '';
            $mp_select .= qq[<option value="$key" $selected>$MemberPackages->{$key}</option>]
        }   
        $mp_select .= qq[</select>];
        my $season_select = qq[<select name="intSeasonMemberPackageID"><option value=""></option>];
        foreach my $key (sort {$MemberPackages->{$a} cmp $MemberPackages->{$b}} keys  %{$MemberPackages}) {
            my $selected = ($key == $dref->{'intSeasonMemberPackageID'}) ? 'selected' : '';
            $season_select.= qq[<option value="$key" $selected>$MemberPackages->{$key}</option>]
        }   
        $season_select.= qq[</select>];
        
				$productExpiry = '' if ($productExpiry and $productExpiry eq '0000-00-00');
				$memberExpiry = '' if ($memberExpiry and $memberExpiry eq '0000-00-00');
        my $prodexpiry = _date_selection_dropdown('productExpiry',$productExpiry);
        my $regexpiry = _date_selection_dropdown('registrationExpiry',$memberExpiry);

				$dref->{'intProductExpiryDays'} ||= '';
				$dref->{'intMemberExpiryDays'} ||= '';
        $body .= qq[
				</table>
				</div>
				<div id="prod-actions" class="prodtabletab">
					<div class="sectionheader">Actions to perform on successful payment</div>
				<table>
					<tr>
						<th class="label">Set Product Expiry:</th>
						<td class="data">to $prodexpiry <span class="HTdateformat">(dd-mon-yyyy)</span> <br><b>or</b><br>for <input type="textbox" size="2" value="$dref->{intProductExpiryDays}" name="d_productExpiry_days"/> (days from product purchase) </td>
					</tr>
				];
        $body .= qq[

					<tr><td class="settings-group-name" colspan="2"><br>Season Based (Registration Season)</td></tr>
					<tr>
						<td class="label"><label for="setSeasonPlayerFinancial">Set Player Financial:</label></td>
						<td class="data"><input type="checkbox" name="setSeasonPlayerFinancial" value="1" $seasonPlayerFinancial></td>
					</tr>
					<tr>
						<td class="label"><label for="setSeasonCoachFinancial">Set Coach Financial:</label></td>
						<td class="data"><input type="checkbox" name="setSeasonCoachFinancial" value="1" $seasonCoachFinancial></td>
					</tr>
					<tr>
						<td class="label"><label for="setSeasonUmpireFinancial">Set $Data->{'SystemConfig'}{'TYPE_NAME_3'} Financial:</label></td>
						<td class="data"><input type="checkbox" name="setSeasonUmpireFinancial" value="1" $seasonUmpireFinancial></td>
					</tr>
				];
        $body .= qq[
					<tr>
						<td class="label"><label for="setSeasonOther1Financial">Set $other1 Financial:</label></td>
						<td class="data"><input type="checkbox" name="setSeasonOther1Financial" value="1" $seasonOther1Financial></td>
					</tr>
				] if $other1;
        $body .= qq[
					<tr>
						<td class="label"><label for="setSeasonOther2Financial">Set $other2 Financial:</label></td>
						<td class="data"><input type="checkbox" name="setSeasonOther2Financial" value="1" $seasonOther2Financial></td>
					</tr>
				] if $other2;
        $body .= qq[
					<tr>
						<td class="label"><label for="setSeasonMemberPackage">Set Season Member Package:</label></td>
						<td class="data">$season_select</td>
					</tr>

				];

        
				my $ProductMemberTypes = getProductAttributes($Defs::PRODUCT_MEMBER_TYPES,$Data,$id);
        my $ProductAgeGroups = getProductAttributes($Defs::PRODUCT_AGE_GROUPS,$Data,$id);
        my $ProductDOB_Min = getProductAttributes($Defs::PRODUCT_DOB_MIN,$Data,$id);
        my $ProductDOB_Max = getProductAttributes($Defs::PRODUCT_DOB_MAX,$Data,$id);
        my $ProductAge_Min = getProductAttributes($Defs::PRODUCT_AGE_MIN,$Data,$id);
        my $ProductAge_Max = getProductAttributes($Defs::PRODUCT_AGE_MAX,$Data,$id);

				my $genderdropdown = popup_menu(
					-name => 'gender',
					-values => [0, $Defs::GENDER_MALE, $Defs::GENDER_FEMALE],
					-labels => {
						0 => $l->txt('Any'),
						$Defs::GENDER_MALE => $l->txt($Defs::genderInfo{$Defs::GENDER_MALE}),
						$Defs::GENDER_FEMALE => $l->txt($Defs::genderInfo{$Defs::GENDER_FEMALE}),
					},
					-default => $dref->{'intProductGender'} || 0,
				);

				my $dob_max = _date_selection_dropdown('dob_max', $ProductDOB_Max->[0]);
				my $dob_min = _date_selection_dropdown('dob_min', $ProductDOB_Min->[0]);
                my %age_min_options = map {$_=>$_} (1..99);
                my %age_max_options = map {$_=>$_} (1..99);
                $age_min_options{0} = 'Any';
                $age_max_options{100} = 'Any';
                my @age_min_orders = sort { $a <=> $b }  keys %age_min_options;
                my @age_max_orders = sort { $b <=> $a }  keys %age_max_options;
				my $age_max = drop_down('age_max', \%age_max_options, \@age_max_orders, $ProductAge_Max->[0], 1, 0) || '';
				my $age_min = drop_down('age_min', \%age_min_options, \@age_min_orders, $ProductAge_Min->[0], 1, 0) || '';

				my $memtypeslist = '';
        foreach my $type (sort keys %Defs::memberTypeName) {
		if($type<5) {
            	    $memtypeslist .= qq[<input type="checkbox" name="memberTypes" value="$type" ];
            	    if(grep $_ eq "$type", @{$ProductMemberTypes}) {
                	$memtypeslist .= qq[checked];
                    }
            	$memtypeslist .= qq[/>$Defs::memberTypeName{$type}<br>];
        	}
	}

        $body .= qq[
						</table>
					</div>
						<div id="prod-filter" class="prodtabletab">
							<div class="sectionheader">Automatically Filter Product Selection</div>
							<p>Use these fields to automatically show some products.  If you tick 'Coach' then this product will only show to people trying to register as a coach.  Similarly you could use the date of birth fields to show products only relevant to individuals under or over a certain age.<br><br></p>
						<table>
							<tr>
                                <td class="label"><label for="gender">Member Gender:</label></td>
							    <td class="data">$genderdropdown</td>
							</tr>
							<tr>
                                <td class="label"><label for="clrdob1">Minimum DOB:</label></td>
								<td class="data">$dob_min</td>
                                <td><button type="button" class="clrdob" id="clrdob1" style="font-size:8px">C</button>
Older end of Date Range (eg 01 - Jan - 1970)</td> 							
</tr>
							<tr>
                                <td class="label"><label for="clrdob2">Maximum DOB:</label></td>
								<td class="data">$dob_max </td>
                                <td><button type="button" class="clrdob" id="clrdob2" style="font-size:8px">C</button>
 Younger end of Date Range (eg 31 - Dec - 2000) </td>
							</tr>
							<tr>
                                <td class="label"><label for="age1">Minimum Age:</label></td>
								<td class="data">$age_min</td>
</tr>
							<tr>
                                <td class="label"><label for="age2">Maximum Age:</label></td>
								<td class="data">$age_max </td>
							</tr>
							<tr>
								<td class="label"><label for="memberTypes">Member type:<br>(Any of)</label></td>
								<td class="data">$memtypeslist</td>
							</tr>
							];
                
				$body .= qq[		</table>
					</div>
				];

			  $dref->{'DateAvailableFrom'} = '' if $dref->{'DateAvailableFrom'} eq '0000-00-00';
				my $from_date = _date_selection_dropdown('from_date', $dref->{'DateAvailableFrom'});
			  $dref->{'DateAvailableTo'} = '' if $dref->{'DateAvailableTo'} eq '0000-00-00';

				my $to_date   = _date_selection_dropdown('to_date',   $dref->{'DateAvailableTo'});
				my $from_time = _time_selection_box('from_time', $dref->{'TimeAvailableFrom'});
				my $to_time   = _time_selection_box('to_time',   $dref->{'TimeAvailableTo'});

				$body .= qq[
						<div id="prod-available" class="prodtabletab">
							<div class="sectionheader">Product Availability</div>
							<p>If left blank the product will be available all the time.<br></p>
						<table>
							<tr>
                 <td class="label"><label for="gender">Product available from:</label></td>
								<td class="data">$from_date $from_time </td>
							</tr>
							<tr>
                <td class="label"><label for="gender">Product available to:</label></td>
								<td class="data">$to_date $to_time </td>
							</tr>
				];
				my %TProducts = %{$Products};
				my $products_drop = drop_down(
					'd_intRenewProductID',
					\%TProducts,
					'',
					$dref->{'intRenewProductID'} || $id,
					1,
					0,
				);
				$body .= qq[
						</table>
					</div>
						<div id="prod-renew" class="prodtabletab">
							<div class="sectionheader">Product Linking</div>
							<p>Product linking is a way to renew product purchases, it makes the expiry date of an old product, the commencement date of a new product.</p><br>
							<table>
							<tr>
                <td class="label"><label for="">Once this product has expired, it should be renewed by this NEW product:</label></td>
								<td class="data">$products_drop</td>
							</tr>
							</table>
							<div class="sectionheader">Automatic Reminder Emails</div>
							<p>Members can be reminded that a product they have purchased is due to expire/is expired, by creating automatic reminder emails.</p><br>
						<table>
				];
				for my $i (1 .. 5)	{
					my $renewdays = $dref->{'intRenewDays'.$i} || 0;	
					my $renewdir = 'before';
					if($renewdays < 0)	{
						$renewdir = 'after';
						$renewdays *= -1;
					}
					my $renew_dir_drop = drop_down('d_renew_dir_'.$i,{ before => 'before', after => 'after', }, undef,$renewdir,1,0) || '';
					
					my %nums = ();
					my @numorder = ();
					for my $j (0 .. 60)	{
						$nums{$j} = $j;
						push @numorder, $j;
					}
					$dref->{'intRenewDays'.$i} ||= 0;
					my $renew_days_drop = drop_down('d_intRenewDays'.$i,\%nums, \@numorder,$renewdays,1,0) || '';
					$body .= qq[
							<tr>
                 <td class="label" colspan = "2" style ="text-align:left;"><label>Email this message $renew_days_drop days $renew_dir_drop the product is due to expire:</label></td>
							</tr>
							<tr>
								<td class="data" colspan = "2"><textarea name = "d_strRenewText$i" rows = "5" cols = "70">$dref->{'strRenewText'.$i}</textarea><br><br></td>
							</tr>
					];
				}
				my $regoform_drop = '';
				{

    			my $clubID = $Data->{'clientValues'}{'clubID'} || $Defs::INVALID_ID;
					my $st = qq[
							SELECT intRegoFormID, strRegoFormName
							FROM   tblRegoForm
							WHERE  intEntityID = $entityID
									AND intClubID = $clubID
									AND intStatus <> -1
					];
					$regoform_drop = getDBdrop_down(
						'd_intRenewRegoFormID',
						$Data->{'db'},
						$st,
						$dref->{'intRenewRegoFormID'}|| 0,
						' ',
						1,
						0,
					);
				}


				$body .= qq[
							<tr>
                 <td class="data" colspan = "2"><p>In the above reminder emails a link to an online registration form can be included, where members can re-register and purchase the renewal product.</p></td>
							</tr>
							<tr>
                <td class="label"><label for="gender">Registration form to be added to Automatic Reminder Emails:</label></td>
								<td class="data">$regoform_drop</td>
							</tr>
							<tr>
                 <td class="data" colspan = "2"><p>Please Note: In order for members to be able to purchase the renewal product it must have been added to the registration form.</p></td>
							</tr>
				];


		}
		
    $body .= qq[
						</table>
						</div>
	];
$body .= qq[
                                                        </div>
                                                <div style = "clear:both;"></div><br>
        ];

$body .= qq[
            <input type="submit" value=" Update " /> <br><br>
                <input type="hidden" name="a" value="PR_U">
                <input type="hidden" name="client" value="$unesc_cl">
                <input type="hidden" name="lki" value="$id">
                </form>
               <p><a href="$Data->{target}?client=$cl&amp;a=PR_L&amp;">Click here</a> to return to product list.</p>
                ];
		my $breadcrumbs = HTML_breadcrumbs(
				[
            'Products',
            'main.cgi',
            { client => $unesc_cl, a => 'PR_L'},
        ],
        [ $dref->{'strName'}],
    );
    
    my $validation_js = generate_clientside_validation( \%validation, {'options' => {
        LocaleMakeText  => $Data->{'lang'},
        formname => 'product_form',
        field_prefix => '',
        tab_div_id => 'prodtabs',
        tab_class  => 'prodtabletab',
        tab_style  => 'ui-tabs',
    }});

  $Data->{'AddToPage'}->add(
    'js_bottom',
    'inline',
    "if($fulledit) { jQuery('#prodtabs').tabs(); }",
  );

    my $scripts = qq[
                   <script type="text/javascript">
                                    function showPriceBlock(block)  {
                                        jQuery('.pricetype-rows').hide();
                                        jQuery('.pricetype-rows').children().children().addClass('ignore');
                                        jQuery('#' + block ).show(); 
                                        jQuery('#' + block).children().children().removeClass('form_field_invalid');
                                        jQuery('#' + block).children().children().removeClass('ignore');
                                        return true;
                                    }
                                    jQuery(document).ready(function() {
                                        if ($dref->{'intPricingType'} == $Defs::PRICING_TYPE_MULTI)   {
                                            showPriceBlock('multipricerow');
                                        }
                                        else if ($dref->{'intPricingType'} == $Defs::PRICING_TYPE_RANGED) {
                                            showPriceBlock('rangedpricerow');
                                        }
                                        else {
                                            showPriceBlock('singlepricerow');
                                        }
                                        jQuery('.clrdob').click(function(e){
                                            e.preventDefault();
                                            var minmax;
                                            if (e.target.id == 'clrdob1') minmax = 'min'; else minmax = 'max';
                                            jQuery('input[name=d_dob_' + minmax + '_day]').val('');
                                            jQuery('select[name=d_dob_' + minmax + '_mon]').prop('selectedIndex', 0);
                                            jQuery('input[name=d_dob_' + minmax + '_year]').val('');
                                        });
                                        jQuery('.clrdob').hover(function(e){
                                            var minmax;
                                            if (e.target.id == 'clrdob1') minmax = 'Minimum'; else minmax = 'Maximum';
                                            jQuery(this).append(jQuery('<span> Clear ' + minmax + ' DOB fields</span>'));
                                            },function(){
                                            jQuery(this).find("span:last").remove(); 
                                        });
                                    });

                   </script>
                   ];
    
    $scripts .= $validation_js;
    
    return ( $scripts . $body, "Edit Products - $dref->{'strName'}", $breadcrumbs);
}


sub getProductCost {
    my($Data, $prodID) = @_;
    
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};

    my $sql = qq[
      SELECT 
				intLevel, 
				curAmount , 
				intPricingType,
				curAmount_Adult1,
				curAmount_Adult2,
				curAmount_Adult3,
				curAmount_AdultPlus,
				curAmount_Child1,
				curAmount_Child2,
				curAmount_Child3,
				curAmount_ChildPlus
      FROM tblProductPricing 
      WHERE 
				intProductID = ?
				AND intLevel>= ?
			LIMIT 1
    ];

    my $query = $Data->{'db'}->prepare($sql);
    $query->execute(
			$prodID,
			$currentLevel
		);

		my $prodCost = 0;
    my $dref = $query->fetchrow_hashref();
		$query->finish();
		$prodCost = getMinPrice($dref);

    if (!$dref->{'intLevel'})	{
			my $st = qq[
				SELECT curDefaultAmount
				FROM tblProducts
				WHERE intProductID = $prodID
				LIMIT 1
			];
    	my $query = $Data->{'db'}->prepare($st);
    	$query->execute();
    	my ($productCost) = $query->fetchrow_array();
			$prodCost = $productCost;
		}

    return $prodCost;
}


sub getSplitValue {
    my ($Data, $splitID, $productPrice) = @_;

    my $paymentSplitItems = PaymentSplitItemObj->getList($splitID, $Data->{'db'});

    # accum fees first
    my ($feesAmount, $feesFactor) = PaymentSplitFeesObj->getTotalFees($Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'db'});
    my $splitValue = $feesAmount + $productPrice * $feesFactor;
    my $feesTotal = $splitValue || 0;
    # now accum items
    for my $paymentSplitItem(@{$paymentSplitItems}) {
        my $amount = $paymentSplitItem->{'curAmount'};
        my $factor = $paymentSplitItem->{'dblFactor'};
        $splitValue += ($amount != '0.00')
            ? $amount
            : $productPrice * $factor;
    }

    $splitValue = sprintf("%.2f", $splitValue);
    $feesTotal = sprintf("%.2f", $feesTotal);

    return ($splitValue, $feesTotal);
}


sub checkSplitValue {
    my ($Data, $splitID, $prodID, $prodCost) = @_;

    $prodCost = getProductCost($Data, $prodID) if (!$prodCost and $prodID);
    
    $prodCost = sprintf("%.2f", $prodCost); # round to 2 dp

    my ($splitValue, $fees_total) = getSplitValue($Data, $splitID, $prodCost);
    my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);
    
		if ($Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID)	{
			$entityID = $Data->{'clientValues'}{'clubID'} || 0;
			$entityTypeID = 3;
		}
		my $feeType= PaymentApplication::getFeeTypeDefault($Data, $entityTypeID, $entityID);
    my $errMsg = '';

    if ($splitValue > $prodCost  and $feeType !=2)	{
			if(!($splitValue eq $fees_total and $prodCost eq '0.00'))		{
				$errMsg = qq[
		    <div class="warningmsg">
			<p>Product not updated because split value ($splitValue) would exceed price of product ($prodCost)!</p>
		    </div>
				];
			}
    }

    return ($errMsg);
}


sub update_products	{
	my($Data, $id)=@_;

	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  
    my $current_level = $Data->{'clientValues'}{'currentLevel'};
    my $original_level = $current_level;
    
    my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

	my $name=param('name') || '';
	return ('<div class="warningmsg">Unable to Add Product. You must have a name for the Product</div>',0) if ! $name;
	my $notes=param('strProductNotes') || '';
	my $group=param('strGroup') || '';
	my $gsttext=param('strGSTText') || '';
	my $multiPurchase=param('intAllowMultiPurchase') || 0;
	my $minChangeLevel =param('intMinChangeLevel') || 0;
	my $minSellLevel =param('intMinSellLevel') || 0;
	my $allowQtys =param('intAllowQtys') || 0;
	my $inactive =param('intInactive') || 0;
  $name=~s/>/&gt;/g;
  $name=~s/</&lt;/g;
  $notes=~s/>/&gt;/g;
  $notes=~s/</&lt;/g;
  $group=~s/>/&gt;/g;
  $group=~s/</&lt;/g;
  $gsttext=~s/>/&gt;/g;
  $gsttext=~s/</&lt;/g;
	my $amount=param('amount') || 0;
  my $gender=param('gender') || 0;
  my $setMemberActive = param('setMemberActive') || 0;
  my $setMemberFinancial = param('setMemberFinancial') || 0;

  my $setSeasonPlayerFinancial = param('setSeasonPlayerFinancial') || 0;
	my $setSeasonCoachFinancial = param('setSeasonCoachFinancial') || 0;
	my $setSeasonUmpireFinancial = param('setSeasonUmpireFinancial') || 0;
	my $setSeasonOther1Financial = param('setSeasonOther1Financial') || 0;
	my $setSeasonOther2Financial = param('setSeasonOther2Financial') || 0;
	my $setSeasonMemberPackageID = param('intSeasonMemberPackageID') || 0;
	my $intPricingType = param('intPricingType') || 0;
	my $curAmount_Adult1 = param('curAmount_Adult1') || 0;
	my $curAmount_Adult2 = param('curAmount_Adult2') || 0;
	my $curAmount_Adult3 = param('curAmount_Adult3') || 0;
	my $curAmount_AdultPlus = param('curAmount_AdultPlus') || 0;
	my $curAmount_Child1 = param('curAmount_Child1') || 0;
	my $curAmount_Child2 = param('curAmount_Child2') || 0;
	my $curAmount_Child3 = param('curAmount_Child3') || 0;
	my $curAmount_ChildPlus  = param('curAmount_ChildPlus') || 0;
	my $curAmountMax = param('curAmountMax') || 0;
	my $curAmountMin = param('curAmountMin') || 0;
	
	if ($intPricingType == $Defs::PRICING_TYPE_RANGED){
	    $amount =  param('curAmount_Range_Default') || 0;
	}


	my $intProductSeasonID= param('intProductSeasonID') || 0;
    
	my $mandatoryProductID = param('intMandatoryProductID') || 0;
  my $memberPackageID  = param('intProductMemberPackageID') || 0; 
  # photo upload
  my $photoAction = param('a_photo') ||'';

  my $splitID      = param('intSplitID') || 0;
  my $splitDefined = ($splitID) ? 1 : 0;
  $splitID ||= 0;

  $amount=~s/[^\d\.\-]//g;

	# dont accept update if cost < split value
	if ($splitDefined) {
			my $minprice = getMinPrice();
			my $errMsg = checkSplitValue($Data, $splitID, $id, $minprice);
			return ($errMsg, $id) if $errMsg;
	}

	my @memberTypes = param('memberTypes');
	my @ageGroups = param('ageGroups');
	
	my $expiryMemberDt = 'NULL';
	my $expiryMemberDays = 0;
	my $expiryProductDt = 'NULL';
	my $expiryProductDays = 0;

	my $dobmax = getExpiryDt('d_dob_max',1,'-');
	my $dobmin = getExpiryDt('d_dob_min',1,'-');
    my $age_max = param('age_max');
    my $age_min = param('age_min');
	if (($dobmax =~ /ERROR/) or ($dobmin =~ /ERROR/)) {
			return <<"EOS";
<div class="warningmsg">
Unable to add or update product. Please check the dates you entered in the
'Date of Birth between' fields.
</div>
EOS
	}

	if(param('d_registrationExpiry_days') =~/^(\d+)$/ && param('d_registrationExpiry_days') > 0) {
			$expiryMemberDays = $1;
	}
	else {
			$expiryMemberDt = getExpiryDt('d_registrationExpiry',1,'-') ;
			if($expiryMemberDt =~/ERROR/) {
					return("<div class=\"warningmsg\">Unable to add or update product. Please check the Member Registered Until Date you entered.</div>",0);
			}
	}
	
	if(param('d_productExpiry_days') =~/^(\d+)$/ && param('d_productExpiry_days') > 0){
			$expiryProductDays = $1;
	}
	else {
			$expiryProductDt = getExpiryDt('d_productExpiry',1,'-');
			if($expiryProductDt =~/ERROR/) {
					return("<div class=\"warningmsg\">Unable to add or update product. Please check the Product Expiry Date you entered.</div>",0);
			}
	}
    
	my $st='';
	my $dbErrMsg =  '<div class="warningmsg">There was a problem adding or updating the product</div>';

	my $prod_avail_from_date = getExpiryDt('d_from_date',1,'-');
	my $prod_avail_to_date = getExpiryDt('d_to_date',1,'-');
	my $prod_avail_from_time = getTimeFieldValue('d_from_time');
	my $prod_avail_to_time = getTimeFieldValue('d_to_time');
	if(
		$prod_avail_from_date =~/ERROR/
		or $prod_avail_to_date =~/ERROR/
	) {
		return("<div class=\"warningmsg\">Unable to add or update product. Please check the Product availability dates that you entered.</div>",0);
	}
	$prod_avail_from_date .= ' '.$prod_avail_from_time;
	$prod_avail_to_date .= ' '.$prod_avail_to_time;

	if ($id)  {
		$st = qq[
			 SELECT intCreatedLevel, intCreatedID
			 FROM tblProducts
			 WHERE intProductID = ?
		];
		my $query = $Data->{'db'}->prepare($st);
		$query->execute($id);
		my ($intCreatedLevel, $intCreatedID)=$query->fetchrow_array();

		$st = qq[
			DELETE FROM tblProductPricing
			WHERE intProductID = ?
				AND intRealmID = ?
				AND intID = ?
				AND intLevel = ?
		];
		$query = $Data->{'db'}->prepare($st);
		$query->execute(
			$id,
			$realmID,
			$entityID,
			$current_level,
		);	


		if (
			$current_level != $intCreatedLevel 
			and $entityID!= $intCreatedID 
			and $current_level != $Defs::LEVEL_NATIONAL)  {
		}
		else  {
			$amount ||= $curAmount_Adult1;
			$st=qq[
				UPDATE tblProducts
				SET strName= ?,
					curDefaultAmount= ?,
					strProductNotes = ?,
					strGroup = ?,
					intMandatoryProductID = ?,
					intAllowMultiPurchase = ?,
					intInactive = ?,
					intAllowQtys = ?,
					intProductGender = ?,
					intSetMemberActive = ?,
					intSetMemberFinancial = ?,
					dtMemberExpiry = ?,
					dtProductExpiry = ?,
					intProductExpiryDays = ?,
					intMemberExpiryDays = ?,
					intProductMemberPackageID = ?,
					strGSTText = ?,
					intMinChangeLevel= ?,
					intMinSellLevel= ?,
					intSeasonPlayerFinancial = ?,
					intSeasonCoachFinancial = ?,
					intSeasonUmpireFinancial = ?,
					intSeasonOther1Financial = ?,
					intSeasonOther2Financial = ?,
					intSeasonMemberPackageID = ?,
					intProductSeasonID = ?,
					dtDateAvailableFrom = ?,
					dtDateAvailableTo = ?,

				WHERE intRealmID= ?
					AND intEntityID= ?
					AND intProductID = ?
			];
			$query = $Data->{'db'}->prepare($st);
			$query->execute(
				$name,
				$amount,
				$notes,
				$group,
				$mandatoryProductID,
				$multiPurchase,
				$inactive,
				$allowQtys,
				$gender,
				$setMemberActive,
				$setMemberFinancial,
				$expiryMemberDt,
				$expiryProductDt,
				$expiryProductDays,
				$expiryMemberDays,
				$memberPackageID,
				$gsttext,
				$minChangeLevel,
				$minSellLevel,
				$setSeasonPlayerFinancial,
				$setSeasonCoachFinancial ,
				$setSeasonUmpireFinancial,
				$setSeasonOther1Financial,
				$setSeasonOther2Financial,
				$setSeasonMemberPackageID,
				$intProductSeasonID,
				$prod_avail_from_date,
				$prod_avail_to_date,
				$realmID,
				$entityID,
				$id,
			);
			
			# insert/update price range
			
			if ($intPricingType == $Defs::PRICING_TYPE_RANGED){
			    updateProductRangePricing($Data->{'db'}, $id, $curAmountMin, $curAmountMax);    
            };
		}
		updateProductTXNPricing($Data->{'db'}, $entityID, $id, $amount) if ($current_level == $Defs::LEVEL_ASSOC);
		_update_product_dependencies($Data,$id);

		my %attributes_to_update = (
				$Defs::PRODUCT_MEMBER_TYPES => \@memberTypes,
				$Defs::PRODUCT_AGE_GROUPS   =>\@ageGroups,
		);

	    $attributes_to_update{$Defs::PRODUCT_DOB_MIN} = [ $dobmin ];
	    $attributes_to_update{$Defs::PRODUCT_DOB_MAX} = [ $dobmax ];
	    $attributes_to_update{$Defs::PRODUCT_AGE_MIN} = [ $age_min ];
        $attributes_to_update{$Defs::PRODUCT_AGE_MAX} = [ $age_max ];
	    

		_update_product_attributes($Data,$id, \%attributes_to_update );
		update_product_renew_fields(
			$Data,
			$Data->{'db'},
			$id,
		);

		auditLog(
			$id,
			$Data,
			'Update',
			'Products'
		);
	}
	else  {
		if ($entityID== -1)	{
			$entityID= 0;
		}

		$st=qq[
			INSERT INTO tblProducts (
				intEntityID,
				intMinSellLevel,
				intRealmID,
				strName,
				curDefaultAmount,
				intCreatedLevel,
				intCreatedID,
				strProductNotes,
				strGroup,
				intMandatoryProductID,
				intAllowMultiPurchase,
				intInactive,
				intAllowQtys,
				intSetMemberActive,
				intSetMemberFinancial,
				dtMemberExpiry,
				dtProductExpiry,
				intMemberExpiryDays,
				intProductExpiryDays,
				intProductGender,
				intProductMemberPackageID,
				strGSTText,
				intMinChangeLevel,
				intSeasonPlayerFinancial,
				intSeasonCoachFinancial,
				intSeasonUmpireFinancial,
				intSeasonOther1Financial,
				intSeasonOther2Financial,
				intSeasonMemberPackageID,
				intProductSeasonID,
				dtDateAvailableFrom,
				dtDateAvailableTo
			)
			VALUES (
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
                ?,
                ?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?,
				?
			)
		];
		my $query = $Data->{'db'}->prepare($st);

		$query->execute(
			$entityID,
			$minSellLevel,
			$realmID,
			$name,
			$amount,
			$current_level,
			$entityID,
			$notes,
			$group,
			$mandatoryProductID,
			$multiPurchase,
			$inactive,
			$allowQtys,
			$setMemberActive ,
			$setMemberFinancial,
			$expiryMemberDt,
			$expiryProductDt,
			$expiryMemberDays,
			$expiryProductDays,
			$gender,
			$memberPackageID,
			$gsttext,
			$minChangeLevel,
			$setSeasonPlayerFinancial,
			$setSeasonCoachFinancial ,
			$setSeasonUmpireFinancial,
			$setSeasonOther1Financial,
			$setSeasonOther2Financial,
			$setSeasonMemberPackageID,
			$intProductSeasonID,
			$prod_avail_from_date,
			$prod_avail_to_date,
		) || return ($dbErrMsg,0);
		$id = $query->{mysql_insertid} || 0;
		_insert_product_dependencies($Data,$id);
		
		if ($intPricingType == $Defs::PRICING_TYPE_RANGED){
            updateProductRangePricing($Data->{'db'}, $id, $curAmountMin, $curAmountMax);    
        };

		##BAFF
		my %attributes_to_insert = (
				$Defs::PRODUCT_MEMBER_TYPES => \@memberTypes,
				$Defs::PRODUCT_AGE_GROUPS   =>\@ageGroups,
		);

		if ($dobmin and $dobmin ne 'NULL') {
				$attributes_to_insert{$Defs::PRODUCT_DOB_MIN} = [ $dobmin ];
		}

		if ($dobmax and $dobmax ne 'NULL') {
				$attributes_to_insert{$Defs::PRODUCT_DOB_MAX} = [ $dobmax ];
		}

		if ($age_min and $age_min ne 'NULL') {
				$attributes_to_insert{$Defs::PRODUCT_AGE_MIN} = [ $age_min ];
		}

		if ($age_max and $age_max ne 'NULL') {
				$attributes_to_insert{$Defs::PRODUCT_AGE_MAX} = [ $age_max ];
		}
		
		_insert_product_attributes($Data,$id, \%attributes_to_insert );

		auditLog(
			$id,
			$Data,
			'Add',
			'Products'
		);
	}

	$st=qq[
		INSERT IGNORE INTO tblProductPricing (
			curAmount, 
			intProductID, 
			intRealmID, 
			intID, 
			intLevel,
			intPricingType,
			curAmount_Adult1,
			curAmount_Adult2,
			curAmount_Adult3,
			curAmount_AdultPlus,
			curAmount_Child1,
			curAmount_Child2,
			curAmount_Child3,
			curAmount_ChildPlus
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?
		)
	];
	my $query = $Data->{'db'}->prepare($st);
	$query->execute(
		$amount, 
		$id, 
		$realmID, 
		$entityID, 
		$current_level,
		$intPricingType,
		$curAmount_Adult1,
		$curAmount_Adult2,
		$curAmount_Adult3,
		$curAmount_AdultPlus,
		$curAmount_Child1,
		$curAmount_Child2,
		$curAmount_Child3,
		$curAmount_ChildPlus,
	);

	my $dberr = 0;
	$dberr++ if $DBI::err;
	# Process Photo Uploading
	
	#if ($splitDefined and $id) {
	if (param('intSplitID') and $id) {
			$st = qq[
					UPDATE tblProducts
					SET intPaymentSplitID=$splitID
					WHERE intRealmID=$realmID AND intEntityID = $entityID AND intProductID=$id
			];
			$Data->{'db'}->do($st);
			$dberr++ if $DBI::err;
	}
	
	return ($dbErrMsg, 0) if $dberr;
	if($amount>0 and $amount<25) {	
		return (qq[<div class="OKmsg">The product has been successfully saved.</div><div class="warningmsg"> However this product may incur processing fees due to its low price.</div>],$id);
	} else {
		return (qq[<div class="OKmsg">The product has been successfully saved</div>],$id);
	}	
}


sub _update_product_dependencies {
  my ($Data,$id) = @_;


  my $realmID=$Data->{'Realm'} || 0;
  my $intLevel = $Data->{'clientValues'}{'currentLevel'};
my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);
  my $intID = getID($Data->{'clientValues'}) || 0;

  # Remove previously selected dependent products;
  my $query = qq[
           DELETE FROM tblProductDependencies
           WHERE intProductID = $id
           AND intRealmID = $realmID
           AND intID = $entityID
           AND intLevel = $entityTypeID
           ];
  $Data->{'db'}->do($query);

  return _insert_product_dependencies($Data,$id);
}

sub _insert_product_dependencies {
  my ($Data,$id)= @_;

  my $realmID=$Data->{'Realm'} || 0;
my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

  # Now insert the selected mandatory products into tblProductsDependencies.
  if (!scalar(param('intDependentProductIDs'))) {
    return;
  }
  else {
    my $query = qq[
             INSERT INTO tblProductDependencies(intProductID,intDependentProductID,intRealmID,intID,intLevel)
             VALUES($id,?,$realmID,$entityID, $entityTypeID)
             ];
    my $sth = $Data->{'db'}->prepare($query);
    foreach my $mID(param('intDependentProductIDs')) {
      $sth->bind_param( 1, $mID );
      $sth->execute();
    }
    return;
  }
}

sub _update_product_attributes {
  my ($Data,$productID,$attributesValues) = @_;

   my $realmID=$Data->{'Realm'} || 0;
    my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

  # Remove previously selected product attributes for this type.
  my $query = qq[
           DELETE FROM tblProductAttributes
           WHERE intProductID = $productID
           AND intRealmID = $realmID
           AND intID = $entityID
           AND intLevel = $entityTypeID
           AND intAttributeType = ?
            ];
  my $sth = $Data->{'db'}->prepare($query);
  foreach my $type(keys %{$attributesValues}) {
    $sth->execute($type);
  }
  return _insert_product_attributes($Data,$productID,$attributesValues);
}


sub _insert_product_attributes {
  my ($Data,$productID,$attributesValues) = @_;
  my $realmID=$Data->{'Realm'} || 0;
my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

  my $query = qq[
           INSERT INTO tblProductAttributes
           (intProductID,intAttributeType,strAttributeValue,intRealmID,intID,intLevel)
           VALUES($productID,?,?,$realmID,$entityID, $entityTypeID)
           ];

  my $sth = $Data->{'db'}->prepare($query);

  TYPE: foreach my $type(keys %{$attributesValues}) {
    VALUE: for my $value(@{$attributesValues->{$type}}) {
        next VALUE if (($type == $Defs::PRODUCT_DOB_MIN or $type == $Defs::PRODUCT_DOB_MAX or $type == $Defs::PRODUCT_AGE_MIN or $type == $Defs::PRODUCT_AGE_MAX) and ($value eq 'NULL'));
        next VALUE if (($type == $Defs::PRODUCTOGRAM_NEW or $type == $Defs::PRODUCT_PROGRAM_RETURNING) and (!$value));
      $sth->execute($type, $value); 
    }
  }
  return;
}

sub getProductDependencies {
    my($Data, @productIDs)=@_;

    my $productID = join(',', map { '?' } @productIDs );

    my $realmID=$Data->{'Realm'} || 0;

my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);
    my $intLevel = $Data->{'clientValues'}{'currentLevel'};
#  $intLevel=$Defs::LEVEL_ASSOC if $intLevel < $Defs::LEVEL_CLUB;

    my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
    my $WHERE = qq[
        AND (
            ( pd.intLevel = $Defs::LEVEL_CLUB AND pd.intID = ? )
            OR
            ( pd.intLevel = $Defs::LEVEL_NATIONAL AND pd.intID = ? )
        ) 
    ];

    my $intID = getID($Data->{'clientValues'}) || 0;
    my $query=qq[
        SELECT pd.intDependentProductID,p.strName
        FROM tblProducts p, tblProductDependencies pd
        WHERE p.intProductID = pd.intDependentProductID
        AND pd.intRealmID = ?
        $WHERE 
        AND pd.intProductID IN ($productID)
        ORDER BY strGroup, strName
    ];

    my $sth = $Data->{'db'}->prepare($query);

    $sth->execute(
        $realmID,
        $clubID,
        $Data->{'clientValues'}{'natID'},
				@productIDs,
    );

  my %DependentProducts=();
  while (my ($id,$name)=$sth->fetchrow_array())  {
    $DependentProducts{$id}=$name||'';
  }
  return \%DependentProducts;
}

sub getProductAttributes {
  my ($attributeType,$Data,$productID) = @_;
  my $realmID=$Data->{'Realm'} || 0;
    
my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

  my $query=qq[
    SELECT 
      strAttributeValue 
    FROM 
      tblProductAttributes
    WHERE 
      intProductID = ?
      AND intRealmID = ?
      AND intID = ?
      AND intLevel = ?
      AND intAttributeType = ?
  ];
  my $sth = $Data->{'db'}->prepare($query);
  $sth->execute(
    $productID,
    $realmID,
    $entityID,
    $entityTypeID,
    $attributeType
  );
  my @AttributeValues=();
  while (my ($value) =$sth->fetchrow_array())  {
		next if($value and $value eq 'NULL');
    push(@AttributeValues,$value);
  }
  return \@AttributeValues;
}

sub getExpiryDt {
  my ($prefix, $dontcheckpast, $delim) = @_;
	$dontcheckpast ||= 0;
	$delim ||='/';
  my $y = param($prefix . '_year') ? param($prefix. '_year') : '';
  my $m = param($prefix . '_mon') ? param($prefix . '_mon') : '';
  my $d = param($prefix. '_day') ? param($prefix . '_day') : '';
  if($y eq '' and $m eq '' and $d eq ''){
    return 'NULL'; # No date supplied.
  }

  if($y !~/\d{2,4}/){
    return 'ERROR:Please check the year you entered.';
    }

    my($yearNow) = (localtime)[5];
    $yearNow += 1900;

  if(($y < $yearNow and !$dontcheckpast)  || ($y > ($yearNow += 100)) ) {
     return ("ERROR:Please check the year you entered");
   }
  use Date::Calc qw(check_date);
  if(check_date($y,$m,$d)){
		$m='0'.$m if length($m) == 1 ;
		$d='0'.$d if length($d) == 1 ;
		return  "$y-$m-$d" if($delim eq '-');
    return  "'$y/$m/$d'";
  }
  else {
    return ("ERROR:Please check the date you entered");
  }
}


sub get_product {
    my($Data,$id) = @_;

    my $realmID=$Data->{'Realm'} || 0;
    my $target=$Data->{'target'};

my $entityTypeID = $Data->{'currentLevel'};
    my $entityID = getID($Data->{'clientValues'}, $entityTypeID);

    my $st=qq[
			SELECT 	
				P.intProductID, 	
				P.strName, 	
				P.intEntityID, 	
				P.curDefaultAmount, 	
				P.intMinChangeLevel, 	
				P.intMinSellLevel, 	
				P.intCreatedLevel, 	
				PP.curAmount, 	
				P.intCreatedID, 	
				P.strGroup, 	
				P.strProductNotes, 	
				P.intMandatoryProductID, 	
				P.intAllowMultiPurchase, 	
				P.intInactive, 	
				P.intAllowQtys, 	
				P.intPaymentSplitID,
				P.intProductGender,
				P.intSetMemberActive,
				P.intSetMemberFinancial,
				P.dtMemberExpiry,
				P.dtProductExpiry,
				P.intMemberExpiryDays,
				P.intProductExpiryDays,
				P.intSeasonPlayerFinancial,
				P.intSeasonCoachFinancial,
				P.intSeasonUmpireFinancial,
				P.intSeasonOther1Financial,
				P.intSeasonOther2Financial,
				P.intSeasonMemberPackageID,
				P.intProductSeasonID,
				P.dtDateAvailableFrom,
				P.dtDateAvailableTo,
				DATE(dtDateAvailableFrom) AS DateAvailableFrom,
				TIME(dtDateAvailableFrom) AS TimeAvailableFrom,
				DATE(dtDateAvailableTo) AS DateAvailableTo,
				TIME(dtDateAvailableTo) AS TimeAvailableTo,
				intProductMemberPackageID,
			  strGSTText,
              P.strLMSCourseID,
				PP.intPricingType,
				PP.curAmount_Adult1,
				PP.curAmount_Adult2,
				PP.curAmount_Adult3,
				PP.curAmount_AdultPlus,
				PP.curAmount_Child1,
				PP.curAmount_Child2,
				PP.curAmount_Child3,
				PP.curAmount_ChildPlus,
				PR.strRenewText1,
				PR.strRenewText2,
				PR.strRenewText3,
				PR.strRenewText4,
				PR.strRenewText5,
				PR.intRenewDays1,
				PR.intRenewDays2,
				PR.intRenewDays3,
				PR.intRenewDays4,
				PR.intRenewDays5,
				PR.intRenewProductID,
				PR.intRenewRegoFormID,
				PPR.curAmountMin,
				PPR.curAmountMax,
				OPP.intPricingType as intOriginalPricingType
	FROM 
				tblProducts as P 
					LEFT JOIN tblProductPricing as PP 
						ON (
							PP.intProductID = P.intProductID 
							AND PP.intID = $entityID
							AND PP.intLevel = $Data->{'clientValues'}{'currentLevel'} 
							AND PP.intRealmID = $realmID
						)
					LEFT JOIN tblProductRenew AS PR
						ON PR.intProductID = P.intProductID
				    LEFT JOIN tblProductPriceRange AS PPR
				        ON PPR.intProductID = P.intProductID
				    LEFT JOIN tblProductPricing as OPP 
                        ON (
                            OPP.intProductID = P.intProductID 
                            AND OPP.intLevel = P.intCreatedLevel 
                            AND OPP.intRealmID = P.intRealmID
                        )

			WHERE P.intRealmID = $realmID
				AND P.intProductID= $id
			LIMIT 1
		];

    my $query = $Data->{'db'}->prepare($st);
    $query->execute();
    my $dref=$query->fetchrow_hashref();
    $query->finish();
		$dref->{'curAmount'} = '' if $dref->{'curAmount'} eq '0.00';
		$dref->{'curDefaultAmount'} = '' if $dref->{'curDefaultAmount'} eq '0.00';
		$dref->{'intPricingType'} ||= 0;

    return $dref;
}


sub product_apply_transaction {
    my ($Data,$transLogID) = @_;
    my $db = $Data->{db};
    
    return if !$transLogID;
    my $st = qq[
			SELECT 
                T.intProductID,
                T.intTableType,
                T.intID,
                P.intCanResetPaymentRequired,
                T.intPersonRegistrationID,
                T.intStatus
			FROM tblTransactions as T
                INNER JOIN tblProducts as P ON (P.intProductID=T.intProductID)
			WHERE T.intTransLogID = ?
				AND T.intTableType = 1
		];
    my $q = $db->prepare($st);
    $q->execute($transLogID);
    
    my $stUPD= qq[
        UPDATE tblPersonRegistration_$Data->{'Realm'} 
        SET 
            intPaymentRequired = 0,
            intIsPaid=1
        WHERE 
            intPersonID = ?
            AND intPersonRegistrationID = ?
        LIMIT 1
    ];
    my $qUPD = $db->prepare($stUPD);

   my $stUPDEntity= qq[
        UPDATE tblEntity
        SET 
            intPaymentRequired = 0,
            intIsPaid=1
        WHERE 
            intEntityID = ?
    ];
    my $qUPDEntity = $db->prepare($stUPDEntity);
   

    while( my ($productID,$tableType, $ID, $resetPaymentReq, $personRegoID, $txnStatus) = $q->fetchrow_array())	{
        apply_product_rules($Data,$productID,$ID,$transLogID);
        next if (! $ID or ! $productID or $txnStatus != 1 or ! $resetPaymentReq);
        if ($tableType = $Defs::LEVEL_PERSON and $personRegoID) {
            $qUPD->execute($ID, $personRegoID);
        }
        if ($tableType >= $Defs::LEVEL_CLUB) {
            $qUPDEntity->execute($ID);
        }
    }
    $q->finish();

    return;
}


sub apply_product_rules {
    my ($Data,$productID,$personID,$transID) = @_;
        
    
    # For each product purchased apply appropriate rules.
    #foreach my $id(@{$IDs}){
    my $product = get_product($Data,$productID);
    my $dtStart = 'NULL';
    my $dtEnd = 'NULL';
    
    # Let's check and see if the product has a number of days until it expires or an expiry date.
    # If intProductExpiryDays is set we use this to calculate the expiry date,
    # otherwise we use the dtProductExpiry.
    #intProductExpiryDays: 0
    #intMemberExpiryDays: 0
    #dtProductExpiry: NULL
    #dtMemberExpiry: 2010-03-31 00:00:00
    {
			# Work out if there is a renewal product to get existing time from
			my $st = qq[
				SELECT 
					T.intTransactionID
				FROM
					tblTransactions AS T
					INNER JOIN tblProductRenew AS PR
						ON PR.intProductID = T.intProductID

				WHERE 
					PR.intRenewProductID = ?
					AND T.dtEnd > DATE_SUB(SYSDATE(), INTERVAL 100 DAY)
					AND T.dtPaid > '1970-01-01'
					AND T.intTableType = $Defs::LEVEL_PERSON
					AND T.intID = ?
				ORDER BY T.dtEnd
				LIMIT 1
			];
			my $q = $Data->{'db'}->prepare($st);
			$q->execute(
				$productID,
				$personID,
			);
			my($tid_to_be_renewed) = $q->fetchrow_array();
			$q->finish();
			if($tid_to_be_renewed)	{
				my $st_u = qq[
					UPDATE tblTransactions
					SET intRenewed = ?
					WHERE intTransactionID = ?
				];
				my $q_u = $Data->{'db'}->prepare($st_u);
				$q_u->execute(
					$transID,
					$tid_to_be_renewed,
				);
				$q_u->finish();
			}
		}
   
    if($product->{intProductExpiryDays} > 0){
        $dtStart = 'SYSDATE()';
				{
					# Work out if there is a renewal product to get existing time from
					my $st = qq[
						SELECT 
							MAX(T.dtEnd)
						FROM
							tblTransactions AS T
							INNER JOIN tblProductRenew AS PR
								ON PR.intProductID = T.intProductID

						WHERE 
							PR.intRenewProductID = ?
							AND T.dtEnd > SYSDATE()
							AND T.dtPaid > '1970-01-01'
							AND T.intTableType = $Defs::LEVEL_PERSON
							AND T.intID = ?
					];
					my $q = $Data->{'db'}->prepare($st);
					$q->execute(
						$productID,
						$personID,
					);
					my($dt) = $q->fetchrow_array();
					$q->finish();
					if($dt and $dt ne '0000-00-00 00:00:00')	{
						$dtStart = "DATE_ADD('$dt', INTERVAL 1 DAY)";
					}
				}
        $dtEnd = "DATE_ADD($dtStart, INTERVAL $product->{intProductExpiryDays} DAY)";
    }
    elsif($product->{dtProductExpiry}){
        $dtStart = 'SYSDATE()';
        $dtEnd = "'$product->{dtProductExpiry}'";
    }
    
    # Update the Transactions table with the transaction start and end dates.
    my $query = qq[
                       UPDATE tblTransactions
                       SET dtStart = $dtStart, dtEnd = $dtEnd
                       WHERE intProductID = $productID
                       AND intTransLogID = $transID
                   ];
    
    
    #if($dtStart ne 'NULL' || $dtEnd ne 'NULL'){
    #print STDERR $query;
    
    $Data->{'db'}->do($query);
    #}
    
    # Update the Member_Associations table.
    # - Check if we should set the members financial status or registered until date.
    my %ColumnsValues = ();
    my $query2 = qq[
                        UPDATE tblPerson_Associations SET
                        ];
    
    if ($product->{intProductMemberPackageID}) {
        $ColumnsValues{'intMemberPackageID'} = $product->{intProductMemberPackageID};
        $ColumnsValues{'dtLastRegistered'} = qq[NOW()];
        $ColumnsValues{'dtFirstRegistered'} = qq[IF(dtFirstRegistered, dtFirstRegistered, NOW())];
    }
    
    if($product->{intSetMemberFinancial}){
        $ColumnsValues{'intFinancialActive'} = 1;
    }
    if($product->{intSetMemberActive}){
        $ColumnsValues{'intRecStatus'} = 1;
    }
    
    
    if($product->{intMemberExpiryDays} > 0) {
        $ColumnsValues{'dtRegisteredUntil'} = 'DATE_ADD(SYSDATE(), INTERVAL ' . $product->{intMemberExpiryDays} . ' DAY)';
        }
    elsif($product->{dtMemberExpiry} and $product->{dtMemberExpiry} ne '0000-00-00 00:00:00' and $product->{dtMemberExpiry} ne '0000-00-00' ){
        $ColumnsValues{'dtRegisteredUntil'} = "'$product->{dtMemberExpiry}'";
    }
    
    if(scalar (keys %ColumnsValues)) {
        while(my ($column, $value) = (each %ColumnsValues)){
            $query2 .= "$column = $value,";
        }
        $query2 =~s/\,$//;
        $query2 .= " WHERE intPersonID = $personID ";
        
        $Data->{'db'}->do($query2);
    }

    warn("PERSON REGO RECORD HERE ?");

}

sub getFormProductAttributes {
    my (
        $Data,
        $formID
    ) = @_;
    
    my @product_list;
    my %AttributeValues=();
    
    # Select products at the node level
    my $node_search_sql = qq[
        SELECT
            intProductID
        FROM
            tblRegoFormProducts
        WHERE
            intRegoFormID = ?
    ];
    
    my $node_search_sth = $Data->{'db'}->prepare($node_search_sql);
    $node_search_sth->execute($formID);
    my $node_products = $node_search_sth->fetchall_arrayref([0]);
    
    foreach my $ref ( @$node_products){
        push @product_list, $ref->[0];
    }
    
    # Select added products at assoc or club level
    my $added_search_sql = qq[
        SELECT
            intProductID
        FROM
            tblRegoFormProductsAdded
        WHERE
            intRegoFormID = ?
            AND intClubID = ?
    ];
    my $added_search_sth = $Data->{'db'}->prepare($added_search_sql);
    
    my $clubID = $Data->{'clientValues'}{'clubID'}>0 ? $Data->{'clientValues'}{'clubID'} : 0;
    
    $added_search_sth->execute($formID, $clubID);
    
    my $added_products = $added_search_sth->fetchall_arrayref([0]);
    
    foreach my $ref ( @$added_products){
        push @product_list, $ref->[0];
    }
    
    # Get product attributes for our list of products
    if (@product_list){
        my $products_where = join (', ', map{'?'} @product_list );
        my $query = qq[
            SELECT 
                intProductID,
                intAttributeType,
                strAttributeValue 
            FROM 
                tblProductAttributes
            WHERE 
                intProductID in ( $products_where )
        ];
        my $sth = $Data->{'db'}->prepare($query);
        $sth->execute(@product_list);
        
        while (my ($pID, $type, $value) = $sth->fetchrow_array()) {
            push @{$AttributeValues{$pID}{$type}},$value;
        }
    }
    return \%AttributeValues;
}

sub updateProductTXNPricing {

    my ($db, $entityID, $productID, $amount) = @_;

    $productID || return 0;
    $entityID || return 0;
    $amount || return 0;

    my $st = qq[
        UPDATE
            tblTransactions
        SET
            curAmount= ?
        WHERE
            intProductID= ?
            AND intEntityID= ?
            AND intStatus=0
            AND curAmount=0
            AND dtTransaction <= DATE_ADD(CURRENT_DATE(), INTERVAL -15 MINUTE)
    ];
		my $q= $db->prepare($st);
		$q->execute(
			$amount,
			$productID,
			$entityID,
		);
		$q->finish();
}

sub updateProductRangePricing {

    my ($db, $productID, $curAmountMin, $curAmountMax) = @_;

    $productID || return 0;

    my $st = qq[
        INSERT INTO tblProductPriceRange (intProductID, curAmountMin, curAmountMax)
        VALUES ( ?, ?, ? )
        ON DUPLICATE KEY UPDATE 
            intProductID = VALUES(intProductID), 
            curAmountMin = VALUES(curAmountMin),
            curAmountMax = VALUES(curAmountMax)
        
    ];
    my $query = $db->prepare($st);
    $query->execute(
        $productID,
        $curAmountMin,
        $curAmountMax
    );  
    
    return 1;
}

sub getMinPrice	{
	my ($dref) = @_;

	my $intPricingType = 0;
	my $curAmount = 0;
	my $curAmount_Adult1 = 0;
	my $curAmount_Adult2 = 0;
	my $curAmount_Adult3 = 0;
	my $curAmount_AdultPlus = 0;
	my $curAmount_Child1 = 0;
	my $curAmount_Child2 = 0;
	my $curAmount_Child3 = 0;
	my $curAmount_ChildPlus  = 0;

	if($dref)	{
	
		$intPricingType = $dref->{'intPricingType'} || 0;
		$curAmount = $dref->{'curAmount'} || $dref->{'amount'} || 0;
		$curAmount_Adult1 = $dref->{'curAmount_Adult1'} || 0;
		$curAmount_Adult2 = $dref->{'curAmount_Adult2'} || 0;
		$curAmount_Adult3 = $dref->{'curAmount_Adult3'} || 0;
		$curAmount_AdultPlus = $dref->{'curAmount_AdultPlus'} || 0;
		$curAmount_Child1 = $dref->{'curAmount_Child1'} || 0;
		$curAmount_Child2 = $dref->{'curAmount_Child2'} || 0;
		$curAmount_Child3 = $dref->{'curAmount_Child3'} || 0;
		$curAmount_ChildPlus  = $dref->{'curAmount_ChildPlus'} || 0;
	}
	else	{
		$intPricingType = param('intPricingType') || 0;
		$curAmount = param('curAmount') || param('amount') || 0;
		$curAmount_Adult1 = param('curAmount_Adult1') || 0;
		$curAmount_Adult2 = param('curAmount_Adult2') || 0;
		$curAmount_Adult3 = param('curAmount_Adult3') || 0;
		$curAmount_AdultPlus = param('curAmount_AdultPlus') || 0;
		$curAmount_Child1 = param('curAmount_Child1') || 0;
		$curAmount_Child2 = param('curAmount_Child2') || 0;
		$curAmount_Child3 = param('curAmount_Child3') || 0;
		$curAmount_ChildPlus  = param('curAmount_ChildPlus') || 0;
	}
	if($intPricingType == 1)	{
		my @values = sort ( $curAmount_Adult1, $curAmount_Adult2, $curAmount_Adult3, $curAmount_AdultPlus, $curAmount_Child1, $curAmount_Child2, $curAmount_Child3, $curAmount_ChildPlus);
		return $values[0];	
	}
	return $curAmount;
}

sub HTML_breadcrumbs {
    my @html_links;

    while ( my $link_params = shift ) {
        push @html_links, HTML_link( @{ $link_params } );
    }

    my $cgi = new CGI;

    return $cgi->div(
        { -class => 'config-bcrumbs', },
        join('&nbsp;&raquo;&nbsp;', grep(/^.+$/, @html_links)),
    ) ;
}

sub getTimeFieldValue {
  my ($prefix) = @_;

  my $h = param($prefix . '_h') || '';
  my $m = param($prefix . '_m') || '';
	my $s = '00';

  if($h eq '' && $m eq ''){
    return 'NULL'; # No time supplied.
  }

	$h = 0 if $h > 59;
	$m = 0 if $m > 59;
	$m='0'.$m if length($m) == 1 ;
	$h='0'.$h if length($h) == 1 ;
	return  "$h:$m:$s";
}

sub update_product_renew_fields	{
	my(
		$Data,
		$db,
		$prodID,
	) = @_;

	my %vals = ();
	for my $i (1 ..5)	{
		my $days = param('d_intRenewDays'.$i) || 0;
		my $dir = param('d_renew_dir_'.$i) || 'before';
		if($dir eq 'after')	{
			$days *= -1;
		}
		$vals{'intRenewDays'.$i} = $days || 0;
	}

	my $st = qq[
		INSERT INTO tblProductRenew (
			intProductID,
			strRenewText1,
			strRenewText2,
			strRenewText3,
			strRenewText4,
			strRenewText5,
			intRenewDays1,
			intRenewDays2,
			intRenewDays3,
			intRenewDays4,
			intRenewDays5,
			intRenewProductID,
			intRenewRegoFormID
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?
		)
		ON DUPLICATE KEY UPDATE
			strRenewText1 = ?,
			strRenewText2 = ?,
			strRenewText3 = ?,
			strRenewText4 = ?,
			strRenewText5 = ?,
			intRenewDays1 = ?,
			intRenewDays2 = ?,
			intRenewDays3 = ?,
			intRenewDays4 = ?,
			intRenewDays5 = ?,
			intRenewProductID = ?,
			intRenewRegoFormID = ?
	];
	my $q = $db->prepare($st);
	$q->execute(
		$prodID,
		param('d_strRenewText1') || '',
		param('d_strRenewText2') || '',
		param('d_strRenewText3') || '',
		param('d_strRenewText4') || '',
		param('d_strRenewText5') || '',
		$vals{'intRenewDays1'} || 0,
		$vals{'intRenewDays2'} || 0,
		$vals{'intRenewDays3'} || 0,
		$vals{'intRenewDays4'} || 0,
		$vals{'intRenewDays5'} || 0,
		param('d_intRenewProductID') || $prodID,
		param('d_intRenewRegoFormID') || 0,

		param('d_strRenewText1') || '',
		param('d_strRenewText2') || '',
		param('d_strRenewText3') || '',
		param('d_strRenewText4') || '',
		param('d_strRenewText5') || '',
		$vals{'intRenewDays1'} || 0,
		$vals{'intRenewDays2'} || 0,
		$vals{'intRenewDays3'} || 0,
		$vals{'intRenewDays4'} || 0,
		$vals{'intRenewDays5'} || 0,
		param('d_intRenewProductID') || $prodID,
		param('d_intRenewRegoFormID') || 0,

	);

}

sub copy_product {
	my ($Data, $id) = @_;

	my $intID = getID($Data->{'clientValues'}) || 0;

	my $db_err_msg  =  '<div class="warningmsg">There was a problem creating the new product</div>';
	my $db_err_msg2 =  '<div class="warningmsg">There was a problem creating the supplmentary details for the new product</div>';

    my $products_st = qq[
        INSERT INTO tblProducts (
            intEntityID,
            intMinSellLevel,
            intRealmID,
            strName,
            curDefaultAmount,
            intCreatedLevel,
            intCreatedID,
            strProductNotes,
            strGroup,
            intMandatoryProductID,
            intAllowMultiPurchase,
            intInactive,
            intAllowQtys,
            intSetMemberActive,
            intSetMemberFinancial,
            dtMemberExpiry,
            dtProductExpiry,
            intMemberExpiryDays,
            intProductExpiryDays,
            intProductGender,
            intProductMemberPackageID,
            strGSTText,
            intMinChangeLevel,
            intSeasonPlayerFinancial,
            intSeasonCoachFinancial,
            intSeasonUmpireFinancial,
            intSeasonOther1Financial,
            intSeasonOther2Financial,
            intSeasonMemberPackageID,
            intProductSeasonID,
            dtDateAvailableFrom,
            dtDateAvailableTo,
            intPaymentSplitID
        )
        SELECT
            intEntityID,
            intMinSellLevel,
            intRealmID,
            CONCAT(strName, ' (Copy)'),
            curDefaultAmount,
            $Data->{'clientValues'}{'currentLevel'},
            $intID,
            strProductNotes,
            strGroup,
            intMandatoryProductID,
            intAllowMultiPurchase,
            intInactive,
            intAllowQtys,
            intSetMemberActive,
            intSetMemberFinancial,
            dtMemberExpiry,
            dtProductExpiry,
            intMemberExpiryDays,
            intProductExpiryDays,
            intProductGender,
            intProductMemberPackageID,
            strGSTText,
            intMinChangeLevel,
            intSeasonPlayerFinancial,
            intSeasonCoachFinancial,
            intSeasonUmpireFinancial,
            intSeasonOther1Financial,
            intSeasonOther2Financial,
            intSeasonMemberPackageID,
            intProductSeasonID,
            dtDateAvailableFrom,
            dtDateAvailableTo,
            intPaymentSplitID
        FROM tblProducts
        WHERE intProductID=$id
    ];
    
    my $products_query = $Data->{'db'}->prepare($products_st);
    $products_query->execute() || return ($db_err_msg);
    my $new_id = $products_query->{mysql_insertid} || 0;
    
    my $dependencies_st = qq[
        INSERT INTO tblProductDependencies (
            intProductID, 
            intDependentProductID, 
            intRealmID, 
            intID, 
            intLevel
        )
        SELECT
            $new_id, 
            intDependentProductID, 
            intRealmID, 
            $intID, 
            $Data->{'clientValues'}{'currentLevel'}
        FROM tblProductDependencies
        WHERE intProductID=$id AND intID=$intID AND intLevel=$Data->{'clientValues'}{'currentLevel'}
    ];

    my $attributes_st = qq[
        INSERT INTO tblProductAttributes (
            intProductID,
            intAttributeType,
            strAttributeValue,
            intRealmID,intID,
            intLevel
        )
        SELECT
            $new_id,
            intAttributeType,
            strAttributeValue,
            intRealmID,
            $intID,
            $Data->{'clientValues'}{'currentLevel'}
        FROM tblProductAttributes
        WHERE intProductID=$id AND intID=$intID AND intLevel=$Data->{'clientValues'}{'currentLevel'}
    ];
    
    my $pricing_st = qq[
        INSERT INTO tblProductPricing (
            curAmount, 
            intProductID, 
            intRealmID, 
            intID, 
            intLevel,
            intPricingType,
            curAmount_Adult1,
            curAmount_Adult2,
            curAmount_Adult3,
            curAmount_AdultPlus,
            curAmount_Child1,
            curAmount_Child2,
            curAmount_Child3,
            curAmount_ChildPlus
        )
        SELECT
            curAmount, 
            $new_id,
            intRealmID, 
            $intID, 
            $Data->{'clientValues'}{'currentLevel'},
            intPricingType,
            curAmount_Adult1,
            curAmount_Adult2,
            curAmount_Adult3,
            curAmount_AdultPlus,
            curAmount_Child1,
            curAmount_Child2,
            curAmount_Child3,
            curAmount_ChildPlus
        FROM tblProductPricing
        WHERE intProductID=$id AND intID=$intID AND intLevel=$Data->{'clientValues'}{'currentLevel'}
    ];
    

    my $dependencies_query = $Data->{'db'}->prepare($dependencies_st);
    my $attributes_query = $Data->{'db'}->prepare($attributes_st);

    auditLog($new_id, $Data, 'Copy', 'Products');

    my $pricing_query = $Data->{'db'}->prepare($pricing_st);

    my $db_errors = 0;

    $dependencies_query->execute();
    $db_errors++ if $DBI::err;

    $attributes_query->execute();
    $db_errors++ if $DBI::err;

    $pricing_query->execute();
    $db_errors++ if $DBI::err;

    $products_query->finish;
    $dependencies_query->finish;
    $attributes_query->finish;
    $pricing_query->finish;

    return ($db_err_msg2, 0) if $db_errors;

	return (qq[<div class="OKmsg">The product has been successfully copied</div>], $id);
}


1;
