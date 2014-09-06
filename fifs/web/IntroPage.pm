#
# $Header: svn://svn/SWM/trunk/web/IntroPage.pm 8251 2013-04-08 09:00:53Z rlee $
#

package IntroPage;
require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(print_top print_bottom);
@EXPORT_OK = qw(print_top print_bottom);


use strict;

sub print_top	{
	my $returnstr="Content-type: text/html\n\n";

	$returnstr.=q[
<html>

<head>
  	<title>SportingPulse - Registration Database</title>
	<link rel="stylesheet" type="text/css" href="adminstyle.css">

<script language="javascript">

  <!--
  function searchfocus()
  {
    if (document.loginform)
      document.loginform.username.focus();
  }
  //-->

</script>

</head>

<body bgcolor="#ffffff" marginheight="0" marginwidth="0" leftmargin="0" topmargin="0" onload="searchfocus();">

<table border="0" cellpadding="0" cellspacing="0" width="100%" height="100%">
<tr>
 <td valign="top" height="100%">

<!-- START HEADER -->
<p align="center"><img src="images/header.gif" border="0" alt=""></p>
<!-- END HEADER -->
	];
	return $returnstr;
};

sub print_bottom	{
	my $returnstr=q[
<p><br></p>
<p><br></p>

<div style="clear:both;margin-left:100px;padding-top:30px;">
SportingPulse takes your privacy seriously, <a href="http://www.sportingpulse.com.au/privacy.cgi">click to see our privacy policy.</a><br><br>
If you experience problems with logging into the system then please contact: <a href="mailto:info@sportingpulse.com" class="info"><b>info@sportingpulse.com</b></a>
</div>

 </td>
</tr>
 <td height="35">

<!-- FOOTER -->
<table border="0" cellpadding="0" cellspacing="0" width="680" align="center">
	<tr>
		<td><img src="images/spacer.gif" width="25" height="15" border="0" alt=""><a href="http://www.sportingpulse.com"><img src="images/spacer.gif" width="125" height="15" border="0" alt=""></a> <br> <img src="images/spacer.gif" width="1" height="20" border="0" alt=""></td>
	</tr>
</table>

 </td>
</tr>
</table>

</body>

</html>
	];
	return $returnstr;
}

1;
