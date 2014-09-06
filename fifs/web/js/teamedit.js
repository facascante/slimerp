function setup_team_selection(assocID, compID, teamID, client)	{
	load_available_players(assocID, compID, teamID, client);
	load_selected_players(assocID, compID, teamID, client);
	jQuery(document).on('click','.aplayer_item', function()	{
		var playerfamilyname = jQuery(this).attr('data-familyname');
		var playerfirstname = jQuery(this).attr('data-firstname');
		var playerID = jQuery(this).attr('data-playerid');
		var playing_number = jQuery(this).attr('data-playing_number');
		var position = jQuery(this).attr('data-pos');
		var permit = jQuery(this).attr('data-permit');
		var finals_qualified = jQuery(this).attr('data-finals_qualified');
		if(jQuery(this).hasClass('aplayer_item_selected'))	{
			jQuery(this).removeClass('aplayer_item_selected');
			jQuery('#splayer_item_' + playerID).remove();
		}
		else	{
			jQuery(this).addClass('aplayer_item_selected');
			var str = createSelectedRecord(
				playerfamilyname,
				playerfirstname,
				playerID,
				teamID
			);
			jQuery('#splayers_container').append(str);
			rescan_selected();
		}
	});
	jQuery(document).on('click','.splayer_item_del' , function() {
		jQuery(this).parent().remove();
		rescan_selected();
	});

	jQuery('#availableCompFilter').change(function() {
		 compID = jQuery(this).val();
         load_selected_players(assocID, compID, teamID, client);
	});

    jQuery('#save_splayer').click(function() {
        saveplayers(assocID, compID, teamID, client);
    });

	jQuery('.search_options').change(function() {
	    load_available_players(assocID, compID, teamID, client);
	});

};

function filter_available()	{
	var searchval = jQuery('#aplayer_search_field').val();
	var re = new RegExp(searchval,"i");
	jQuery('.apl_name').each(function()	{
		var parent_ele = jQuery(this).parent();
		if(!jQuery(parent_ele).hasClass('aplayer_item_selected'))	{
			if(!re.test(jQuery(this).html()))	{
				parent_ele.hide();
			}
			else	{
				parent_ele.css('display','');
			}
		}
	});
}

function load_available_players(assocID, compID, teamID, client)	{
	var filterval = jQuery('[name="availp_opt"]:checked').val();
	var seasonFilterval = jQuery('#seasonFilter option:selected').val(); 
	var ageGroupFilterval = jQuery('#ageGroupFilter option:selected').val();
	var genderFilterval = jQuery('#genderFilter option:selected').val();
	var dobFromval = jQuery('#dobFrom').val();
	var dobToval = jQuery('#dobTo').val();
	jQuery('#loading').fadeIn('fast');
	var noCache = new Date().getTime(); //will give you to the ms
	
	jQuery.getJSON("ajax/aj_team_available_players.cgi", { assocID: assocID, compID: compID, teamID: teamID, client: client, seasonFilter: seasonFilterval, ageGroupFilter: ageGroupFilterval, genderFilter:genderFilterval, dobFrom: dobFromval, dobTo: dobToval, filteropt: filterval, "noCache": noCache }, function(json)	{
		var items = [];
	
	jQuery.each(json.players, function(index, player) {
//			items.push('<li id="ap_pID_' + player.id + '" class =" aplayer_item aplayer_item" data-natnum = "' + player.natnum + '" data-pos = "' + player.pos + '" data-permit = "' + player.permit + '" data-playing_number = "' + player.playing_number + '" data-familyname = "' + player.familyname + '" data-playerid = "' + player.id + '" data-firstname = "' + player.firstname + '" data-finals_qualified= "' + player.finals_qualified + '">' + '<span class = "apl_name">' + player.familyname + ', ' + player.firstname + '</span> <span class = "apl_dob">(' + player.dobFormatted + ')</span>' + ' <span class = "apl_num">(' + player.natnum + ')</span>' + player.permit + ' ' + player.finals_qualified + '</li>');
			items.push('<li id="ap_pID_' + player.id + '" class =" aplayer_item aplayer_item" data-natnum = "' + player.natnum + '" data-pos = "' + player.pos + '" data-permit = "' + player.permit + '" data-playing_number = "' + player.playing_number + '" data-familyname = "' + player.familyname + '" data-playerid = "' + player.id + '" data-firstname = "' + player.firstname + '">' + '<span class = "apl_name">' + player.familyname + ', ' + player.firstname + '</span> <span class = "apl_dob">(' + player.dobFormatted + ')</span>' + '</li>');
		});
		jQuery('#aplayers').html(items.join(''));
		rescan_selected();
		jQuery('#loading').fadeOut('fast');
	});
	jQuery('#aplayer_search_clear').click(function(){
		jQuery('#aplayer_search_field').val('');
		filter_available();
		return false;
	});
	jQuery('#aplayer_search_field').keyup(function(){
		filter_available();
	});
}

function load_selected_players(assocID, compID, teamID, client, skipFade)	{
	var filterval = jQuery('[name="selp_opt"]:checked').val();
	var selected_str = '';
	var noCache = new Date().getTime(); //will give you to the ms
	jQuery.getJSON("ajax/aj_team_selected_players.cgi", { assocID: assocID, compID: compID, teamID: teamID, client: client, filteropt: filterval, "noCache": noCache }, function(json)	{
		var items = [];
		var posnames = [];
		jQuery.each(json.players, function(index, player) {
			var str = createSelectedRecord(
				player.familyname,
				player.firstname,
				player.id,
				teamID
			);
			selected_str = selected_str + str;
		});
		jQuery('#splayers_container').html(selected_str);
		rescan_selected();
	});
}

function createSelectedRecord(
		playerfamilyname,
		playerfirstname,
		playerID,
		teamID
)	
{
	var str = '<div class = "splayer_item splayer_row" id = "splayer_item_' + playerID + '" data-firstname = "' + playerfirstname + '" data-familyname = "' + playerfamilyname + '">';
	str = str + '<span class="splayer_name"><span class ="splayer_familyname">' + playerfamilyname + '</span>, ';
	str = str + '<span class ="splayer_firstname">' + playerfirstname + '</span></span>';
	str = str + '<span class = "splayer_item_del delete-btn"><img src="images/remove.png"></span>';
	str = str + '</div>';
	return str;
}

function rescan_selected()	{
	jQuery('.aplayer_item').removeClass('aplayer_item_selected');
	jQuery('#splayers_container .splayer_item').each(function(index, obj)	{
		var id = jQuery(obj).attr('id');
		var newid = id.replace(/splayer_item/, 'ap_pID');
		jQuery('#' + newid).addClass('aplayer_item_selected');
		create_sort_key(obj);
	});
	jQuery('#splayers_container .splayer_item').tsort( {attr:'data-sortkey'});
}

function create_sort_key(obj)	{
	var playerfamilyname = jQuery(obj).attr('data-familyname');
	var playerfirstname = jQuery(obj).attr('data-firstname');
	var namewidth = 50;
	while(playerfirstname.length < namewidth)	{
		playerfirstname = playerfirstname + '0';
	}
	while(playerfamilyname.length < namewidth)	{
		playerfamilyname = playerfamilyname + '0';
	}
	var sortkey = playerfamilyname + ':' + playerfirstname;
	jQuery(obj).attr('data-sortkey', sortkey);
}

function saveplayers(assocID, compID, teamID, client)	{

	var items = [];
	var count = 0;
	jQuery('#splayers_container .splayer_item').each(function(index, obj)	{
		count++;
		var id = jQuery(obj).attr('id');
		var newid = id.replace(/splayer_item/, 'spl');
		items.push(newid + '=' + newid );
	});
	var savestring = items.join('|');
	jQuery('#loading').fadeIn('fast');
	var noCache = new Date().getTime(); //will give you to the ms
    jQuery.ajax({
		url: "ajax/aj_save_players.cgi", 
		data: { assocID: assocID, compID: compID, teamID: teamID, client: client, playerdata: savestring, "noCache": noCache},
		cache: false,
		type: 'POST',
		dataType: 'json',
		success: function(json)	{
			if(json.result == 'ok')	{
				var alertText = 'Player Selection saved\n';
				if (json.warnings)	{
					alertText = "\n\n\n" + alertText + json.warnings;
				}
				alert(alertText);
			}
			jQuery('#loading').fadeOut('fast');
		}
	});
}


