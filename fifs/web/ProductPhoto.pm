#
# $Header: svn://svn/SWM/trunk/web/Photo.pm 8251 2013-04-08 09:00:53Z rlee $
#

package ProductPhoto;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_ProductPhoto);
@EXPORT_OK = qw(handle_ProductPhoto);

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

sub handle_ProductPhoto	{
	my($action, $Data, $memberID, $returnlink, $otherformdata, $tempfilename, $productAction)=@_;
  my $resultHTML='';
	my $fromRegoForm ||= 0;
	$returnlink ||=param('ra') || '';
  my $assocID= $Data->{'clientValues'}{'assocID'} || -1;
	return ('No Member or Association Specified','','') if (!$memberID or !$assocID) and !$productAction;
	my $newaction='';
  my $client=setClient($Data->{'clientValues'}) || '';

  my $type = '';

  if ($action eq 'M_PH_s') {
    $resultHTML = show_photo($Data,$memberID,$client, $returnlink);
  }
=fk
   elsif ($action eq 'M_PH_n') {
    $resultHTML = new_photo($Data,$memberID,$client, $returnlink, $otherformdata, $tempfilename, $fromRegoForm);
  }
  elsif ($action eq 'M_PH_u') {
    $resultHTML = process_upload($Data, $memberID,$client, $tempfilename, $fromRegoForm);
    $type = 'Upload Photo';
  }
=cut 
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
    $resultHTML .= new_photo_product($Data,$memberID,$client);
    $type = 'Delete Photo';
  }
# PRODUCT PHOTO UPLOAD HANDLING
  elsif($action eq 'P_PH_n'){
	$resultHTML = new_photo_product($Data,$memberID,$client, $returnlink, $otherformdata, $tempfilename, $fromRegoForm);
  }	
  elsif($action eq 'P_PH_u'){
	$resultHTML = process_upload_product($Data,$memberID,$client, $tempfilename, $fromRegoForm);
  }	
  elsif($action eq 'P_PH_s'){
        $resultHTML = show_photo_product($Data,$memberID,$client, $tempfilename, $fromRegoForm);
  }   
  elsif($action eq 'P_PH_upload'){
        $resultHTML ="POSTED!";
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
if($tempfilename and $newaction and $productAction)      {
                my $imgURL = "getProductPhoto.cgi?client=$client&amp;pID=$memberID&amp;t=0&amp;tf=$tempfilename";

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
}

sub new_photo	{
	my($Data, $memberID, $cl, $returnlink, $otherformdata, $tempfilename, $fromRegoForm)=@_;
}

#'#

sub process_upload	{
	my($Data, $memberID, $client, $tempfile_prefix, $fromRegoForm)=@_;
}

sub do_delete	{
	my($reason, $db, $memberID)=@_;
	my $mID=$memberID;
	$mID =~/^(\d+)$/;
	$mID =$1;
	if($mID)	{
		if($db)	{
			my $statement=qq[
				UPDATE tblProducts
				SET intPhoto=0
				WHERE intProductID= ? 
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
    <a href="$Data->{'target'}?a=M_PH_rl&amp;client=$client&amp;pID=$memberID&amp;tfn=$tempfile_prefix">$r_left</a>
    &nbsp; | &nbsp;
    <a href="$Data->{'target'}?a=M_PH_rr&amp;client=$client&amp;pID=$memberID&amp;tfn=$tempfile_prefix">$r_right</a>
    <br>
    <div style="float:left;border:1px solid #000000;">
      <img
        src="getProductPhoto.cgi?client=$client&amp;t=1&amp;pID=$memberID&amp;tf=$tempfile_prefix"
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
					src="getProductPhoto.cgi?client=$client&amp;t=1&amp;pID=$memberID&amp;tf=$tempfile_prefix"
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
    <input type="hidden" name="pID" value="$memberID">
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


sub new_photo_product	{
	my($Data, $pID, $cl, $returnlink, $otherformdata, $tempfilename, $fromRegoForm)=@_;
  	$cl = unescape($cl);
	$returnlink||='';
	$otherformdata||='';
	my $target=$Data->{'target'} || '';

  my $upload_photo = $Data->{'lang'}->txt('Save Photo');
  my $uploading    = $Data->{'lang'}->txt('Uploading');

 # my $upload_photo_form_text
  #  = $Data->{'lang'}->txt($Data->{'SystemConfig'}{'txt_UPLOAD_PHOTO_FORM_TEXT'} || '')
   # || $Data->{'lang'}->txt('UPLOAD_PHOTO_FORM_TEXT', $upload_photo);
	my $upload_photo_form_text='';
  my $upload_time = $Data->{'lang'}->txt('The estimated time to upload a 400Kb image is');

  my $connection        = $Data->{'lang'}->txt('Connection');
  my $approx_time       = $Data->{'lang'}->txt('Approx. Time');
  my $minutes           = $Data->{'lang'}->txt('minutes');
  my $cable             = $Data->{'lang'}->txt('Cable');
  my $under_1_minute    = $Data->{'lang'}->txt('Under 1 minute');
  my $please_be_patient = $Data->{'lang'}->txt('Please be Patient');

  my $body = '';
$body = qq[<form action="$target" method="POST" enctype="multipart/form-data">
    ];
	$body .=qq[
<div id="photoselect">
  ];
  $body .= qq[
		<div id = "upload_div">
			<input type="file" name="uploadfile" size="30"><br><br>
			<p> Photos should be in JPEG (jpg) format and be less than 3Mb in size.  </p>
		</div>

    <input type="hidden" name="client" value="$cl">
    <input type="hidden" name="pID" value="$pID">
    <input type="hidden" name="p_action" value="1">
    <input type="hidden" name="a" value="P_PH_u">
    <input type="hidden" name="tfn" value="$tempfilename">
    <input type="hidden" name="ra" value="$returnlink">
    <input type="hidden" name = "rawimage" id="imageout" value = "">
    $otherformdata

 <input
      type="submit"
      name="submitb"
      value="$upload_photo"
      style="width:160px;"
                        class = "button proceed-button"
                        
      onclick="
        document.getElementById('photoselect').style.display='none';
        document.getElementById('pleasewait').style.display='block';
      "
    >		<br>
		<br>
</form></div>
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

];

	return $body;
}

sub process_upload_product {
 my($Data, $memberID, $client, $tempfile_prefix, $fromRegoForm)=@_;
        my $path='';
        my $orig_file = '';
        my $temp_file = '';
        $tempfile_prefix =~ /^([\da-zA-Z]+)$/;
        $tempfile_prefix = $1;

        if($memberID == -1000)  {
                $orig_file="$Defs::fs_upload_dir/temp/$tempfile_prefix.jpg";
                $temp_file="$Defs::fs_upload_dir/temp/$tempfile_prefix".'_temp.jpg';
        }
        else    {
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
        my $newphotolink=new_photo_product($Data, $memberID, $client, $returnlink);
        my $returnlinkhtml=$returnlink ? qq[<br><br><a href="$Data->{'target'}?a=$returnlink&amp;client=$client&amp;=$memberID">&lt; Return</a>] : '';
        $newphotolink.=$returnlinkhtml;
        my $imgtmp = undef;
        my $PhotoDPI = $Data->{'SystemConfig'}{'PhotoDPI'} || 0;
        if(param('rawimage'))   {
                my $raw= param('rawimage');
                $raw=~s/.*base64,//;
                open RAWFILE, ">$temp_file";
                print RAWFILE decode_base64($raw);
                close RAWFILE;
                $imgtmp=new ImageUpload(fieldname=>"$temp_file", existing => 1, filename=>$temp_file, overwrite=>1, maxsize=>3145728);
        }
        else    {
                $imgtmp=new ImageUpload(fieldname=>"uploadfile", filename=>$temp_file, overwrite=>1, maxsize=>3145728);
        }

        if($imgtmp->Error())    {return do_delete(q[<div class="warningmsg">Cannot create Upload temp object].$imgtmp->Error()."</div>".$newphotolink,$Data->{'db'},$memberID);}
        else    {
                my $ret=$imgtmp->ImageManip(Dimensions=>'2000x2000', DPI => $PhotoDPI);
                if($ret)        { return do_delete(q[<div class="warningmsg">].$imgtmp->Error()."</div>".$newphotolink,$Data->{'db'},$memberID); }
                my $PhotoHeight=$Data->{'SystemConfig'}{'PhotoHeight'} || 200;
                my $PhotoWidth=$Data->{'SystemConfig'}{'PhotoWidth'} || 154;
                if($imgtmp->Height() < $PhotoHeight or $imgtmp->Width() < $PhotoWidth)  {
                                return do_delete(
                                        q[<div class="warningmsg">The image uploaded is too small</div>].$newphotolink,
                                        $Data->{'db'},
                                        $memberID
                                );
                }
}

   my $img=new ImageUpload(fieldname=>"$temp_file", existing=>1, filename=>$orig_file, overwrite=>1, maxsize=>3145728);
        if($img->Error())       {return do_delete(q[<div class="warningmsg">Cannot create Upload object].$img->Error()."</div>".$newphotolink,$Data->{'db'},$memberID);}
        else    {
                my $PhotoHeight=$Data->{'SystemConfig'}{'PhotoHeight'} || 200;
                my $PhotoWidth=$Data->{'SystemConfig'}{'PhotoWidth'} || 154;

                my $ret=$img->ImageManip(Dimensions=>$PhotoWidth.'x'.$PhotoHeight, DPI => $PhotoDPI);
                if($ret)        {
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
        )       {
                my $statement=qq[
                        UPDATE tblProducts
                        SET intPhoto=1
                        WHERE intProductID = ?
                ];
                my $q = $Data->{'db'}->prepare($statement);
                $q->execute(
                        $memberID
                );
                $q->finish();
        }
        return $returnlinkhtml.edit_photo($Data, $memberID, $client, $returnlink, $tempfile_prefix, $fromRegoForm);

}
sub show_photo_product {
	 my($Data, $memberID,$client, $returnlink)=@_;
        my $target=$Data->{'target'} || '';
        $returnlink||='';

        #First check if there is a photo
        my $statement = qq[
                SELECT intPhoto
                FROM tblProducts
                WHERE intProductID = ?
        ];
        my $query = $Data->{'db'}->prepare($statement);
        $query->execute($memberID);
        my($hasphoto)=$query->fetchrow_array();
        $query->finish();
	if ($hasphoto) {
                
                my $photoopts;
                
                if ((allowedAction($Data, 'm_ep') and !$Data->{'MemberOnPermit'})) {
                        
                        my $replace_photo = $Data->{'lang'}->txt('Replace Photo');
                        my $delete_photo  = $Data->{'lang'}->txt('Delete Photo');
                        
                        $photoopts = qq[
<a href="$target?client=$client&amp;a=P_PH_n" >
  <img
    src="images/edit_sml.png"
    title="$replace_photo"
    alt="$replace_photo"
    border="0"
  >
</a>
<a href="$target?client=$client&amp;a=M_PH_d" >
  <img
    src="images/delete_sml.png"
    border="0"
    alt="$delete_photo"
    title="$delete_photo"
  >
</a>                    
                        ];
    }
                
                my $photo = $Data->{'lang'}->txt('Photo');
                my $PhotoHeight = $Data->{'SystemConfig'}{'PhotoHeightDisplay'} || $Data->{'SystemConfig'}{'PhotoHeight'} || 200;
                my $PhotoHeightstring = $PhotoHeight.'px';
                
                return qq[
<div class="mphoto">
  <div>
    <img src="getProductPhoto.cgi?client=$client&amp;pID=$memberID" class="productphoto" alt="$photo" style="height:$PhotoHeightstring;">
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
	my $pID = "&$memberID";
            my $script =  q[<input type="button" value = " Upload Photo " id = "photoupload" class="button generic-button">
                                       <script>
                                        jQuery('#photoupload').click(function() {
                                                        jQuery('#photoupload_form').html('<iframe src="productphoto.cgi?client=].$client.$pID.q[" style="width:750px;height:650px;border:0px;"></iframe>');
                                                        jQuery('#photoupload_form').dialog({
                                                                        width: 800,
                                                                        height: 700,
                                                                        modal: true,
                                                                        title: 'Upload Photo'
                                                        });
                                        });
                                        </script>
                                ]; 
                        return <<"EOS";
<div class="mphoto">
  <a href="" id ="photoupload__">
    <img src="images/add_photo_icon.gif" border="0" alt="$no_photo_found" title="$no_photo_found">
    <br>
    $add_photo
  </a>
$script
</div>
EOS
         
                }
        }
        
        return q{};

}


