#!/usr/bin/perl -ws
#####################
#
# ©2013 Autodesk Development Sàrl
#
# Created on 21 Jun 2013 by Ventsislav Zhechev
#
# Changelog
# v0.1			Modified by Ventsislav Zhechev on 21 Jun 2013
# First version.
#
#####################

use strict;
use utf8;

use Encode qw/encode decode/;

my $oldSource = my $oldTarget = my $oldProduct = "";
my $cumulateP3 = my $cumulateP4 = 0;
my %targets;

while (<>) {
	chomp;
	my ($source, $target, $data) = split / \|\|\| /, decode "utf-8", $_;
	my (undef, undef, $prob3, $prob4, undef, $product) = split / \| /, $data;
	if ($source ne $oldSource || $product ne $oldProduct) {
		if ($oldTarget ne "") {
			if (defined $targets{$oldTarget}) {
				$targets{$oldTarget}->[0] += $cumulateP3;
				$targets{$oldTarget}->[1] += $cumulateP4;
			} else {
				$targets{$oldTarget} = [$cumulateP3, $cumulateP4];
			}
		}
		if ($oldSource ne "" && $oldProduct ne "") {
			foreach my $target (sort {$a cmp $b} keys %targets) {
				print encode "utf-8", "$oldSource | $target | ".join(" | ", @{$targets{$target}})." | $oldProduct\n";
			}
		}
		$cumulateP3 = $prob3;
		$cumulateP4 = $prob4;
		$oldSource = $source;
		$oldTarget = $target;
		$oldProduct = $product;
		%targets = ();
	} elsif ($target ne $oldTarget) {
		if ($oldTarget ne "") {
			if (defined $targets{$oldTarget}) {
				$targets{$oldTarget}->[0] += $cumulateP3;
				$targets{$oldTarget}->[1] += $cumulateP4;
			} else {
				$targets{$oldTarget} = [$cumulateP3, $cumulateP4];
			}
		}
		$cumulateP3 = $prob3;
		$cumulateP4 = $prob4;
		$oldTarget = $target;
	} else {
		$cumulateP3 += $prob3;
		$cumulateP4 += $prob4;
	}
}



1;