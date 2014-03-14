#!/usr/bin/perl -w
#####################
#
# © 2012 Autodesk Development Sàrl
#
# Created on 30 Mar 2012 by Ventsislav Zhechev
# Last modified on 13 Apr 2012 by Ventsislav Zhechev
#
# Changelog
# v0.1.2
# Added additional permissible characters for abbr.
#
# v0.1.1
# Now we are printing up to five examples per abbr. category.
#
# v0.1
# First version.
#
#####################

use strict;

use utf8;

use Encode qw/encode decode/;
use List::Util qw/sum/;

my %abbreviations;
while(<>) {
	my ($s, $t, undef) = split //, decode "utf-8", $_;
	next unless defined $s && defined $t;
	$t =~ s/^\s+|\s+$//g;

	++$abbreviations{lc $+{a}}->{$t} if $t =~ /(?:^|\s+)(?<a>\p{IsAlpha}[\p{IsAlpha}\.\-–—\: ]{0,4}\.)\s+/;
}

my $total = 0;
foreach (keys %abbreviations) {
	++$total unless sum(values %{$abbreviations{$_}}) < 5;
}
print encode "utf-8", "Total abbreviation categories: $total\n\n";
foreach my $abbreviation (sort {sum(values %{$abbreviations{$b}}) <=> sum(values %{$abbreviations{$a}})} keys %abbreviations) {
	my $sum = sum(values %{$abbreviations{$abbreviation}});
	next if $sum < 5;
	print encode "utf-8", "========== $abbreviation ==> $sum ==========\n";
	my $counter = 0;
	foreach my $line (sort {$abbreviations{$abbreviation}->{$b} <=> $abbreviations{$abbreviation}->{$a}} keys %{$abbreviations{$abbreviation}}) {
		last if ++$counter > 5;
		print encode "utf-8", "$abbreviations{$abbreviation}->{$line} ==> $line\n";
	}
	print encode "utf-8", "========== $abbreviation ==========\n";
}




1;