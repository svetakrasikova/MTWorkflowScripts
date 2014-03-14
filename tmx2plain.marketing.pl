#!/usr/bin/perl -ws

#####################
#
# A utility to convert TMX data to plain aligned text
#
# © 2009–2010 Венцислав Жечев
# © 2011–2013 Autodesk Development Sàrl
#
# created  14 Oct 2009
# modified 11 Jan 2013 by Ventsislav Zhechev
#
# Changelog
# version 1.5.1
# Updated to handle some RTF-based peculiarities of Marketing TMs.
# The output is now formatted like TM_..._ALL.bz2 files.
#
# version 1.5
# Changed to handle zipped Trados export with UTF16-BE encoding.
# Removed TDA-specific code.
# Updated to use latest release of XML::TMX::Reader (.23+)
#
# version 1.1
# Changed the command-line option handling.
# Added an option to extract only data from a specific organisation.
#
# version 1.0
# Modified to suit data downloaded from TDA.
# Improved regex practices
#
# version 0.9
# Any leftover whitespace at the beginning or end of segments is now also being stripped.
# Translation pairs where there is a sentence-length ratio greater than the standard GIZA++ fertility limit are now being skipped.
# (Caveat: read-in of bzip2 files is not currently supported due to the way the XML::TMX::Reader works.)
#
# version 0.8
# Added normalisation of whitespace — all and any amount of whitespace is converted to single space characters.
# Translation pairs where there is an empty segment for one of the languages are now skipped.
#
# version 0.7
# The script now removes new lines from within translation units.
#
# version 0.6
# Modified the filename conversion so that it would work with any .tmx or .bz2 file
#
# version 0.5
# Basic version dealing specifically with DGT TMs.
#
#####################

use strict;
use utf8;
use Encode qw/encode decode/;

$| = 1;

#use IO::Uncompress::Unzip;

use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);
#use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use XML::TMX::Reader;

our ($fileName);
die encode "utf-8", "Usage: $0 -fileName=…\n" unless defined $fileName;

#my $fileName = $ARGV[0];
print STDERR encode "utf-8", "Using TMX file ‘$fileName’\n";

system "bunzip2 \"$fileName\"";
$fileName =~ s/.bz2$//;
my $origFileName = $fileName;

my $reader = XML::TMX::Reader->new($fileName);
$reader->ignore_markup(0);

my @languages = sort {$a eq "EN-US" ? -1 : ($b eq "EN-US" ? 1 : $a cmp $b)} $reader->languages();
local $" = "; ";
print STDERR encode "utf-8", "Languages: @languages\n";

$fileName =~ s/^(.*)(?:_.._..)?\.(?:tmx|zip)(?:\.bz2)?/$1/;
local $" = "_";
$fileName .= "_@languages.txt.bz2";
print STDERR encode "utf-8", "Outputting to file: $fileName\n";
#open (OUT, ">:utf8", $fileName);
my $out = new IO::Compress::Bzip2 $fileName
or die encode "utf-8", "Cannot write file “$fileName”: $Bzip2Error\n";

my $tus =
#my $errWrongType =
my $errDiamonds =
#my $errNoJapanese =
my $errEmpty =
0;

$reader->for_tu(sub {
	local $" = ", ";
	local $| = 1;
	my $tu = shift;
	++$tus;
	print STDERR "." if ($tus % 1000 == 0);
#	print STDOUT "tu is:\n", (values %$tu), "\n===\n";
	
#	if ($tu->{-prop}->{"tda-type"} ne "Software Strings and Documentation") {
#		print STDERR "«$tus»";
#		++$errWrongType;
#		return;
#	}
	my $pair = "";
	my $tokens = 0;
	foreach my $key (sort {$a eq "EN-US" ? -1 : ($b eq "EN-US" ? 1 : $a cmp $b)} keys %$tu) {
		unless ($key =~ m"^-"m) {
			my $line = $tu->{$key}->{-seg};
			if ($line =~ /♦♦♦/) {
				print STDERR encode "utf-8", "«$tus»";
				++$errDiamonds;
				return;
			}
#			unless ($key =~ /en/ || $line =~ /[\p{Script:Hiragana}\p{Script:Katakana}\p{Script:Han}]+/) {
#				print STDERR "«$tus»";
#				++$errNoJapanese;
#				return;
#			}
			$line =~ s!<br(?:/)?>! !g;
			$line =~ s/\n+//g;
			$line =~ s/\r+//g;
			$line =~ s!<ut>.*?</ut>!!g;
			$line =~ s/<!\[CDATA\[|\]\]>//g;
			$line =~ s/(?<![A-Z]:)(?:\\[rn])+/ /g;
			$line =~ s!<([\w:-]+).*?>(?:.*?</\1>)?!{1}!g;
			$line =~ s!<[\w:-]+[^>]*?/>!{1}!g;
			$line =~ s!</[\w:-]+>!{1}!g;
			$line =~ s!<\?[\w:-]+[^>]*?\?>!{1}!g;
			my $ph = 0;
			$line =~ s/(?<=\{)\d+(?=\})/++$ph/ge;
			$line =~ s/\s+/ /g;
			$line =~ s/(?:^\s+)|(?:\s+$)//g;
			$line =~ s/\\0$//g;
			$line =~ s/\\'/\'/g;
			$line =~ s/^{\\field.*?}?}}\s*(?!{)//;
			if ($line =~ /^\s*$/) {
				print STDERR encode "utf-8", "«$tus»";
#				$pair = "";
				++$errEmpty;
				return;
			}
#			unless ($tokens) {
#				$tokens = () = split ' ', $line, -1;
#			} else {
#				my $newTokens = () = split ' ', $line, -1;
#				if ($newTokens > $tokens ? (1. * $newTokens)/$tokens > 9. : (1. * $tokens)/$newTokens > 9.) {
#					print STDERR "Bad pair $tus (length disparity)\t";
#					$pair = "";
#					++$skippedTus;
#					last;
#				}
#			}
			$pair .= "$line";
		}
	}
	print $out "$pair◊÷\n";
});

system "bzip2 \"$origFileName\"";

$" = "/";
print STDERR encode "utf-8", "\nProcessed $tus translation units for language pair @languages.\nOutput ".
#($tus - $errWrongType - $errDiamonds - $errNoJapanese - $errEmpty)
($tus - $errDiamonds - $errEmpty)
." translation units.\n"
#."Skipped due to wrong data type: $errWrongType\n"
."Skipped due to ♦♦♦: $errDiamonds\n"
#."Skipped due to target not containing Japanese: $errNoJapanese\n"
."Skipped due to an empty segment: $errEmpty\n";



1;