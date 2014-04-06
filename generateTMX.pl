#!/usr/bin/perl -sw
#
#
# ©2011–2014 Autodesk Development Sàrl
#
# Change log
# v2.1.1	Last modified by Ventsislav Zhechev on 06 Apr 2014
# Added AR to the language list.
#
# v2.1		Last modified by Ventsislav Zhechev on 26 Feb 2014
# Now we no longer use CDATA to protect the segments from messing up the XML. Instead, we use HTML::Escape to manually escape any problematic characters.
#
# v2			Last modified by Ventsislav Zhechev on 18 Feb 2014
# Modified to process a list of languages in parallel.
#
# v1.1.1	Last modified by Ventsislav Zhechev on 17 Feb 2014
# Modified to handle corpus data containing product information.
#
# v1.1		Last modified by Ventsislav Zhechev on 03 Apr 2013
# Now properly TMX-escapes WorldServer placeholders.
#
# v1			Last modified by Ventsislav Zhechev on 18 Jan 2013
# Added code to generate several TMX files with an upper limit of 3000000 segments per file. This requires the user to supply a output file name.
#
# v0.9		Last modified by Ventsislav Zhechev on 16 Jan 2013
# Allows the user to select gzip or bzip2 compression for the generated TMX file, when an output file name is given.
#
#################################

use strict;
use utf8;

use threads;
use Thread::Queue;

use Encode qw/encode decode/;
use List::Util qw/shuffle/;
use XML::TMX::Writer;

use IO::Uncompress::Bunzip2;
use HTML::Escape qw/escape_html/;

our ($corpusPath, $outputPath, $gzip, $bzip2, $threads);

die encode "utf-8", "Usage: $0 -corpusPath=… -outputPath=… [{-gzip|-bzip2}] [-threads=…]\n"
unless defined $corpusPath && defined $outputPath;
$threads ||= 8;

my @languages = (
{ short => "AR", long => "ARA", corpus => "ar" },
{ short => "CS", long => "CSY", corpus => "cs" },
{ short => "DA", long => "DNK", corpus => "da" },
{ short => "DE", long => "DEU", corpus => "de" },
{ short => "ES-ES", long => "ESP", corpus => "es" },
{ short => "ES-MX", long => "LAS", corpus => "es_mx" },
{ short => "FI", long => "FIN", corpus => "fi" },
{ short => "FR-FR", long => "FRA", corpus => "fr" },
{ short => "HU", long => "HUN", corpus => "hu" },
{ short => "IT", long => "ITA", corpus => "it" },
{ short => "JA", long => "JPN", corpus => "jp" },
{ short => "KO", long => "KOR", corpus => "ko" },
{ short => "ES-MX", long => "LAS", corpus => "es_mx" },
{ short => "NL", long => "NLD", corpus => "nl" },
{ short => "NO", long => "NOR", corpus => "no" },
{ short => "PL", long => "PLK", corpus => "pl" },
{ short => "PT-BR", long => "PTB", corpus => "pt_br" },
{ short => "PT-PT", long => "PTG", corpus => "pt_pt" },
{ short => "RO", long => "ROM", corpus => "ro" },
{ short => "RU", long => "RUS", corpus => "ru" },
{ short => "SV", long => "SWE", corpus => "sv" },
{ short => "TR", long => "TUR", corpus => "tr" },
{ short => "VI", long => "VIT", corpus => "vi" },
{ short => "ZH-CN", long => "CHS", corpus => "zh_hans" },
{ short => "ZH-TW", long => "CHT", corpus => "zh_hant" },
);

my $work = new Thread::Queue;

my $sourceLanguage = "EN-US";

my $generator = sub {
	while (my $language = $work->dequeue()) {
		last unless defined $language;
		
		my $targetLanguage = $language->{short};
		my $source = "$corpusPath/$language->{long}/corpus.en.bz2";
		my $target = "$corpusPath/$language->{long}/corpus.$language->{corpus}.bz2";
		my $output = "$outputPath/EN-$language->{short}.tmx";
		print encode "utf-8", "Processing data (EN-$language->{short})…";

		my $tmx;
		unless (defined $output) {
			$tmx = new XML::TMX::Writer();
			$tmx->start_tmx(
			srclang => $sourceLanguage,
			)
		} else {
			$output =~ s/.tmx$//;
		}

		$source = new IO::Uncompress::Bunzip2($source)
		or die encode "utf-8", "Cannot open file ‘$source’ for reading!\n";
		$target = new IO::Uncompress::Bunzip2($target)
		or die encode "utf-8", "Cannot open file ‘$target’ for reading!\n";

		local $| = 1;
		my $countTMX = 0;
		my $full = 1;
		while (my $sourceLine = decode("utf-8", $source->getline()), my $targetLine = decode("utf-8", $target->getline())) {
			print "." unless $. % 100000;

			if (!($. % 3000000) && defined $output) {
				$full = 1;
				$tmx->end_tmx();
				print "TMX segment limit reached! ($.)\n";
				print encode "utf-8", "Compressing TMX $countTMX…";
				if (defined $bzip2) {
					system "bzip2 $output.$countTMX.tmx";
				} else {
					system "gzip $output.$countTMX.tmx";
				}
				print "done!\n";
				print encode "utf-8", "Resuming processing (EN-$language->{short})…";
			}

			if ($full && defined $output) {
				++$countTMX;
				$full = 0;
				$tmx = new XML::TMX::Writer();
				$tmx->start_tmx(-output	=> "$output.$countTMX.tmx",
				srclang => $sourceLanguage,
				);
				if (defined $bzip2) {
					unlink "$output.$countTMX.tmx.bz2" if -e "$output.$countTMX.tmx.bz2";
				} else {
					unlink "$output.$countTMX.tmx.gz" if -e "$output.$countTMX.tmx.gz";
				}
			}
			
			($sourceLine) = $sourceLine =~ /^(.*)◊/; # Strip product code.
			$sourceLine = escape_html($sourceLine);
			$sourceLine =~ s¡(?:\{)(\d+)(?:\})¡¡<ph x="$1">{$1}</ph>¡g;
			($targetLine) = $targetLine =~ /^(.*)◊/; # Strip product code.
			$targetLine = escape_html($targetLine);
			$targetLine =~ s¡(?:\{)(\d+)(?:\})¡¡<ph x="$1">{$1}</ph>¡g;
			$tmx->add_tu(
										$sourceLanguage => $sourceLine,
										$targetLanguage => $targetLine,
										-verbatim => 1,
			);
		}

		close $source;
		close $target;

		if (defined $output) {
			$tmx->end_tmx();
			print "done! ($.)\n";
			print encode "utf-8", "Compressing TMX $countTMX…";
			if (defined $bzip2) {
				system "bzip2 $output.$countTMX.tmx";
			} else {
				system "gzip $output.$countTMX.tmx";
			}
			print "done!\n";
		}
	}
};


my @workers = map { scalar threads->create($generator) } 1..$threads;

$work->enqueue($_) foreach shuffle @languages;


$work->enqueue(undef) foreach 1..$threads;
$_->join() foreach @workers;





1;