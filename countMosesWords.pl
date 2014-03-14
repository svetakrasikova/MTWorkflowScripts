#!/usr/bin/perl -ws
#
# ©2011 Autodesk Development Sàrl
# Created on 01 Nov 2011 by Ventsislav Zhechev
# Last modified on 04 Nov 2011 by Ventsislav Zhechev
#
#
###########################

use strict;

$| = 1;

our ($logDir, $filterEngine);

$logDir ||= "./LOG/";
$filterEngine ||= 0;

opendir LOG, $logDir
or die "Cannot read folder $logDir!\n";

my %engines;

while (my $file = readdir LOG) {
	my ($engine) = $file =~ /^(fy\d+.*)_\w+_\d+\..*.log$/;
	next unless $engine && $file =~ /script/;
	next if $filterEngine && $engine ne $filterEngine;
#	print STDERR "--- counting for engine $engine\n";

	unless (defined $engines{$engine}) {
		$engines{$engine} = {restarts => 1};
	} else {
		++$engines{$engine}->{restarts};
	}
	
	open IN, "<:encoding(utf-8)", "$logDir/$file";
	
	while (my $line = <IN>) {
		my ($lines, $words) = $line =~ /src lines: (\d+); words: (\d+)/;
		next unless $lines && $words;

		$engines{$engine}->{totalLines} += $lines;
		$engines{$engine}->{totalWords} += $words;
		++$engines{$engine}->{connections};
	}
	
	close IN;
}

closedir LOG;


print STDOUT "{engine => \"$_\", lines => $engines{$_}->{totalLines}, words => $engines{$_}->{totalWords}, connections => $engines{$_}->{connections}, restarts => $engines{$_}->{restarts}}\n" foreach sort {$a cmp $b} keys %engines;


1;