#!/usr/bin/perl -ws
#
# ©2011–2014 Autodesk Development Sàrl
# Created on 15 May 2012 by Ventsislav Zhechev
#
# ChangeLog
# v2.0		Last modified by Ventsislav Zhechev on 26 Mar 2014
# Updated to process a list of sources in parallel.
# Updated to skip ngrams containing punctuation tokens.
#
# v1.0		Last modified by Ventsislav Zhechev on 15 May 2012
# Initial version
#
####################

use strict;
use utf8;

use threads;
use Thread::Queue;

use Encode qw/encode decode/;
use IO::Compress::Bzip2 qw/$Bzip2Error/;
use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;
use List::Util qw/shuffle/;


$| = 1;
$" = " ";

select STDERR;
$| = 1;

our ($inputFolder, $outputFolder, $maxNGram, $threads);
die "Usage: $0 -inputFolder=… -outputFolder=… [-maxNGram=…] [-threads=…]\n"
unless defined $inputFolder && defined $outputFolder;

$maxNGram ||= 7;
$threads ||= 8;

my @languages = shuffle qw/ARA CHS CHT CSY DEU DNK ELL ENA ENG ESP FIN FRA FRB FRC HUN IND ITA JPN KOR LAS NLD NOR PLK PTB PTG ROM RUS SLK SWE THA TUR VIT/;

require "/OptiBay/ADSK_Software/tokenise.pl"
or die encode "utf-8", "Could not load tokeniser at /OptiBay/ADSK_Software/tokenise.pl\n";
my $tokeniserData = &initTokeniser("en", 1);


my $extractions = new Thread::Queue;

my $extract = sub {
	for (;;) {
		my $language;
		unless ($language = $extractions->dequeue()) {
			print STDOUT threads->tid().": Finished work!\n";
			last;
		}
		
		my $in = new IO::Uncompress::Bunzip2 "$inputFolder/$language/corpus.en.bz2"
		or die encode "utf-8", "Could not read input file $inputFolder/$language/corpus.en.bz2: $Bunzip2Error\n";
		
		my %ngrams;
		while (<$in>) {
			my ($line, undef) = split /◊/;
			my @segments = split / ?[\&\?\!\,\"\:\;\(\)\{\}\[\]\\\/\%\#\$\*\+\|] ?/, $line;
			foreach my $line (@segments) {
				my @line = split / /, &tokenise($tokeniserData, decode "utf-8", $line);
				if (@line <= $maxNGram) {
					++$ngrams{"@line"};
				} else {
					for (my $i = 0; $i < @line - $maxNGram; ++$i) {
						++$ngrams{"@line[$i..($i+$maxNGram)]"};
					}
				}
			}
		}
		
		close $in;
		
		
		my $out = new IO::Compress::Bzip2 "$outputFolder/ngrams.$language.bz2"
		or die encode "utf-8", "Could not write output file $outputFolder/ngrams.$language.bz2: $Bzip2Error\n";
		
		print $out encode("utf-8", " $_ ") foreach keys %ngrams;
		print $out "\n";
		
		close $out;
		
		print STDERR "Generated ".scalar(keys%ngrams)." $maxNGram-grams for language $language.\n"
	}
};

my @workers = map { scalar threads->create($extract) } 1..$threads;

$extractions->enqueue($_) foreach shuffle @languages;


$extractions->enqueue(undef) foreach 1..$threads;
$_->join() foreach @workers;




1;