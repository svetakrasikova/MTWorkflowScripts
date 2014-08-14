#!/usr/bin/perl -ws
#
# ©2011–2014 Autodesk Development Sàrl
# Created on 29 May 2012 by Ventsislav Zhechev
#
# ChangeLog
# v0.2		modified on 24 Jul 2014 by Ventsislav Zhechev
# Modified to extract data from parallel original/post-edited XLIFFs
#
# v0.1		modified on 29 May 2012 by Ventsislav Zhechev
# Initial version
#
###########################

use strict;
use utf8;
use Encode qw/encode decode/;

use IO::Uncompress::Unzip;


$| = 1;


our ($input, $postEdited);

die encode("UTF-8", "Usage: $0 -input=… [-postEdited=…]\n")
unless defined $input;


my $in = new IO::Uncompress::Unzip $input
or die encode "UTF-8", "Cannot read file $input!\n";
my $pe;
if (defined $postEdited) {
	$pe = new IO::Uncompress::Unzip $postEdited
	or die encode "UTF-8", "Cannot read file $postEdited!\n";
}


$/ = "</trans-unit>";
#my %goodFiles = map {$_ => 1} (1099, 1100, 1146, 116, 1160, 1162, 122, 126, 1276, 1375, 1379, 1380, 1402, 141, 1427, 145, 153, 1535, 1550, 1551, 158, 1588, 1590, 1602, 1610, 1628, 1635, 1636, 1779, 1845, 1878, 191, 1997, 2120, 2133, 2134, 2162, 2230, 2233, 2278, 2286, 2350, 2398, 2430, 2474, 256, 2627, 2787, 2856, 2860, 2870, 2878, 2879, 2917, 2923, 2941, 298, 30, 3019, 3052, 3161, 3173, 3253, 3328, 3342, 3367, 3368, 3381, 3425, 3431, 3435, 3465, 3473, 3477, 3479, 354, 357, 3581, 3586, 3590, 3611, 3626, 3636, 3643, 366, 368, 3696, 3736, 374, 375, 3756, 3759, 3833, 4027, 4075, 4077, 41, 4157, 4166, 4172, 4181, 4197, 4201, 4321, 4328, 4354, 4387, 4394, 4409, 4422, 4423, 587, 674, 675, 677, 68, 874, 881, 945);
#my %goodFiles = map {$_ => 1} (1014, 1205);
#my %goodFiles = map {$_ => 1} (1718, 7536);

my ($MTWords, $TMWords, $MTSegs, $TMSegs, $MTScore, $TMScore, $file) = map {$_ = 0} 1..7;
#my ($fileNo, $fileName);
while (my $segment = decode "UTF-8", scalar <$in>) {
	my $peSegment = defined $postEdited ? decode "UTF-8", scalar <$pe> : undef;
#	if ($segment =~ m!<file!) {
#		if ($file) {
#			if ($fileNo && $goodFiles{$fileNo}) {
#				print encode "UTF-8", "File ${fileNo}.$fileName:\n";
#				print encode "UTF-8", "\tMT Segments: $MTSegs; MT Words: $MTWords; MT avg Words: ".($MTSegs ? $MTWords/$MTSegs : 0)."; MT avg Score: ".($MTSegs ? $MTScore/$MTSegs : 0)."\n";
#				print encode "UTF-8", "\tTM Segments: $TMSegs; TM Words: $TMWords; TM avg Words: ".($TMSegs ? $TMWords/$TMSegs : 0)."; TM avg Score: ".($TMSegs ? $TMScore/$TMSegs : 0)."\n";
#			}
#			($MTWords, $TMWords, $MTSegs, $TMSegs, $MTScore, $TMScore) = map {$_ = 0} 1..6;
#		}
#		($fileNo, $fileName) = $segment =~ m!<file.*?SW_ProdTest/en/(\d+)\.(.+?)\.en\.html!;
#		++$file;
#	}
	$segment =~ s/^.+(?=<trans-unit)//s;
	if ($segment =~ /<trans-unit/) {
		$peSegment =~ s/^.+(?=<trans-unit)//s;
		die encode "utf-8", "1. FUCK the mismatched XLIFFs!\n" unless defined $peSegment && $peSegment =~ /<trans-unit/;
		
		my ($source, $target) = $segment =~ m!^.*?<source>(.*?)</source><target>(.*?)</target>.*$!s;
		die encode "utf-8", "Could not handle segment «$segment»\n" unless defined $source;
		my ($peSource, $peTarget) = $peSegment =~ m!^.*?<source>(.*?)</source><target>(.*?)</target>.*$!s if defined $peSegment;
		die encode "utf-8", "2. FUCK the mismatched XLIFFs!\n$source --> $peSource\n" unless !(defined $peSegment) || $source eq $peSource;
		$source =~ s!^\s+|\s+$!!sg;
		$target =~ s!^\s+|\s+$!!sg;
		$source =~ s!<ph.*?({\d+})</ph>!$1!sg;
		$target =~ s!<ph.*?({\d+})</ph>!$1!sg;
		if (defined $peTarget) {
			$peTarget =~ s!^\s+|\s+$!!sg;
			$peTarget =~ s!<ph.*?({\d+})</ph>!$1!sg;
		}
#		print encode "UTF-8", "$source\n$target\n\n";

		my ($score, $wc, $transType) = $segment =~ m!^.*<iws\:segment-metadata tm_score\=\"(.+?)\".*?ws_word_count\=\"(.+?)\".*?(?:translation_\w+?\=\"(.+?)\".*?)?$!s;
		$score =~ s/^-(\d+)(\d{3})$/-$1.$2/;
		$score =~ s/^-(\d+),(\d{3})\.00$/-$1.$2/;
		$transType ||= "fuzzy";
		
		if ($transType eq "machine_translation_mt" || ($transType eq "fuzzy" && $score < 100)) {
#		if ($score < 100) {
			unless ($transType eq "fuzzy") {
				$MTWords += $wc;
				++$MTSegs;
				$MTScore += $score;
			} else {
				$TMWords += $wc;
				++$TMSegs;
				$TMScore += $score;
			}
			if (defined $peTarget) {
				print encode "UTF-8", "$source$target$peTargetGWD__Alpha__all$wc".($transType eq "fuzzy" ? "Fuzzy" : "MT")."$score1◊÷\n";
			} else {
				print encode "UTF-8", "$source --> $target\n";
			}
#		} else {
#			$TMWords += $wc;
#			++$TMSegs;
#			$TMScore += $score;
		}
		
	} else {
#		print encode "UTF-8", "BAD SEGMENT\n";
	}
}
#if ($fileNo && $goodFiles{$fileNo}) {
#	print encode "UTF-8", "File ${fileNo}.$fileName:\n";
print STDERR encode "UTF-8", "\tMT Segments: $MTSegs; MT Words: $MTWords; MT avg Words: ".($MTSegs ? $MTWords/$MTSegs : 0)."; MT avg Score: ".($MTSegs ? $MTScore/$MTSegs : 0)."\n";
print STDERR encode "UTF-8", "\tTM Segments: $TMSegs; TM Words: $TMWords; TM avg Words: ".($TMSegs ? $TMWords/$TMSegs : 0)."; TM avg Score: ".($TMSegs ? $TMScore/$TMSegs : 0)."\n";
#}


close $in;



1;