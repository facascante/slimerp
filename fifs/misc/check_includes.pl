#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/check_includes.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;

my %modulefunctions = ();
my %brokenmodules = ();
my $verbose = 1;


my $lastfindname = ''; #Stupid global - but needed

main();

sub main	{

	if(!scalar(@ARGV) ) {
		print STDERR "No Filenames\n";
		exit;
	}
	my %Summary = ();
	for my $filename (@ARGV)	{
		chomp $filename;
		open FILEIN, "<$filename";
		my @lines = <FILEIN>;
		my $filecontents = join('',@lines);
		#find all the includes first
		my @matches =  $filecontents =~ /\b(?:use|require)\s+([^\s;]+)[\s;\n]/gs;
		my $modules = cleanupModuleList(\@matches);

		#create list of modules to check 
		print "===== Processing file $filename =====================\n" if $verbose;
		for my $module (@{$modules})	{
			my $founduse = 0;
			print " .. Checking use of module $module ----- \n" if $verbose;
			{
				print "       Checking direct use of module eg. $module"."::XX .." if $verbose;
				my $directstr = $module.'::';
				if(
					$filecontents =~ /$directstr/ 
					or $filecontents =~ /$module->/
					or $filecontents =~ /new $module/
					or $filecontents =~ /\@ISA[^\n]+$module/
				)	{
					$founduse = 1;
					print " # Found # " if $verbose;
				}
				else	{
					print " (Not Found) " if $verbose;
				}
				print " \n" if $verbose;
			}
			{
				my $fns = getValidFunctions($module);
				if($fns)	{
					for my $f (keys %{$fns})	{
						print "       Checking function use  .. $f" if $verbose;
						if($filecontents =~ /$f\s*\(/
							or $filecontents =~ /\&$f/)	{
							$founduse = 1;
							print " # Found #" if $verbose;
						}
						else	{
							print " (Not Found) " if $verbose;
						}
						print " \n" if $verbose;
					}
				}
			}
			$Summary{$filename}{$module} = $founduse || 0;
		}

		close FILEIN;
	}
	#Print Summary 
	for my $filename (keys %Summary)	{
		for my $module (keys %{$Summary{$filename}})	{
			my $foundstr =  $Summary{$filename}{$module} 
				? ' +++++ In Use   +++++ '
				: ' ----- Not Used ----- ';
			if($brokenmodules{$module} and !$Summary{$filename}{$module})	{
				$foundstr = '!!!!! Unknown !!!!!';
			}
			printf "%20s : %20s : %s\n", $filename, $module, $foundstr;
		}
	}
}

sub cleanupModuleList {
	my ($module_list) = @_;

	#remove duplicates and other system modules
	my %ignorelist = (
		CGI => 1,
		lib => 1,
		strict => 1,
		Defs => 1,
		Exporter => 1,
	);
	my %modules= ();
	for my $m (@{$module_list})	{
		if(!$ignorelist{$m})	{
			$modules{$m} = 1;
		}
	}
	my @modules = keys %modules;
	return \@modules;	
}


sub getValidFunctions {
	my ($module) = @_;

	return undef if $brokenmodules{$module};
	if($modulefunctions{$module})	{
		return $modulefunctions{$module};
	}

	my $filename = getModuleFile($module);

	if($filename)	{
		chomp $filename;
		if(-e $filename and open EXTMODULE , "<$filename")	{
			my $modulestring = '';
			my $inexport = 0;
			while(<EXTMODULE>)	{
				chomp;
				my $line = $_;
				if($line =~/^\s*\@EXPORT/)	{
					$inexport = 1;
				}
				$modulestring .= $line if $inexport;
				if($inexport and $line=~/\)/)	{
					$inexport = 0;
				}
			}
			close EXTMODULE;
			$modulestring =~ s/\@EXPORT(_OK)*\s*=\s*qw[\(\/]/ /g;
			$modulestring =~ s/[\)\/];/ /g;
			my @modules = split/\s+/, $modulestring;
			for my $m (@modules) {
				next if !$m;
				$modulefunctions{$module}{$m} = 1; 
			}
		}
		else	{
			print "Cannot open $filename\n";
			$brokenmodules{$module} = 1;
		}
	}
	else	{
		$brokenmodules{$module} = 1;
	}

	return $modulefunctions{$module};
}

sub getModuleFile	{
	my ($module) = @_;

	use Cwd;
	use File::Find;

	my $module_to_find = $module.'.pm';
	$module_to_find =~s/::/\//g;
	my @directories_to_search = (getcwd());

	$lastfindname = '';
	find(sub { find_fn($module_to_find);}, @directories_to_search);
	return $lastfindname || '';
}

sub find_fn	{
	my ($module_to_find) = @_;

	return '' if $lastfindname;
	my $name = $File::Find::name;
	return 0 if $name =~/\.svn\//;
	if($name =~/\/$module_to_find$/)	{
		$lastfindname = $name;
	}
	return $lastfindname;
}
