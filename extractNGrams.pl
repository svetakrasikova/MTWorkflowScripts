#!/usr/bin/perl -ws
#
# ©2011–2012 Autodesk Development Sàrl
# Created on 15 May 2012 by Ventsislav Zhechev
# Last modified on 15 May 2012 by Ventsislav Zhechev
#
# ChangeLog
# v1.0
#
####################

use strict;
use utf8;

use Encode qw/encode decode/;
use IO::Compress::Bzip2 qw/$Bzip2Error/;
use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;


$| = 1;
$" = " ";

select STDERR;
$| = 1;

our ($input, $output, $lang, $maxNGram);
die "Usage: $0 -input=… -output=… -lang=… -maxNGram=…\n"
unless defined $input && defined $output && defined $lang && defined $maxNGram;

require "/Volumes/OptiBay/ADSK_Software/tokenise.pl"
or die encode "utf-8", "Could not load tokeniser at /Volumes/OptiBay/ADSK_Software/tokenise.pl\n";
my $tokeniserData = &initTokeniser($lang, 1);

my $in = new IO::Uncompress::Bunzip2 $input
or die encode "utf-8", "Could not read input file $input: $Bunzip2Error\n";


my %ngrams;

while (<$in>) {
	chomp;
	my @line = split ' ', &tokenise($tokeniserData, decode "utf-8", $_);
	for (my $i = 0; $i < @line; ++$i) {
		foreach (1..$maxNGram) {
			++($ngrams{$_}->{"@line[$i..($i+$_-1)]"}) unless $i+$_ > $#line;
		}
	}
}

close $in;


my $out = new IO::Compress::Bzip2 $output
or die encode "utf-8", "Could not write output file $output: $Bzip2Error\n";

foreach my $ngram (1..$maxNGram) {
	print $out encode("utf-8", "$_\t$ngrams{$ngram}->{$_}\n") foreach sort {lc $a cmp lc $b} keys %{$ngrams{$ngram}};
#	print STDOUT encode("utf-8", "$_\t$ngrams{$ngram}->{$_}\n") foreach sort {lc $a cmp lc $b} keys %{$ngrams{$ngram}};
}

close $out;


1;