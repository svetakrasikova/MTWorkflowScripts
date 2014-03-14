#!/usr/bin/perl -ws
#
# ©2011 Autodesk Development Sàrl
# Created on 29 May 2012 by Ventsislav Zhechev
# Last modified on 29 May 2012 by Ventsislav Zhechev
#
# ChangeLog
# v0.1
# Initial version
#
###########################

use strict;
use utf8;
use Encode qw/encode decode/;

use IO::Uncompress::Unzip;


$| = 1;


our ($input);

die encode("UTF-8", "Usage: $0 -input=…\n")
unless defined $input;


my $in = new IO::Uncompress::Unzip $input
or die encode "UTF-8", "Cannot read file $input!\n";


$/ = "</trans-unit>";
#my %goodFiles = map {$_ => 1} (1099, 1100, 1146, 116, 1160, 1162, 122, 126, 1276, 1375, 1379, 1380, 1402, 141, 1427, 145, 153, 1535, 1550, 1551, 158, 1588, 1590, 1602, 1610, 1628, 1635, 1636, 1779, 1845, 1878, 191, 1997, 2120, 2133, 2134, 2162, 2230, 2233, 2278, 2286, 2350, 2398, 2430, 2474, 256, 2627, 2787, 2856, 2860, 2870, 2878, 2879, 2917, 2923, 2941, 298, 30, 3019, 3052, 3161, 3173, 3253, 3328, 3342, 3367, 3368, 3381, 3425, 3431, 3435, 3465, 3473, 3477, 3479, 354, 357, 3581, 3586, 3590, 3611, 3626, 3636, 3643, 366, 368, 3696, 3736, 374, 375, 3756, 3759, 3833, 4027, 4075, 4077, 41, 4157, 4166, 4172, 4181, 4197, 4201, 4321, 4328, 4354, 4387, 4394, 4409, 4422, 4423, 587, 674, 675, 677, 68, 874, 881, 945);
#my %goodFiles = map {$_ => 1} (1014, 1205);
#my %goodFiles = map {$_ => 1} (1718, 7536);

my ($MTWords, $TMWords, $MTSegs, $TMSegs, $MTScore, $TMScore, $file) = map {$_ = 0} 1..7;
my ($fileNo, $fileName);
while (my $segment = decode "UTF-8", scalar <$in>) {
	if ($segment =~ m!<file!) {
#		if ($file) {
#			if ($fileNo && $goodFiles{$fileNo}) {
#				print encode "UTF-8", "File ${fileNo}.$fileName:\n";
#				print encode "UTF-8", "\tMT Segments: $MTSegs; MT Words: $MTWords; MT avg Words: ".($MTSegs ? $MTWords/$MTSegs : 0)."; MT avg Score: ".($MTSegs ? $MTScore/$MTSegs : 0)."\n";
#				print encode "UTF-8", "\tTM Segments: $TMSegs; TM Words: $TMWords; TM avg Words: ".($TMSegs ? $TMWords/$TMSegs : 0)."; TM avg Score: ".($TMSegs ? $TMScore/$TMSegs : 0)."\n";
#			}
#			($MTWords, $TMWords, $MTSegs, $TMSegs, $MTScore, $TMScore) = map {$_ = 0} 1..6;
#		}
		($fileNo, $fileName) = $segment =~ m!<file.*?SW_ProdTest/en/(\d+)\.(.+?)\.en\.html!;
		++$file;
	}
	$segment =~ s/^.+(?=<trans-unit)//s;
	if ($segment =~ /<trans-unit/) {
		
		my ($source, $target) = $segment =~ m!^.*?<source>(.*?)</source>.*$!s;
		unless (defined $source) {
			die encode "utf-8", "Could not handle segment «$segment»\n";
		}
		$source =~ s!^\s+|\s+$!!sg;
#		$target =~ s!^\s+|\s+$!!sg;
		$source =~ s!<ph.*?({\d+})</ph>!$1!sg;
#		$target =~ s!<ph.*?({\d+})</ph>!$1!sg;
#		print encode "UTF-8", "$source\n$target\n\n";

		my ($score, $wc) = $segment =~ m!^.*<iws\:segment-metadata tm_score\=\"(.+?)\".*?ws_word_count\=\"(.+?)\".*?$!s;
		
#		if ($status =~ /machine_translation_mt/) {
		if ($score < 100) {
			$MTWords += $wc;
			++$MTSegs;
			$MTScore += $score;
			print encode "UTF-8", "$source\n";
		} else {
			$TMWords += $wc;
			++$TMSegs;
			$TMScore += $score;
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

#print encode "UTF-8", "MT Segments: $MTSegs; MT Words: $MTWords; MT avg Words: ".($MTSegs ? $MTWords/$MTSegs : 0)."; MT avg Score: ".($MTSegs ? $MTScore/$MTSegs : 0)."\n";
#print encode "UTF-8", "TM Segments: $TMSegs; TM Words: $TMWords; TM avg Words: ".($TMSegs ? $TMWords/$TMSegs : 0)."; TM avg Score: ".($TMSegs ? $TMScore/$TMSegs : 0)."\n";




1;