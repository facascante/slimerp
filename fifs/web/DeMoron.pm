#
# $Header: svn://svn/SWM/trunk/web/DeMoron.pm 8251 2013-04-08 09:00:53Z rlee $
#

package DeMoron;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(demoronise);
@EXPORT_OK = qw(demoronise);

use utf8;

#
#           De-moron-ise Text from Microsoft Applications
# 
#                   by John Walker -- January 1998
#                      http://www.fourmilab.ch/
#
#               This program is in the public domain.
#
# This is the Unmoroniser fork
# Changelog:
# June 2003: Unicode added by Charlie Loyd

sub demoronise {
    my ($s) = @_;

    #   Eliminate idiot MS-DOS carriage returns from line terminator

    #$s =~ s/\s+$//;
    #$s .= "\n";

    #   Fix strategically non-standard characters 0x82 through 0x9f.
    #   Unicode!

	#$s =~ s/\x{20AC}/&euro;/g; # Euro currency symbol (looks like e)
	#$s =~ s/\x82/&sbquo;/g; # single low open quote (looks like ,)
	#$s =~ s/\x83/&fnof;/g; # function, folder, and florin symbol (looks like f)
	#$s =~ s/\x84/&bdquo;/g; # double low open quote (looks like ,,)
	$s =~ s/\x85/.../g; 
	$s =~ s/\x{e280a6}/&hellip;/g; # horizontal ellipsis (looks like ...)
	#$s =~ s/\x86/&dagger;/g; # dagger symbol (death or second footnote)
	#$s =~ s/\x87/&Dagger;/g; # double dagger symbol (third footnote)
	#$s =~ s/\x88/&circ;/g; # empty circumflex accent (looks like ^)
	#$s =~ s/\x89/&permil;/g; # per-thousand symbol (looks like %0)
	#$s =~ s/\x8a/&Scaron;/g; # capital s with caron (looks like S + v)
	#$s =~ s/\x8b/&lsaquo;/g; # left single angle quote (looks like less-than)
	#$s =~ s/\x8c/&OElig;/g; # capital o-e ligature (looks like Oe)
	#$s =~ s/\x8e/&#x017d;/g; # capital z with caron (looks like Z + v)
	$s =~ s/\x{e28098}/&lsquo;/g; # left single quote (looks like `)
	$s =~ s/\x{e28099}/&rsquo;/g; # right single quote (looks like ')
	$s =~ s/\x{e2809c}/&ldquo;/g; # left double quote (looks like ``)
	$s =~ s/\x{e2809d}/&rdquo;/g; # right double quote (looks like ")
	$s =~ s/\x93/"/g;
	$s =~ s/\x94/"/g;

	#$s =~ s/\x95/&bull;/g; # bullet (dot for lists)
	$s =~ s/\x96/&ndash;/g; # en dash (looks like -)
	$s =~ s/\x97/&mdash;/g; # em dash (looks like --)
	#$s =~ s/\x98/&tilde;/g; # small tilde (looks like ~)
	#$s =~ s/\x99/&trade;/g; # trademark symbol (looks like TM)
	#$s =~ s/\x9a/&scaron;/g; # lowercase s with caron (looks like s + v)
	#$s =~ s/\x9b/&rsaquo;/g; # right single angle quote (looks like greater-than)
	#$s =~ s/\x9c/&oelig;/g; # lowercase o-e ligature (looks like oe)
	#$s =~ s/\x9e/&#x017e;/g; # lowercase z with caron (looks like z + v)
	#$s =~ s/\x9f/&Yuml;/g; # capital y with diaeresis or umlaut (looks like Y + ")

    #   That was Unicode.
    #   Now check for any remaining untranslated characters.

    #if ($s =~ m/[\x00-\x08\x10-\x1F\x80-\x9F]/) {
        #for (my $i = 0; $i < length($s); $i++) {
            #my $c = substr($s, $i, 1);
            #if ($c =~ m/[\x00-\x09\x10-\x1F\x80-\x9F]/) {
                #printf(STDERR  "$ifname: warning--untranslated character 0x%02X in input line %d, output line(s) %d(...).\n",
                    #unpack('C', $c), $iline, $oline + 1);
            #}
        #}
    #}
    #   Supply missing semicolon at end of numeric entity if
    #   Billy's bozos left it out.

    $s =~ s/(&#[0-2]\d\d)\s/$1; /g;

    #   Fix dimbulb obscure numeric rendering of &lt; &gt; &amp;

    $s =~ s/&#038;/&amp;/g;
    $s =~ s/&#060;/&lt;/g;
    $s =~ s/&#062;/&gt;/g;
		$s =~s/\x92/'/g;


    #   Fix unquoted non-alphanumeric characters in table tags

    $s =~ s/(<TABLE\s.*)(WIDTH=)(\d+%)(\D)/$1$2"$3"$4/gi;
    $s =~ s/(<TD\s.*)(WIDTH=)(\d+%)(\D)/$1$2"$3"$4/gi;
    $s =~ s/(<TH\s.*)(WIDTH=)(\d+%)(\D)/$1$2"$3"$4/gi;

    #   Correct PowerPoint mis-nesting of tags

    $s =~ s-(<Font .*>\s*<STRONG>.*)(</FONT>\s*</STRONG>)-$1</STRONG></Font>-gi;

    #   Translate bonehead PowerPoint misuse of <UL> to achieve
    #   paragraph breaks.

    $s =~ s-<P>\s*<UL>-<p>-gi;
    $s =~ s-</UL><UL>-<p>-gi;
    $s =~ s-</UL>\s*</P>--gi;

    #   Repair PowerPoint depredations in "text-only slides"

    $s =~ s-<P></P>--gi;
    $s =~ s- <TD HEIGHT=100- <tr><TD HEIGHT=100-ig;
    $s =~ s-<LI><H2>-<H2>-ig;

    $s;
}


1;
