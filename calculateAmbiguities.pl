#!/usr/bin/perl -sw
#####################
#
# ©2013 Autodesk Development Sàrl
#
# Created on 04 Jun 2013 by Ventsislav Zhechev
#
# Changelog
# v0.2.1	Modified by Ventsislav Zhechev on 05 Jul 2013
# The JSON output is now cleared before writing.
#
# v0.2		Modified by Ventsislav Zhechev on 24 Jun 2013
# Now the data is output in JSON format.
#
# v0.1		Modified by Ventsislav Zhechev on 04 Jun 2013
# First version.
#
#####################

use strict;
use utf8;

use Encode qw/encode decode/;
use Storable qw/dclone/;
use Data::Serializer::Raw;

my $oldSource = my $oldTarget = my $oldProduct = "";
my $oldProbability = my $maxProbability = -1;

my $probabilityThreshold = 10E-2;

my @statistics;
my $currentSource = my $currentTarget = 0;

my %products;

our $output;
my %data;
my $serialiser = Data::Serializer::Raw->new(serializer => "JSON")
or die "Could not create serialiser: $!\n";

sub processTarget {
	my ($source, $target, $product, $probability, $maxProbability) = @_;
#	print encode "utf-8", "$source → $target; Old probability is $oldProbability; max probability is $maxProbability\n";
	if ($maxProbability > .75 && 1.*$oldProbability / $maxProbability > $probabilityThreshold) {
		++$currentTarget;
		push @statistics, {} unless defined $statistics[$currentTarget];
		$statistics[$currentTarget]->{$target} = [] unless defined $statistics[$currentTarget]->{$target};
		push @{$statistics[$currentTarget]->{$target}}, [$product, $probability];
	}
}

sub processProduct {
	&processTarget(@_);
	++$products{$_[2]};
}

sub processSource {
	&processProduct(@_);
	if (1 < keys %{$statistics[1]}) {
		print encode "utf-8", "Source ".(++$currentSource).": “$_[0]”:\n";
		$data{$_[0]} = [];
#		++$currentSource;
		for (my $rank = 1; $rank < @statistics; ++$rank) {
			print encode "utf-8", "\tRank $rank:\n";
#			$data{$_[0]}->[$rank-1] = dclone($statistics[$rank]);
			foreach my $target (keys %{$statistics[$rank]}) {
				foreach my $prodProb (@{$statistics[$rank]->{$target}}) {
					$data{$_[0]}->[$rank-1]->{$target}->{$prodProb->[0]} = $prodProb->[1];
				}
			}
			my $currentTarget = 0;
			foreach my $target (keys %{$statistics[$rank]}) {
				print encode "utf-8", "\t\tTarget ".(++$currentTarget).": “$target”: ";
				print encode "utf-8", join ", ", map {join "→", @$_} @{$statistics[$rank]->{$target}};
				print encode "utf-8", "\n";
			}
		}
		print encode "utf-8", "\n";
	}
}

while (<>) {
	unless ($.%100000) {
		print STDERR ".";
		print STDERR "$." unless $.%1000000
	}
	chomp;
	my ($source, $target, $probability, undef, $product) = split / ?\| ?/, decode "utf-8", $_;
	$maxProbability = $probability unless $maxProbability > 0;
	if ($source ne $oldSource) {
		if ($oldSource ne "") {
			&processSource($oldSource, $oldTarget, $oldProduct, $oldProbability, $maxProbability);
		}
		$oldSource = $source;
		$oldTarget = $target;
		$oldProduct = $product;
		$oldProbability = $probability;
		$maxProbability = $probability;
		@statistics = ();
		$currentTarget = 0;
		next;
	}
	if ($product ne $oldProduct) {
		if ($oldProduct ne "") {
			&processProduct($oldSource, $oldTarget, $oldProduct, $oldProbability, $maxProbability);
		}
		$oldTarget = $target;
		$oldProduct = $product;
		$oldProbability = $probability;
		$maxProbability = $probability;
		$currentTarget = 0;
		next;
	}
	if ($probability != $oldProbability) {
		if ($oldProbability > 0) {
			&processTarget($oldSource, $oldTarget, $oldProduct, $oldProbability, $maxProbability);
		}
		$oldProbability = $probability;
		$oldTarget = $target;
		next;
	}
}

print STDERR encode "utf-8", "\nEncountered products: ".(join ", ", sort {$a cmp $b} keys %products)."\n";
print STDERR encode "utf-8", "Number of potentially ambiguous source phrases: $currentSource\n";


unlink $output;
$serialiser->store(\%data, $output);



1;