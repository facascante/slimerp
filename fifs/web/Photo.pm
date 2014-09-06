#
# $Header: svn://svn/SWM/trunk/web/Photo.pm 9237 2013-08-16 06:03:00Z cregnier $
#

package Photo;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_photo);
@EXPORT_OK = qw(handle_photo);

use strict;
use lib "..",".";
use Defs;
use Utils;

use ImageUpload;
use FileUpload;
use CGI qw(:cgi param unescape escape);
use Reg_common;
use AuditLog;
use MIME::Base64;

sub handle_photo	{
	my($action, $Data, $memberID, $returnlink, $otherformdata, $tempfilename, $fromRegoForm)=@_;
  my $resultHTML='';
	$fromRegoForm ||= 0;
	
	$returnlink ||=param('ra') || '';
  my $assocID= $Data->{'clientValues'}{'assocID'} || -1;
	return ('No Member or Association Specified','','') if !$memberID or !$assocID;
	my $newaction='';
  my $client=setClient($Data->{'clientValues'}) || '';

  my $type = '';

  if ($action eq 'M_PH_s') {
    $resultHTML = show_photo($Data,$memberID,$client, $returnlink);
  }
  elsif ($action eq 'M_PH_n') {
    $resultHTML = new_photo($Data,$memberID,$client, $returnlink, $otherformdata, $tempfilename, $fromRegoForm);
  }
  elsif ($action eq 'M_PH_u') {
    $resultHTML = process_upload($Data, $memberID,$client, $tempfilename, $fromRegoForm);
    $type = 'Upload Photo';
  }
  elsif ($action eq 'M_PH_cr') {
    ($resultHTML, $newaction) = crop_photo($Data, $memberID,$client, $returnlink, $tempfilename, $fromRegoForm);
    $type = 'Crop Photo';
  }
  elsif ($action =~/^M_PH_r/) {
    $resultHTML = rotate_photo($Data, $memberID,$client, $action, $returnlink, $tempfilename);
    $type = 'Rotate Photo';
  }
  elsif ($action eq 'M_PH_d') {
    $resultHTML = do_delete('Photo Deleted', $Data->{'db'}, $memberID, $tempfilename);
    $resultHTML .= new_photo($Data,$memberID,$client);
    $type = 'Delete Photo';
  }
	if($tempfilename and $newaction and $fromRegoForm)	{
		my $imgURL = "getphoto.cgi?client=$client&amp;t=0&amp;tf=$tempfilename";

		$resultHTML = qq~ 
			<script>
			jQuery(document).ready(function () {
					jQuery(parent.document).find('#photoupload_result').html('<img src="$imgURL">');
					jQuery(parent.document).find('input[name=d_PhotoUpload]').val('$tempfilename');
					window.parent.jQuery('#photoupload_form').dialog('close');
			});
			</script>
		~;
	}

  if ($type and !$tempfilename) {
    auditLog($memberID, $Data, $type, 'Photo');
  }

	return ($resultHTML,'', $newaction);
}


sub show_photo	{
	my($Data, $memberID,$client, $returnlink)=@_;
	my $target=$Data->{'target'} || '';
	$returnlink||='';

	#First check if there is a photo
	my $statement = qq[
		SELECT intPhoto
		FROM tblMember
		WHERE intMemberID = ?
	];
	my $query = $Data->{'db'}->prepare($statement);
	$query->execute($memberID);
	my($hasphoto)=$query->fetchrow_array();
	$query->finish();

	if ($hasphoto) {

		my $photoopts;
        
		if ((allowedAction($Data, 'm_ep') and !$Data->{'MemberOnPermit'})) {

			my $replace_photo = $Data->{'lang'}->txt('Edit Photo');
			my $delete_photo  = $Data->{'lang'}->txt('Delete Photo');

			$photoopts = qq[
				<span class="button-small mobile-button"><a href="$target?client=$client&amp;a=M_PH_n">$replace_photo</a></span>  
				<span class="button-small mobile-button"><a href="$target?client=$client&amp;a=M_PH_d">$delete_photo</a></span>
			];
    }

		my $photo = $Data->{'lang'}->txt('Photo');
		my $PhotoHeight = $Data->{'SystemConfig'}{'PhotoHeightDisplay'} || $Data->{'SystemConfig'}{'PhotoHeight'} || 200;
		my $PhotoHeightstring = $PhotoHeight.'px';

		return qq[
<div class="mphoto">
  <div>
    <img src="getphoto.cgi?client=$client" class="memphoto" alt="$photo" style="height:$PhotoHeightstring;">
  </div>
  $photoopts
</div>
		];
	}
	else {

        if (
            allowedAction($Data, 'm_ep') and !$Data->{'MemberOnPermit'}
            or $Data->{'clientValues'}{'authLevel'}==$Defs::LEVEL_EVENT_ACCRED
        ) {
            my $no_photo_found = $Data->{'lang'}->txt('No Photo Found');
            my $add_photo      = $Data->{'lang'}->txt('Add Photo');


			return <<"EOS";
<div class="mphoto">
  <a href="$target?client=$client&amp;a=M_PH_n&amp;ra=$returnlink">
    <img src="images/add_photo_icon.gif" border="0" alt="$no_photo_found" title="$no_photo_found">
    <br>
    $add_photo
  </a>
</div>
EOS
		}
	}

	return q{};
}

sub new_photo	{
	my($Data, $memberID, $cl, $returnlink, $otherformdata, $tempfilename, $fromRegoForm)=@_;

  $cl = unescape($cl);

	$returnlink||='';
	$otherformdata||='';
	my $target=$Data->{'target'} || '';

  my $upload_photo = $Data->{'lang'}->txt('Save Photo');
  my $uploading    = $Data->{'lang'}->txt('Uploading');

  my $upload_photo_form_text
    = $Data->{'lang'}->txt($Data->{'SystemConfig'}{'txt_UPLOAD_PHOTO_FORM_TEXT'} || '')
    || $Data->{'lang'}->txt('UPLOAD_PHOTO_FORM_TEXT', $upload_photo);

  my $upload_time = $Data->{'lang'}->txt('The estimated time to upload a 400Kb image is');

  my $connection        = $Data->{'lang'}->txt('Connection');
  my $approx_time       = $Data->{'lang'}->txt('Approx. Time');
  my $minutes           = $Data->{'lang'}->txt('minutes');
  my $cable             = $Data->{'lang'}->txt('Cable');
  my $under_1_minute    = $Data->{'lang'}->txt('Under 1 minute');
  my $please_be_patient = $Data->{'lang'}->txt('Please be Patient');

  my $hide_webcam_tab = param('hwct') || '';

  my $body = '';
	if(!$fromRegoForm)	{
	  $body .=qq[ <div class="pageHeading">$upload_photo</div>];
	}

	$body .=qq[
<div id="photoselect">
  <p class="upload_form_text">$upload_photo_form_text</p>
  <form action="$target" method="POST" enctype="multipart/form-data">

	<script type="text/javascript" src="js/jquery.webcam/jquery.webcam.js" language="javascript"></script>
	<div id = "photo_tabs" style = "float:left;width:98%;">
  ];
  $body .= qq[
		<ul>
			<li><a href = "#webcam_div">Webcam</a></li>
			<li><a href = "#upload_div">File Upload</a></li>
		</ul>
  ] if !$hide_webcam_tab;
  $body .= qq[
		<div id = "webcam_div" >
			<div id = "nocams_div" class = "warningmsg">You do not have any webcams available. Click the 'File Upload' tab to upload an image file. </div>
			<div id="webcam" style = "float:left;"></div>
			<canvas id="canvas" height="600" width="600" style = "display:none;float:left;"></canvas>
			<div class = "photobuttons" style = "display:none;">
				<input id = "btn_snap" class="button generic-button" type = "button" onclick = "javascript:webcam.capture();void(0);" value = "Take Picture">
				<input id = "btn_reset" class="button cancel-button" type = "button" onclick = "" value = "Reset Picture" style = "display:none;">
			</div>
			<div style = "clear:both;"></div>
		</div>
  ]if !$hide_webcam_tab;
  $body .= qq[
		<div id = "upload_div">
			<input type="file" name="uploadfile" size="30">
			<p> Photos should be in JPEG (jpg) format and be less than 3Mb in size.</p>
		</div>
		</div>
		<div style = "clear:both;"></div>
    <input type="hidden" name="client" value="$cl">
    <input type="hidden" name="a" value="M_PH_u">
    <input type="hidden" name="tfn" value="$tempfilename">
    <input type="hidden" name="ra" value="$returnlink">
		<input type = "hidden" name = "rawimage" id="imageout" value = "">
    $otherformdata
    <input
      type="submit"
      name="submitb"
      value="$upload_photo"
			class = "button proceed-button"
      onclick="
        document.getElementById('photoselect').style.display='none';
        document.getElementById('pleasewait').style.display='block';
      "
    >
  </form>
</div>
    ];
		$body .=qq[
<div id="pleasewait" style="display:none;">
  <img src="images/spinning-wheel.gif" style="float:left;margin-right:10px;">
  <h3>$uploading ...</h3>
  <p>$upload_time</p>
  <table style="width:300px;">
    <tr><th>$connection</th><th>$approx_time</th></tr>
    <tr><td>56K</td><td>2-3 $minutes</td></tr>
    <tr><td>(A)DSL/$cable</td><td>$under_1_minute</td></tr>
  </table>
  <p><b>$please_be_patient</b></p>
</div>
].q~
<script type="text/javascript">
jQuery(function() {
	var pos = 0, ctx = null, saveCB, image = [];
	var canvas = document.getElementById("canvas");
  canvas.setAttribute('width', 600);
  canvas.setAttribute('height', 600);
	if (canvas.toDataURL) {
		ctx = canvas.getContext("2d");
		image = ctx.getImageData(0, 0, 600, 600);
		saveCB = function(data) {
			var col = data.split(";");
			var img = image;

			for(var i = 0; i < 600; i++) {
							var tmp = parseInt(col[i]);
							img.data[pos + 0] = (tmp >> 16) & 0xff;
							img.data[pos + 1] = (tmp >> 8) & 0xff;
							img.data[pos + 2] = tmp & 0xff;
							img.data[pos + 3] = 0xff;
							pos+= 4;
			}

			if (pos >= 4 * 600 * 600) {
							ctx.putImageData(img, 0, 0);
							jQuery('#imageout').val(canvas.toDataURL("image/jpg"));
							pos = 0;
			}
		};
	} 
	else {

		saveCB = function(data) {
						image.push(data);
						pos+= 4 * 600;
						if (pos >= 4 * 600 * 600) {
										jQuery('#imageout').val(image.join('|'));
										pos = 0;
						}
		};
	}

	function supports_canvas() {
		return !!document.createElement('canvas').getContext;
	}
	 
	function supportsToDataURL() {
		if(!supports_canvas()) {
			return false;
		}
	 
		var c = document.createElement("canvas");
		var data = c.toDataURL("image/png");
		return (data.indexOf("data:image/png") == 0);
	}
	 
	var photo_tabs = jQuery('#photo_tabs').tabs();
	if(supportsToDataURL()) {
		
		jQuery("#webcam").webcam({
						width: 600,
						height: 600,
						mode: "callback",
						swffile: "js/jquery.webcam/jscam.swf",

						onSave: saveCB,

						onCapture: function () {
								webcam.save();
						},
						onLoad: function() {
							var cams = webcam.getCameraList();
							if(cams)	{
								jQuery('.photobuttons').show();
								jQuery('#nocams_div').hide();
							}
						}
		});
	}


	jQuery('#btn_snap').click(function ()	{
		jQuery('#webcam').hide();
		jQuery('#canvas').show();
		jQuery('#btn_snap').hide();
		jQuery('#btn_reset').show();
	});
	jQuery('#btn_reset').click(function ()	{
		jQuery('#webcam').show();
		jQuery('#canvas').hide();
		jQuery('#btn_snap').show();
		jQuery('#btn_reset').hide();
	});
});
</script>
</div>
	~;
	return $body;
}

#'#

sub process_upload	{
	my($Data, $memberID, $client, $tempfile_prefix, $fromRegoForm)=@_;

	my $path='';
	my $orig_file = '';
	my $temp_file = '';
	$tempfile_prefix =~ /^([\da-zA-Z]+)$/;
	$tempfile_prefix = $1;
	
	if($memberID == -1000)	{
		$orig_file="$Defs::fs_upload_dir/temp/$tempfile_prefix.jpg";
		$temp_file="$Defs::fs_upload_dir/temp/$tempfile_prefix".'_temp.jpg';
	}
	else	{
		my $l=6 - length($memberID);
		my $pad_num=('0' x $l).$memberID;
		my (@nums)=$pad_num=~/(\d\d)/g;
		for my $i (0 .. $#nums-1) { 
			$path.="$nums[$i]/"; 
			if( !-d "$Defs::fs_upload_dir/$path") { mkdir "$Defs::fs_upload_dir/$path",0755; }
		}
		$orig_file="$Defs::fs_upload_dir/$path$memberID.jpg";
		$temp_file="$Defs::fs_upload_dir/$path$memberID".'_temp.jpg';
	}
	my $returnlink=param('ra') || '';
	my $newphotolink=new_photo($Data, $memberID, $client, $returnlink);
	my $returnlinkhtml=$returnlink ? qq[<br><br><a href="$Data->{'target'}?a=$returnlink&amp;client=$client">&lt; Return</a>] : '';
	$newphotolink.=$returnlinkhtml;
	my $imgtmp = undef;
	my $PhotoDPI = $Data->{'SystemConfig'}{'PhotoDPI'} || 0;
	if(param('rawimage'))	{
		my $raw= param('rawimage');
		$raw=~s/.*base64,//;
		open RAWFILE, ">$temp_file";
		print RAWFILE decode_base64($raw);
		close RAWFILE;
		$imgtmp=new ImageUpload(fieldname=>"$temp_file", existing => 1, filename=>$temp_file, overwrite=>1, maxsize=>3145728);
	}
	else	{
		$imgtmp=new ImageUpload(fieldname=>"uploadfile", filename=>$temp_file, overwrite=>1, maxsize=>3145728);
	}

	if($imgtmp->Error())	{return do_delete(q[<div class="warningmsg">Cannot create Upload temp object].$imgtmp->Error()."</div>".$newphotolink,$Data->{'db'},$memberID);}
	else	{
		my $ret=$imgtmp->ImageManip(Dimensions=>'2000x2000', DPI => $PhotoDPI);
		if($ret)	{ return do_delete(q[<div class="warningmsg">].$imgtmp->Error()."</div>".$newphotolink,$Data->{'db'},$memberID); }
		my $PhotoHeight=$Data->{'SystemConfig'}{'PhotoHeight'} || 200;
		my $PhotoWidth=$Data->{'SystemConfig'}{'PhotoWidth'} || 154;
		if($imgtmp->Height() < $PhotoHeight or $imgtmp->Width() < $PhotoWidth)	{
				return do_delete(
					q[<div class="warningmsg">The image uploaded is too small</div>].$newphotolink,
					$Data->{'db'},
					$memberID
				); 
		}
}


	my $img=new ImageUpload(fieldname=>"$temp_file", existing=>1, filename=>$orig_file, overwrite=>1, maxsize=>3145728);
	if($img->Error())	{return do_delete(q[<div class="warningmsg">Cannot create Upload object].$img->Error()."</div>".$newphotolink,$Data->{'db'},$memberID);}
	else	{
		my $PhotoHeight=$Data->{'SystemConfig'}{'PhotoHeight'} || 200;
		my $PhotoWidth=$Data->{'SystemConfig'}{'PhotoWidth'} || 154;

		my $ret=$img->ImageManip(Dimensions=>$PhotoWidth.'x'.$PhotoHeight, DPI => $PhotoDPI);
		if($ret)	{ 
			return do_delete(
				q[<div class="warningmsg">].$img->Error()."</div>".$newphotolink,
				$Data->{'db'},
				$memberID
			); 
		}
	}

	if(
		$memberID 
		and $memberID =~ /^\d+$/
	)	{
		my $statement=qq[
			UPDATE tblMember
			SET intPhoto=1
			WHERE intMemberID = ?
		];		
		my $q = $Data->{'db'}->prepare($statement);
		$q->execute(
			$memberID
		);
		$q->finish();
	}

	return $returnlinkhtml.edit_photo($Data, $memberID, $client, $returnlink, $tempfile_prefix, $fromRegoForm);
	#return $returnlinkhtml.show_photo($Data, $memberID, $client, $returnlink);
}

sub do_delete	{
	my($reason, $db, $memberID)=@_;
	my $mID=$memberID;
	$mID =~/^(\d+)$/;
	$mID =$1;
	if($mID)	{
		if($db)	{
			my $statement=qq[
				UPDATE tblMember
				SET intPhoto=0
				WHERE intMemberID= ? 
			];
			my $q = $db->prepare($statement);
			$q->execute(
				$memberID
			);
		}

		my $path='';
		{
			my $l=6 - length($mID);
			my $pad_num=('0' x $l).$mID;
			my (@nums)=$pad_num=~/(\d\d)/g;
			for my $i (0 .. $#nums-1) { $path.="$nums[$i]/"; }
		}

		my @tobedeleted=();
		#debug("DEL $Defs::fs_upload_dir/$path$mID.jpg");
		push @tobedeleted, "$Defs::fs_upload_dir/$path$mID.jpg";
		unlink @tobedeleted;
	}

	return $reason;
}

sub edit_photo	{
	my($Data, $memberID, $client, $returnlink, $tempfile_prefix, $fromregoform)=@_;

	$fromregoform ||= '';
	my $unesc_client=unescape($client) || '';

	my $PhotoHeight=$Data->{'SystemConfig'}{'PhotoHeight'} || 200;
	my $PhotoWidth=$Data->{'SystemConfig'}{'PhotoWidth'} || 154;

    my $modify   = $Data->{'lang'}->txt('Modify Photo');
    my $photo    = $Data->{'lang'}->txt('Photo');
    my $save     = $Data->{'lang'}->txt('Save');
    my $preview  = $Data->{'lang'}->txt('Preview');
    my $original = $Data->{'lang'}->txt('Original Photo');
    my $r_left   = $Data->{'lang'}->txt('Rotate Left');
    my $r_right  = $Data->{'lang'}->txt('Rotate Right');

    my $form_header = $Data->{'lang'}->txt(
        'MODIFY_PHOTO_FORM_HEADER',
        $save,
    );

    my $body = '';
		if(!$fromregoform)	{
			$body .= qq[ <div class="pageHeading">$modify</div>];
		}
		my $previewwidth = 150;
		my $previewheight = int(150*$PhotoHeight/$PhotoWidth);
    $body .= qq~
$form_header
    <script src="js/jcrop/jquery.Jcrop.min.js"></script>
    <link rel="stylesheet" href="js/jcrop/css/jquery.Jcrop.css" type="text/css">

    <script language="Javascript">

      // Remember to invoke within jQuery(window).load(...)
      // If you don't, Jcrop may not initialize properly
      jQuery(window).load(function(){

        jQuery('#cropbox').Jcrop({
          onChange: showPreview,
          onSelect: showPreview,
          bgColor: 'black',
					setSelect: [0,0,$PhotoWidth, $PhotoHeight],
					minSize: [$PhotoWidth, $PhotoHeight],
          aspectRatio: $PhotoWidth/$PhotoHeight,
					boxWidth:500
        });
      });

      function showPreview(coords) {
        var rx = $previewwidth / coords.w;
        var ry = $previewheight / coords.h;

				var img_height = jQuery("#cropbox").height();
				var img_width = jQuery("#cropbox").width();

        jQuery('#preview').css({
					width: Math.round(rx * img_width) + 'px',
         	height: Math.round(ry * img_height) + 'px',
          marginLeft: '-' + Math.round(rx * coords.x) + 'px',
          marginTop: '-' + Math.round(ry * coords.y) + 'px'
        });
        updateCoords(coords);
      }

      function updateCoords(c)
      {
        jQuery('#x').val(c.x);
        jQuery('#y').val(c.y);
        jQuery('#w').val(c.w);
        jQuery('#h').val(c.h);
      };
	</script>

<form action="$Data->{'target'}" method="POST">
      <input type="submit" value=" &nbsp; $save &nbsp; " class = "button proceed-button">
	<div style="clear:both;"></div>
  <div style="float:left;">
<b>$original</b>
    &nbsp;&nbsp;
    <a href="$Data->{'target'}?a=M_PH_rl&amp;client=$client&amp;tfn=$tempfile_prefix">$r_left</a>
    &nbsp; | &nbsp;
    <a href="$Data->{'target'}?a=M_PH_rr&amp;client=$client&amp;tfn=$tempfile_prefix">$r_right</a>
    <br>
    <div style="float:left;border:1px solid #000000;">
      <img
        src="getphoto.cgi?client=$client&amp;t=1&amp;tf=$tempfile_prefix"
        alt="$photo"
        id="cropbox"
      />
    </div>
  </div>

  <div style="float:left;margin-left:20px;">
    <b>$preview</b>
    <div style="border:1px solid #000000;">
      <div id="previewholder" style = "width:$previewwidth~.qq~px;overflow:hidden;height:$previewheight~.qq~px;">
				<img
					src="getphoto.cgi?client=$client&amp;t=1&amp;tf=$tempfile_prefix"
					alt="Crop Preview"
					id="preview"
				>
			</div>
    </div>
	</div>

	<input type="hidden" id="x" name="x" value = "0">
	<input type="hidden" id="y" name="y" value = "0">
	<input type="hidden" id="w" name="w" value = "100">
	<input type="hidden" id="h" name="h" value = "100">

	<input type="hidden" name="tfn" value="$tempfile_prefix">

  <div style="clear:both;">
    <input type="hidden" name="a" value="M_PH_cr">
    <input type="hidden" name="client" value="$unesc_client">
  </div>
</form>
	~;

	return $body;
}

sub rotate_photo	{
	my($Data, $memberID,$client, $action, $returnlink, $tempfile_prefix, $fromRegoForm)=@_;

	my $filename = '';
	if($memberID == -1000)	{
		$filename = "$Defs::fs_upload_dir/temp/$tempfile_prefix".'_temp.jpg';
	}
	else	{
		my $path='';
		{
			my $l=6 - length($memberID);
			my $pad_num=('0' x $l).$memberID;
			my (@nums)=$pad_num=~/(\d\d)/g;
			for my $i (0 .. $#nums-1) { 
				$path.="$nums[$i]/"; 
			}
		}
		$filename="$Defs::fs_upload_dir/$path$memberID".'_temp.jpg';
	}

	my $direction= $action eq 'M_PH_rl' ? -90 : 90;
	use Image::Magick;

	my $error='';
	my $q = Image::Magick->new;
	{
		my $x= $q->Read($filename);
		$error="Bad Image Type in Read :$x" if $x;
	}
	if(!$error)	{
		my $x = $q->Rotate(degrees => $direction);
		$error="Bad Rotate:$x" if $x;
	}
	if(!$error)	{
		my $x = $q->Write($filename);
		$error="Bad Write:$x" if $x;
	}
	$error=qq[<div class="warningmsg">$error</div>] if $error;
	return $error.edit_photo($Data, $memberID, $client, $returnlink, $tempfile_prefix, $fromRegoForm);
}

sub crop_photo	{
	my($Data, $memberID,$client, $returnlink, $tempfile_prefix, $fromregoform)=@_;

  my $filename = '';
	my $tmpfilename= '';
  if($memberID == -1000)  {
    $filename = "$Defs::fs_upload_dir/temp/$tempfile_prefix.jpg";
    $tmpfilename = "$Defs::fs_upload_dir/temp/$tempfile_prefix".'_temp.jpg';
  }
  else  {

		my $path='';
		{
			my $l=6 - length($memberID);
			my $pad_num=('0' x $l).$memberID;
			my (@nums)=$pad_num=~/(\d\d)/g;
			for my $i (0 .. $#nums-1) { 
				$path.="$nums[$i]/"; 
			}
		}
		$tmpfilename="$Defs::fs_upload_dir/$path$memberID".'_temp.jpg';
		$filename="$Defs::fs_upload_dir/$path$memberID.jpg";
	}
	my $PhotoHeight=$Data->{'SystemConfig'}{'PhotoHeight'} || 200;
	my $PhotoWidth=$Data->{'SystemConfig'}{'PhotoWidth'} || 154;

	use Image::Magick;
	my $x1=param('x') || 0;
	my $y1=param('y') || 0;
	my $width=param('w') || 0;
	my $height=param('h') || 0;

	my $error='';
	my $q = Image::Magick->new;
	{
		my $x= $q->Read($tmpfilename);
		$error="Bad Image Type in Read :$x" if $x;
	}
	if(!$error)	{
		my $x = $q->Crop(geometry => $width.'x'.$height, x=>$x1, y=>$y1);
		$error="Bad Crop:$x" if $x;
	}
	if(!$error)	{
		my $x = $q->Scale(geometry => $PhotoWidth.'x'.$PhotoHeight.'>');
		$error="Bad Resize:$x" if $x;
	}
	if(!$error)	{
		my $x = $q->Write($filename);
		$error="Bad Write:$x" if $x;
	}
	if($error)	{
		$error=qq[<div class="warningmsg">$error</div>];
		return ($error.edit_photo($Data, $memberID, $client, $returnlink, $tempfile_prefix, $fromregoform),'')
	}
	my $newaction= ($Data->{'SystemConfig'}{'DefaultListAction'} || 'DT') eq 'SUMM' ? 'M_SEL_l' : 'M_DT';
	return ('',$newaction);
}
