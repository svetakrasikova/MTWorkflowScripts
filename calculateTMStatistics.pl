#!/usr/bin/perl -ws
#####################
#
# © 2012 Autodesk Development Sàrl
#
# Created on 26 Mar 2012 by Ventsislav Zhechev
# Last modified on 29 Mar 2012 by Ventsislav Zhechev
#
# Changelog
# v0.2.1
# The data is now output in tab-separated format.
#
# v0.2
# Modified to process a whole folder of TMs at once.
# Now we are applying normalisation to the TM names to avoid significant duplication.
#
# v0.1
# First version.
#
#####################

use strict;

use utf8;

use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;

use Encode qw/encode decode/;

$| = 1;

our ($tmFolder);
die encode "utf-8", "Usage: $0 -tmFolder=…\n"
unless defined $tmFolder;

opendir TMs, $tmFolder
or die encode "utf-8", "Cannot open folder “$tmFolder”\n";

while (my $tm = readdir TMs) {
	next unless $tm =~ /TM_(.*)_ALL\.bz2/;
	my $lang = $1;

	my $file = new IO::Uncompress::Bunzip2 "$tmFolder/$tm"
	or die encode "utf-8", "Could not read file “$tmFolder/$tm”: $Bunzip2Error\n";
	
	my %fullStats;
	
	while (my $line = $file->getline) {
		chomp $line;
		my $decodeError = 0;
		my $tmp = decode "utf-8", $line, sub {$decodeError = 1};
		if ($decodeError) {
			warn "Could not decode line: $line\n";
			next;
		}
		my ($src, $trg, $prd) = split //, $tmp;
		next unless defined $src && defined $trg && defined $prd;
		$prd =~ s/^\s+|\s+$//g;
		$prd =~ s/\s+/_/g;
#		$prd = lc $prd;
		++$fullStats{$prd};
	}
	
	close $file;
	
	open $file, ">$tmFolder/stats.$lang.txt"
	or die encode "utf-8", "Cannot write file “$tmFolder/stats.$lang.txt”\n";
	print $file encode "utf-8", "TM\tSegments\n";
	print $file encode "utf-8", "$_\t$fullStats{$_}\n" foreach sort {$fullStats{$b} <=> $fullStats{$a} || $a cmp $b} keys %fullStats;
	close $file;
}

closedir TMs;


1;