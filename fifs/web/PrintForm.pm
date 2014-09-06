#
# $Header: svn://svn/SWM/trunk/web/PrintForm.pm 10055 2013-12-01 22:39:26Z tcourt $
#

package PrintForm;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(showPrintForm);
@EXPORT_OK = qw(showPrintForm);

use strict;
use lib '.', '..';
use Defs;

sub showPrintForm	{
	my($CardData, $filename, $preview, $url, $qty, $multi)=@_;
	$multi||=0;
	$qty||=1;
	$preview||=0;

	my $formtemplate='';
	if($filename)	{
		if(-e "$Defs::fs_formdir/$filename")  { 
			open FRMFILE, "< $Defs::fs_formdir/$filename" or print STDERR "Cannot open form $Defs::fs_formdir/$filename\n";	
			while(<FRMFILE>)  { 
				my ($t)=$_=~/(.*)/;  
				$formtemplate.=$t."\n";  
			}
		}
		else	{ print STDERR "Cannot find form $Defs::fs_formdir/$filename\n";	}
	}
	my $printevent =$preview ? '' : qq[ onload="window.print();close();" ];
	my $previewtext=$preview ? qq[ 
		<div style="margin-left:20px;">
			<h1>Preview of Accreditation Card</h1>
			<p style="border-bottom:1px solid #999999;margin-bottom:20px;padding-bottom:20px;">Press the 'Print' button to print the card. <br><br><input type="button" value=" Print " onclick='window.open("$url","accredcardprint","toolbar=no,location=no,status=no,menubar=no,scrollbars=none,titlebar=no,width=200,height=200");window.close();'> &nbsp; &nbsp; <input type="button" value=" Cancel " onclick='window.close();'></p>
		</div>
	] : '';
	my $cardList=undef;
	if(exists $CardData->{'Cards'})	{
		$cardList=$CardData->{'Cards'};
	}
	else	{
		push @{$cardList}, $CardData;
	}

	my $formbody='';
	my $cardnum=0;
	for my $dref (@{$cardList})	{
		$cardnum++;
		my $formcard='';
		$dref->{'ZoneData'}=$CardData->{'ZoneData'};
		$dref->{'VenueData'}=$CardData->{'VenueData'};
		$dref->{'CountryNameToData'}=$CardData->{'CountryNameToData'};
		for my $key (keys %{$dref})  { $dref->{$key}=~s/\$/\\\$/g if $dref->{$key}; }
		if($formtemplate)  {
			for my $i (1 ..$qty)	{
				my $form=$formtemplate;
				$dref->{'PrintCount'}++;
				$form=~ s/<\?\+\+(.*?)\+\+\?>/{$1}/eegs;
				$form=~s/\@/\\@/g;  #Escape @
				$form=~s/\%/\\%/g;  #Escape %
				$form= q^qq[^.$form.q^]^;
				$form=eval($form);
				my $page_break_style='style="page-break-after:always;"';
				$page_break_style='' if($i==$qty and $cardnum == scalar(@{$cardList}));
				$formcard.= "<div $page_break_style>".$form.'</div>';
			}
		}
		$formbody.=$formcard;
	}

	my $outputform='';
	if($formbody and ($formbody!~/<html>/ or $qty >= 1))	{
		$outputform=qq[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
			<html>
				<head>
					<title>Accreditation Card</title>
				</head>
				<body $printevent>
					$previewtext
					$formbody
				</body>
			</html>
		];
	}
	else	{$outputform=$formbody;}
	if(!$formbody)	{
		$outputform=qq[
			<html>
				<head><title>Error Generating Form</title></head>
				<body>
					<h1>Error generating Form</h1>
				</body>
			</html>
		];
	}

	print qq[Content-type: text/html\n\n];
	print $outputform;
}

