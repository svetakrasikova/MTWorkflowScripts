#!/usr/bin/perl -ws
#####################
#
# ©2012–2013 Autodesk Development Sàrl
#
# Created on 26 Jun 2012 by Ventsislav Zhechev
#
# Changelog
# v0.7			Modified on 18 Mar 2013 by Ventsislav Zhechev
# Updated to use the new metrics format produced by evaluateBySegment.pl
# JFS and JFS1 are no longer calculated within this script.
# JFS statistics are output both by source and target segment length.
#
# v0.6.6		Modified on 17 Mar 2013 by Ventsislav Zhechev
# Added a parameter to optionally turn of the output of JFS statistics per segment length.
#
# v0.6.5		Modified on 17 Mar 2013 by Ventsislav Zhechev
# Added a parameter to select a specific translation type for analysis.
# Added a parameter to exclude a specific translation type from analysis.
# Added a parameter to version the statistics files only.
# Now we output JFS statistics per segment length.
#
# v0.6.4		Modified on 16 Mar 2013 by Ventsislav Zhechev
# Modified to read bz2 files instead of uncompressed text.
#
# v0.6.3		Modified on 15 Feb 2013 by Ventsislav Zhechev
# Fixed a bug where the version parameter was not used to read the proper versioned data to analyse.
#
# v0.6.2		Modified on 14 Feb 2013 by Ventsislav Zhechev
# Added a version parameter to output into files with versioned names.
#
# v0.6.1		Modified on 04 Dec 2012 by Ventsislav Zhechev
# Added parameters to selectively switch off Spearman and Kendall coefficient calculation.
#
# v0.6
# Added some debug output to inform the user of progress.
# Added a check to handle empty score records.
#
# v0.5
# Added a Joint Fuzzy Score representing the minimum of SCFS and WFS.
#
# v0.2
# Added correlation coefficient calculation.
#
# v0.1
# First version.
#
#####################

use strict;

use utf8;

use Encode qw/encode decode FB_QUIET/;
use Statistics::Descriptive;
use Statistics::RankCorrelation;

use List::Util qw/min max/;

#use IO::Compress::Bzip2 qw/$Bzip2Error/;
use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;

$| = 1;


our ($languages, $noSpearman, $noKendall, $version, $exclusiveType, $excludeType, $outputVersion, $noByLength);

die encode "utf-8", "Usage: $0 -languages=…\n" unless defined $languages;

if (defined $version) {
	$version = ".$version";
} else {
	$version = "";
}
$outputVersion ||= "";

my %stats;
#Old metric order
#my @metrics = qw/SCFS WPD ProdIncrease CFS WFS METEOR TER PER Precision Recall Length/;
#New metric order
my @metrics = qw/SLength TLength Length.ratio JFS SCFS WFS Moses Fuzzy METEOR TER PER Precision Recall/;

sub addMetrics {
	my ($data, $metrics, $scores, $perLanguage) = @_;
	$perLanguage ||= 0;
	unless (defined $data->{__stats__}) {
		$data->{__stats__}->{$_} = Statistics::Descriptive::Full->new() foreach @$metrics;
#		$data->{__stats__}->{"JFS"} = Statistics::Descriptive::Full->new();
#		$data->{__stats__}->{"JFS1"} = Statistics::Descriptive::Full->new();
		$data->{__stats__}->{bySLength} = {} if $perLanguage;
		$data->{__stats__}->{byTLength} = {} if $perLanguage;
	}
	$data->{__stats__}->{$_}->add_data($scores->{$_}) foreach @$metrics;
#	$data->{__stats__}->{"JFS"}->add_data(min($scores->{"SCFS"}, $scores->{"WFS"}));
#	$data->{__stats__}->{"JFS1"}->add_data(max($scores->{"SCFS"}, $scores->{"WFS"}));
	
	if ($perLanguage) {
		$data->{__stats__}->{bySLength}->{$scores->{SLength}} = Statistics::Descriptive::Full->new() unless defined $data->{__stats__}->{bySLength}->{$scores->{SLength}};
		$data->{__stats__}->{bySLength}->{$scores->{SLength}}->add_data($scores->{"JFS"});

		$data->{__stats__}->{byTLength}->{$scores->{TLength}} = Statistics::Descriptive::Full->new() unless defined $data->{__stats__}->{byTLength}->{$scores->{TLength}};
		$data->{__stats__}->{byTLength}->{$scores->{TLength}}->add_data($scores->{"JFS"});
	}
}

foreach my $language (split //, decode "utf-8", $languages) {
	print STDERR encode "utf-8", "Processing language “$language”…";
#	open my $scores, "<:raw", "$language$version.bysegment/en_$language.scores.txt"
	my ($langCode) = $language =~ /^(.*?)(?:\.|$)/;
	my $scores = new IO::Uncompress::Bunzip2 "$language$version.bysegment/en_$langCode.scores.txt.bz2"
	or die encode "utf-8", "Cannot read score file “$language$version.bysegment/en_$langCode.scores.txt.bz2”: $Bunzip2Error!\n";
	local $/ = encode "UTF-16LE", "\n";
	my $tab = encode "UTF-16LE", "\t";
	scalar <$scores>;
	my %scores;
	while ((undef, my ($type, $product, $release, $component), @scores{@metrics[0..3]}, undef, @scores{@metrics[4..12]}) = map {$_ = (decode "UTF-16LE", $_) || 0; s/,/./; $_} split /$tab/, scalar(<$scores>)) {
		print STDERR "." unless $. % 10000;
		next if defined $excludeType && $type eq $excludeType;
		next if defined $exclusiveType && $type ne $exclusiveType;
#		$scores{$metrics[6]} = (($scores{$metrics[0]}*$scores{$metrics[1]})/($scores{$metrics[0]}+$scores{$metrics[1]}))**$scores{$metrics[2]} + $scores{$metrics[2]}**$scores{$metrics[6]};
		&addMetrics(\%stats, \@metrics, \%scores);# if $type eq "MT";
		$stats{$language} ||= {};
		my $data = $stats{$language};
		&addMetrics($data, \@metrics, \%scores, 1);
		$data->{$type} ||= {};
		$data = $data->{$type};
		&addMetrics($data, \@metrics, \%scores);
		$data->{$product} ||= {};
		$data = $data->{$product};
		&addMetrics($data, \@metrics, \%scores);
		$data->{$release} ||= {};
		$data = $data->{$release};
		&addMetrics($data, \@metrics, \%scores);
		$data->{$component} ||= {};
		$data = $data->{$component};
		&addMetrics($data, \@metrics, \%scores);
	}
	
	close $scores;
	print STDERR encode "utf-8", "done!\n";
}

#unshift @metrics, "JFS", "JFS1";
#pop @metrics foreach 1..9;


unless (defined $noSpearman && defined $noKendall) {
	print STDERR encode "utf-8", "==> Correlations across metrics:\nSource metric\tTarget metric";
	print STDERR encode "utf-8", "\tSpearman" unless defined $noSpearman;
	print STDERR encode "utf-8", "\tKendall" unless defined $noKendall;
	print STDERR encode "utf-8", "\n";
	for (my $i = 0; $i < $#metrics; ++$i) {
		for (my $j = $i+1; $j < @metrics; ++$j) {
			my $correl = Statistics::RankCorrelation->new([$stats{__stats__}->{$metrics[$i]}->get_data()], [$stats{__stats__}->{$metrics[$j]}->get_data()]);
			print STDERR encode "utf-8", "$metrics[$i]\t$metrics[$j]";
			print STDERR encode "utf-8", "\t".$correl->spearman() unless defined $noSpearman;
			print STDERR encode "utf-8", "\t".$correl->kendall() unless defined $noKendall;
			print STDERR encode "utf-8", "\n";
		#			print STDERR encode "utf-8", "\tCSim:\t".$correl->csim()."\n";
		}
	}
}

print STDERR encode "utf-8", "\t".(join "\t", map {("$_.mean", "$_.var", "$_.skew", "$_.kurt")} @metrics)."\n";
foreach my $metric (@metrics) {
	print STDERR encode "utf-8", "\t".(join "\t", map {s/\./,/g if $_; $_} ($stats{__stats__}->{$metric}->mean(), $stats{__stats__}->{$metric}->variance() || 0, $stats{__stats__}->{$metric}->skewness() || 0, $stats{__stats__}->{$metric}->kurtosis() || 0));
}


open my $byLanguage, ">stats$outputVersion$version.byLanguage.txt"
or die encode "utf-8", "Cannot write file “stats$outputVersion$version.byLanguage.txt”\n";
open my $byType, ">stats$outputVersion$version.byType.txt"
or die encode "utf-8", "Cannot write file “stats$outputVersion$version.byType.txt”\n";
open my $byProduct, ">stats$outputVersion$version.byProduct.txt"
or die encode "utf-8", "Cannot write file “stats$outputVersion$version.byProduct.txt”\n";
open my $byRelease, ">stats$outputVersion$version.byRelease.txt"
or die encode "utf-8", "Cannot write file “stats$outputVersion$version.byRelease.txt”\n";
open my $byComponent, ">stats$outputVersion$version.byComponent.txt"
or die encode "utf-8", "Cannot write file “stats$outputVersion$version.byComponent.txt”\n";

print $byLanguage encode "utf-8", "Language\tSegments\t".(join "\t", map {("$_.mean", "$_.var", "$_.skew", "$_.kurt")} @metrics)."\n";
print $byType encode "utf-8", "Language\tType\tSegments\t".(join "\t", map {("$_.mean", "$_.var", "$_.skew", "$_.kurt")} @metrics)."\n";
print $byProduct encode "utf-8", "Language\tType\tProduct\tSegments\t".(join "\t", map {("$_.mean", "$_.var", "$_.skew", "$_.kurt")} @metrics)."\n";
print $byRelease encode "utf-8", "Language\tType\tProduct\tRelease\tSegments\t".(join "\t", map {("$_.mean", "$_.var", "$_.skew", "$_.kurt")} @metrics)."\n";
print $byComponent encode "utf-8", "Language\tType\tProduct\tRelease\tComponent\tSegments\t".(join "\t", map {("$_.mean", "$_.var", "$_.skew", "$_.kurt")} @metrics)."\n";

foreach my $language (sort {$a cmp $b} keys %stats) {
	next if $language eq "__stats__";
	
	unless (defined $noByLength) {
		open my $byLength, ">stats$outputVersion$version.$language.bySLength.txt"
		or die encode "utf-8", "Cannot write file “stats$outputVersion$version.$language.bySLength.txt”\n";
		print $byLength encode "utf-8", "SLength\tSegments\tTokens\tJFS.mean\tJFS.var\n";
		foreach my $length (sort {$a <=> $b} keys %{$stats{$language}->{__stats__}->{bySLength}}) {
			my $currentData = $stats{$language}->{__stats__}->{bySLength}->{$length};
			print $byLength encode "utf-8", "$length\t".$currentData->count()."\t".($currentData->count()*$length)."\t".join("\t", map {s/\./,/g if $_; $_} ($currentData->mean() || 0, $currentData->variance() || 0))."\n";
		}
		close $byLength;

		open $byLength, ">stats$outputVersion$version.$language.byTLength.txt"
		or die encode "utf-8", "Cannot write file “stats$outputVersion$version.$language.byTLength.txt”\n";
		print $byLength encode "utf-8", "TLength\tSegments\tTokens\tJFS.mean\tJFS.var\n";
		foreach my $length (sort {$a <=> $b} keys %{$stats{$language}->{__stats__}->{byTLength}}) {
			my $currentData = $stats{$language}->{__stats__}->{byTLength}->{$length};
			print $byLength encode "utf-8", "$length\t".$currentData->count()."\t".($currentData->count()*$length)."\t".join("\t", map {s/\./,/g if $_; $_} ($currentData->mean() || 0, $currentData->variance() || 0))."\n";
		}
		close $byLength;
	}

	print $byLanguage encode "utf-8", "$language\t".$stats{$language}->{__stats__}->{$metrics[0]}->count();
	foreach my $metric (@metrics) {
		print $byLanguage encode "utf-8", "\t".(join "\t", map {s/\./,/g if $_; $_} ($stats{$language}->{__stats__}->{$metric}->mean(), $stats{$language}->{__stats__}->{$metric}->variance() || 0, $stats{$language}->{__stats__}->{$metric}->skewness() || 0, $stats{$language}->{__stats__}->{$metric}->kurtosis() || 0));
	}
	print $byLanguage encode "utf-8", "\n";
	foreach my $type (sort {$a cmp $b} keys %{$stats{$language}}) {
		next if $type eq "__stats__";
		print $byType encode "utf-8", "$language\t$type\t".$stats{$language}->{$type}->{__stats__}->{$metrics[0]}->count();
		foreach my $metric (@metrics) {
			print $byType encode "utf-8", "\t".(join "\t", map {s/\./,/g if $_; $_} ($stats{$language}->{$type}->{__stats__}->{$metric}->mean(), $stats{$language}->{$type}->{__stats__}->{$metric}->variance() || 0, $stats{$language}->{$type}->{__stats__}->{$metric}->skewness() || 0, $stats{$language}->{$type}->{__stats__}->{$metric}->kurtosis() || 0));
		}
		print $byType encode "utf-8", "\n";
		foreach my $product (sort {$a cmp $b} keys %{$stats{$language}->{$type}}) {
			next if $product eq "__stats__";
			print $byProduct encode "utf-8", "$language\t$type\t$product\t".$stats{$language}->{$type}->{$product}->{__stats__}->{$metrics[0]}->count();
			foreach my $metric (@metrics) {
				print $byProduct encode "utf-8", "\t".(join "\t", map {s/\./,/g if $_; $_} ($stats{$language}->{$type}->{$product}->{__stats__}->{$metric}->mean(), $stats{$language}->{$type}->{$product}->{__stats__}->{$metric}->variance() || 0, $stats{$language}->{$type}->{$product}->{__stats__}->{$metric}->skewness() || 0, $stats{$language}->{$type}->{$product}->{__stats__}->{$metric}->kurtosis() || 0));
			}
			print $byProduct encode "utf-8", "\n";
			foreach my $release (sort {$a cmp $b} keys %{$stats{$language}->{$type}->{$product}}) {
				next if $release eq "__stats__";
				print $byRelease encode "utf-8", "$language\t$type\t$product\t$release\t".$stats{$language}->{$type}->{$product}->{$release}->{__stats__}->{$metrics[0]}->count();
				foreach my $metric (@metrics) {
					print $byRelease encode "utf-8", "\t".(join "\t", map {s/\./,/g if $_; $_} ($stats{$language}->{$type}->{$product}->{$release}->{__stats__}->{$metric}->mean(), $stats{$language}->{$type}->{$product}->{$release}->{__stats__}->{$metric}->variance() || 0, $stats{$language}->{$type}->{$product}->{$release}->{__stats__}->{$metric}->skewness() || 0, $stats{$language}->{$type}->{$product}->{$release}->{__stats__}->{$metric}->kurtosis() || 0));
				}
				print $byRelease encode "utf-8", "\n";
				foreach my $component (sort {$a cmp $b} keys %{$stats{$language}->{$type}->{$product}->{$release}}) {
					next if $component eq "__stats__";
					print $byComponent encode "utf-8", "$language\t$type\t$product\t$release\t$component\t".$stats{$language}->{$type}->{$product}->{$release}->{$component}->{__stats__}->{$metrics[0]}->count();
					foreach my $metric (@metrics) {
						print $byComponent encode "utf-8", "\t".(join "\t", map {s/\./,/g if $_; $_} ($stats{$language}->{$type}->{$product}->{$release}->{$component}->{__stats__}->{$metric}->mean(), $stats{$language}->{$type}->{$product}->{$release}->{$component}->{__stats__}->{$metric}->variance() || 0, $stats{$language}->{$type}->{$product}->{$release}->{$component}->{__stats__}->{$metric}->skewness() || 0, $stats{$language}->{$type}->{$product}->{$release}->{$component}->{__stats__}->{$metric}->kurtosis() || 0));
					}
					print $byComponent encode "utf-8", "\n";
				}
			}
		}
	}
}

close $byLanguage;
close $byType;
close $byProduct;
close $byRelease;
close $byComponent;


1;