#!/usr/bin/perl -ws

#####################
#
# A utility to generate the necessary SGML-annotated files for evaluating Machine Translation runs,
# execute the evaluation scripts and collect the relevant scores.
#
# © 2011 Венцислав Жечев
# © 2011–2012 Autodesk Development Sàrl
#
# created  23 Apr 2010 by Ventsislav Zhechev
# modified 02 Jul 2012 by Ventsislav Zhechev
# 
# Change Log:
# v2.2
# Full-featured to produce per-segment score file with all metrics except BLEU.
#
# v2.1.6
# Added a switch to make TER case-sensitive.
# Added a switch for GTM to use an exponent of 3.0, in order to better asses reordering issues.
# Added a switch for Meteor to keep punctuation when performing internal normailsation.
# Added a switch to run metrics on a per-segment basis. (implies noBleu)
#
# v2.1.5
# Fixed a bug where the PER, Precision and Recall calculations were performed one extra time after all input has been read.
#
# v2.1.4
# Improved informational messages.
#
# v2.1.3
# Imposed hard limit maximum data set size for BLEU calculation of 100000 segments.
#
# v2.1.2
# Added an option to exclude METEOR from the score calculation.
#
# v2.1.1
# Changed the split mode for segment length calculation.
#
# v2.1
# Adjusted to apply to per-product evaluation.
#
# v2.0.1
# Updated some debug messages.
#
# v2.0
# Switched to using named command line parameters.
# Added GTM to the list of metrics.
# It is now possible to switch off BLEU/NIST.
#
# v1.9.1
# Fixed a syntactic bug.
#
# v1.9
# All space is converted to plain space to avoid confusing the scorers.
#
# v1.8
# Made sure to change the decimal point to decimal comma for all values.
#
# v1.7
# The fourth command-line argument now is a -separated list of systems to work on
# 
# v1.6
# Renamed WER to PER (Position-independent Error Rate) to better reflect the common usage of the terms
#
# versoin 1.5
# Modified to suit the Autodesk process
#
# Change Log:
# v1.1
# Added WER, precision and recall calculation.
#
# v1.0
# Added the collection of processing times.
#
# v0.9
# Added automatic tar+bzip2 archiving of the temporary files needed for the computation of the evaluation scores.
#
# v0.8
# Added code to generate the necessary files in the proper format and run TER.
# Adding the processing of additional setups is now as easy as adding an element to the @setups list. This, however, requires the necessary translations to be present on the corresponding lines in the $translations file.
# Also, only the base of the input file names has to be given, as well as the languages in question. This saves on typing somewhat.
# 
# v0.7
# Initial version doing full processing of BLEU, NIST and METEOR scores.
#
#####################

use strict;
no strict "refs";

use utf8;

use List::Util qw[min];

use IO::Compress::Bzip2 qw($Bzip2Error);
use IO::Uncompress::Bunzip2 qw($Bunzip2Error);

use Encode qw(encode decode);

our ($sourceLanguage, $targetLanguage);
our $fileNameBase;
our $setups;
our ($baseDir, $meteorPath, $meteorScript, $bleuPath, $bleuScript, $terTool, $gtmTool);
our ($noBleu, $noNist, $noTer, $noGtm, $noMeteor);
our ($inputFile, $perSegment);
die encode("utf-8", "Usage: $0 -sourceLanguage=… -targetLanguage=… -fileNameBase=… -baseDir=… -meteorPath=… -meteorScript=… -bleuPath=… -bleuScript=… -terTool=… -gtmTool=…")
unless defined $sourceLanguage && defined $targetLanguage && defined $fileNameBase && defined $baseDir && (defined $noMeteor || (defined $meteorPath && defined $meteorScript)) && ((defined $noBleu && defined $noNist) || (defined $bleuPath && defined $bleuScript)) && (defined $noTer || defined $terTool) && (defined $noGtm || defined $gtmTool);

$meteorPath = decode "utf-8", $meteorPath;
$bleuPath = decode "utf-8", $bleuPath;
$terTool = decode "utf-8", $terTool;
$gtmTool = decode "utf-8", $gtmTool;

my $sourceFileName = "$fileNameBase/test.$sourceLanguage.tok.bz2";
my $referenceFileName = "$fileNameBase/test.$targetLanguage.tok.bz2";
my $translationFileName = "$fileNameBase/trans.$targetLanguage.tok.bz2";

if (defined $perSegment) {
	print STDERR encode "utf-8", "Using bzip2 input file ‘$inputFile’\n";
} else {
	print STDERR encode "utf-8", "Using bzip2 source files ‘$sourceFileName’\n";
	print STDERR encode "utf-8", "Using bzip2 reference files ‘$referenceFileName’\n";
	print STDERR encode "utf-8", "Using bzip2 translation files ‘$translationFileName’\n";
}

mkdir("$fileNameBase") unless -e "$fileNameBase";
mkdir("$fileNameBase/eval") unless -e "$fileNameBase/eval";
print STDERR encode "utf-8", "Outputting to files ‘${fileNameBase}/eval/*_${sourceLanguage}_$targetLanguage.*’…";
$fileNameBase = "${fileNameBase}/eval/…_${sourceLanguage}_$targetLanguage.sgm";


my @setups = $setups ? (split //, $setups, -1) : ("mt");

foreach my $setup (@setups) {
	if (defined $perSegment) {
		my $fileName = $inputFile;
		$fileName =~ s/…/$setup/;
		${"in_$setup"} = new IO::Uncompress::Bunzip2 $fileName
		or die "Could not open $inputFile: $Bunzip2Error\n";
	} else {
		my $fileName = $sourceFileName;
		$fileName =~ s/…/$setup/;
		${"in_src_$setup"} = new IO::Uncompress::Bunzip2 $fileName
		or die "Could not open $sourceFileName: $Bunzip2Error\n";
		$fileName = $referenceFileName;
		$fileName =~ s/…/$setup/;
		${"in_ref_$setup"} = new IO::Uncompress::Bunzip2 $fileName
		or die "Could not open $referenceFileName: $Bunzip2Error\n";
		$fileName = $translationFileName;
		$fileName =~ s/…/$setup/;
		${"in_tst_$setup"} = new IO::Uncompress::Bunzip2 $fileName
		or die "Could not open $translationFileName: $Bunzip2Error\n";
	}
}




foreach my $handle (map(("src_$_", "ref_$_", "tst_$_"), @setups)) {
	my $fileName = $fileNameBase;
	$fileName =~ s/…/$handle/;
	open ${"out_$handle"}, ">$fileName"
	or die "Could not open $fileName\n";
	$handle =~ /^(.*?)_/;
	print ${"out_$handle"} (encode "utf-8", "<${1}set setid=\"Autodesk\" srclang=\"$sourceLanguage\" trglang=\"$targetLanguage\">\n<DOC docid=\"1\" sysid=\"$handle\">\n");
		
	#‘Trans’ format for TER
	unless ($handle =~ m"^src_") {
		$fileName =~ s/sgm$/trans/;
		open ${"trans_$handle"}, ">$fileName"
		or die "Could not open $fileName\n";
	}
}

${"${_}Length"} = ${"${_}Count"} = 0 foreach (map(("src_$_", "ref_$_", "tst_$_"), @setups));

for (my $ID = 1, my $finished = 0; !$finished; ++$ID) {

	if (defined $perSegment) {
		local $/ = "◊÷\n";
		foreach my $setup (@setups) {
			my $line = decode "utf-8", ${"in_$setup"}->getline();
			chomp $line;
			my @line = split //, $line;
			next unless defined $line[3];
			$line[$_] =~ s/^null$// foreach (0..2);
			next if $line[0] =~ /^\s*$/ || $line[2] =~ /^\s*$/;
			$line[3] =~ tr!/ :!___!;
			my $type = $line[5];
			$type = "null" if $type =~ /^\s*$/;
			$line[$_] =~ s/[\t\r\n]+/ /g foreach (0..2);

		}
	} else {
	foreach my $setup (map(("src_$_", "ref_$_", "tst_$_"), @setups)) {
		${"${setup}Line"} = ${"in_$setup"}->getline();
		unless (${"${setup}Line"}) {
			$finished = 1;
			last;
		}
		chomp ${"${setup}Line"};
		${"${setup}Line"} = decode "utf-8", ${"${setup}Line"};
		${"${setup}Line"} =~ s/\s+/ /g;
		
		if (defined $perSegment) {
			push @{"${setup}Lines"}, ${"${setup}Line"};
			push @{"${setup}Length"}, scalar(split ' ', ${"${setup}Line"}, -1);
		} else {
			${"${setup}Length"} += scalar(split ' ', ${"${setup}Line"}, -1);
			++${"${setup}Count"};
		}
		print ${"out_$setup"} (encode "utf-8", "<seg id=$ID>".${"${setup}Line"}."</seg>\n");
		
		#Trans format for TER
		#Contains just plain lines with the segment ID in parentheses after a space at the end of each line.
		print ${"trans_$setup"} (encode "utf-8", ${"${setup}Line"}." ($ID)\n") unless ($setup =~ m"^src_");
	}
	}
	
	last if $finished;
	
	foreach my $setup (@setups) {
		#WER calculation
		my ($w, $p, $r) = &per(${"tst_${setup}Line"}, ${"ref_${setup}Line"});
		if (defined $perSegment) {
			push @{"${setup}PER"}, $w;
			push @{"${setup}Precision"}, $p;
			push @{"${setup}Recall"}, $r;
		} else {
			${"${setup}PER"} += $w;
			${"${setup}Precision"} += $p;
			${"${setup}Recall"} += $r;
		}
	}
}
print STDERR encode "utf-8", "done\n"; #Outputting to temporary files.

print STDERR encode "utf-8", "Average $_ length: ".(${"${_}Length"}/${"${_}Count"})."\n" foreach (map(("src_$_", "ref_$_", "tst_$_"), @setups));

foreach my $setup (map(("src_$_", "ref_$_", "tst_$_"), @setups)) {
	$setup =~ m"^(.*?)_";
	print ${"out_$setup"} (encode "utf-8", "</DOC>\n</${1}set>\n");
	close ${"out_$setup"};
	close ${"in_$setup"};
		
	#Trans format for TER
	close ${"trans_$setup"} unless $setup =~ m"^src_";
}

$terTool =~ s/ /\\ /g;
$gtmTool =~ s/ /\\ /g;
my @metrics = defined $perSegment ? () : ("generic");
unshift @metrics, "meteor" unless defined $noMeteor;
unshift @metrics, "ter" unless defined $noTer;
unshift @metrics, "gtm" unless defined $noGtm;
unshift @metrics, "bleu" unless defined $noBleu and defined $noNist;


my $scoreFileName = $fileNameBase;
$scoreFileName =~ s/…_(.*)sgm$/${1}scores/;
print STDERR encode "utf-8", "Scores will be written to $scoreFileName\n";
my $scoreOut = new IO::Compress::Bzip2("$scoreFileName")
or die encode "utf-8", "Could not write “$scoreFileName”\n";
print $scoreOut encode "utf-8", "Source\tPre-edit\tPost-edit\t" if defined $perSegment;
print $scoreOut encode "utf-8", "Product\tRelease\tComponent\tMatch\t";
print $scoreOut encode "utf-8", "BLEU\t" unless defined $noBleu;
print $scoreOut encode "utf-8", "NIST\t" unless defined $noNist;
print $scoreOut encode "utf-8", "GTM\t" unless defined $noGtm;
print $scoreOut encode "utf-8", "TER\t" unless defined $noTer;
print $scoreOut encode "utf-8", "METEOR\t" unless defined $noMeteor;
print $scoreOut encode "utf-8", "PER\tPrecision\tRecall\t".(defined $perSegment ? "" : "Segments\t")."Length\n";

my ($prefix, $suffix) = $fileNameBase =~ /^(.*)…(.*)\.sgm$/;
	
foreach my $setup (@setups) {
	unless (defined $perSegment || (defined $noBleu && defined $noNist) || ${"tst_${setup}Count"} > 100000) {
		print STDERR encode "utf-8", "Computing ".(defined $noBleu ? "" : "BLEU").((defined $noBleu || defined $noNist) ? "" : "/").(defined $noNist ? "": "NIST")." scores for setup $setup…";
		system("cd \"$bleuPath\"; /usr/bin/perl $bleuScript -s \"$baseDir/${prefix}src_$setup$suffix.sgm\" -t \"$baseDir/${prefix}tst_$setup$suffix.sgm\" -r \"$baseDir/${prefix}ref_$setup$suffix.sgm\" >\"$baseDir/$prefix$setup$suffix.bleu.score\" 2>/dev/null");
		print STDERR encode "utf-8", "done\n";
	}
	
	unless (defined $noGtm) {
		print STDERR encode "utf-8", "Computing GTM scores for setup $setup…";
		system("java -Xmx2048M -jar $gtmTool ".(defined $perSegment ? "+s -d" : "-s +d")." -e 3 \"$baseDir/${prefix}tst_$setup$suffix.sgm\" \"$baseDir/${prefix}ref_$setup$suffix.sgm\" >\"$baseDir/$prefix$setup$suffix.gtm.score\" 2>/dev/null");
		print STDERR encode "utf-8", "done\n";
	}

	unless (defined $noTer) {
		print STDERR encode "utf-8", "Computing TER scores for setup $setup…";
		system("java -Xmx2048M -jar $terTool ".(defined $perSegment ? "-n \"$baseDir/$prefix$setup$suffix\"" : "")." -s -r \"$baseDir/${prefix}ref_$setup$suffix.trans\" -h \"$baseDir/${prefix}tst_$setup$suffix.trans\" >\"$baseDir/$prefix$setup$suffix.ter.score\" 2>/dev/null");
		print STDERR encode "utf-8", "done\n";
	}
	
	unless (defined $noMeteor) {
		print STDERR encode "utf-8", "Computing METEOR scores for setup $setup…";
		system("cd \"$meteorPath\"; /usr/bin/perl $meteorScript --keepPunctuation -s \"tst_$setup\" -t \"$baseDir/${prefix}tst_$setup$suffix.sgm\" -r \"$baseDir/${prefix}ref_$setup$suffix.sgm\" ".(defined $perSegment ? "--plainOutput -outFile " : ">")."\"$baseDir/$prefix$setup$suffix.meteor.score\" 2>/dev/null");
		print STDERR encode "utf-8", "done\n";
	}
	
	print $scoreOut encode "utf-8", (join "\t", split /__/, $setup)."\t" unless defined $perSegment;
	my $segments;
	foreach my $score (@metrics) {
		my $fileName = "$prefix$setup$suffix.$score".(defined $perSegment && $score eq "ter" ? "" : ".score");
		$fileName =~ s/ /\\ /g;
		if (defined $perSegment) {
			open my $file, "<$fileName"
			or die encode "utf-8", "Cannot open file “$fileName”!\n";
			
			if ($score eq "ter") {
				scalar <$file> foreach 1..2;
				while (my $score = <$file>) {
					(undef, undef, undef, $score) = split / /, $score, -1;
					$score =~ s/./,/;
					push @{"${setup}TER"}, $score;
				}
			} elsif ($score eq "gtm") {
				while (my $score = <$file>) {
					(undef, undef, $score) = split / /, $score, -1;
					$score =~ s/./,/;
					push @{"${setup}GTM"}, $score;
				}
			} elsif ($score eq "meteor") {
				while (my $score = <$file>) {
					(undef, $score) = split / /, $score, -1;
					$score =~ s/./,/;
					push @{"${setup}METEOR"}, $score;
				}
			}
			
			close $file;
		} else {
			my $data = `cat $fileName` unless ($score eq "bleu" && ${"tst_${setup}Count"} > 100000) || $score eq "generic";
			if ($score eq "bleu") {
				unless (${"tst_${setup}Count"} > 100000) {
					print $scoreOut encode "utf-8", (join ",", ($data =~ /BLEU score = (\d+)\.(\d+)/))."\t" unless defined $noBleu;
					print $scoreOut encode "utf-8", (join ",", ($data =~ /NIST score = (\d+)\.(\d+)/))."\t" unless defined $noNist;
				} else {
					print $scoreOut encode "utf-8", "0\t" unless defined $noBleu;
					print $scoreOut encode "utf-8", "0\t" unless defined $noNist;
				}
			} elsif ($score eq "ter") {
				print $scoreOut encode "utf-8", (join ",", ($data =~ /Total TER: (\d+)\.(\d+)/))."\t";
			} elsif ($score eq "gtm") {
				print $scoreOut encode "utf-8", (join ",", ($data =~ /1 (\d+)\.(\d+)/))."\t";
			} elsif ($score eq "meteor") {
				print $scoreOut encode "utf-8", (join ",", ($data =~ /Meteor Score: (\d+)\.(\d+)/))."\t";
			} elsif ($score eq "generic") {
				if (${"tst_${setup}Count"}) {
					my $temp;
					$temp .= (${"${setup}PER"}/${"tst_${setup}Count"})."\t";
					$temp .= (${"${setup}Precision"}/${"tst_${setup}Count"})."\t";
					$temp .= (${"${setup}Recall"}/${"tst_${setup}Count"})."\t";
					$temp .= ${"tst_${setup}Count"}."\t";
					$temp .= (${"tst_${setup}Length"}/${"tst_${setup}Count"})."\n";
					$temp =~ s/(?<=\d)\.(?=\d)/,/g;
					print $scoreOut encode "utf-8", $temp;
				} else {
					print $scoreOut encode "utf-8", "0\t0\t0\t0\t0\n";
				}
			}
		}
	}
	
	if (defined $perSegment) {
		for (my $i = 0; $i < @{"${setup}Lines"}; ++$i) {
			print $scoreOut ${"${setup}Lines"}[$i]."\t";
		}
	}
}

close $scoreOut;

my $bzFileName = $fileNameBase;
$bzFileName =~ s/…_(.*)sgm$/${1}eval.tar.bz2/;
$bzFileName =~ s/ /\\ /g;
$fileNameBase =~ s/…_(.*)sgm$/*$1/;
print STDERR encode "utf-8", "Archiving temporary files…";
system("tar -cjf $bzFileName $fileNameBase*sgm $fileNameBase*trans $fileNameBase*score; rm -f $fileNameBase*sgm $fileNameBase*trans $fileNameBase*score");
print STDERR encode "utf-8", "done\n";


1;


sub per {
	my ($src, $ref) = @_;
	my (%src, %ref);
	++$src{$_} foreach (split ' ', $src);
	++$ref{$_} foreach (split ' ', $ref);
	
	my $precision = my $recall = my $count = 0;
	
	foreach (keys %src) {
		$count += $src{$_};
		if (defined $ref{$_}) {
			$precision += min($src{$_}, $ref{$_});
		}
	}
	$precision /= 1.*$count if $count;
	
	$count = 0;
	foreach (keys %ref) {
		$count += $ref{$_};
		if (defined $src{$_}) {
			$recall += min($src{$_}, $ref{$_});
		}
	}
	$recall /= 1.*$count if $count;
	
	(1 - (($precision == 0 && $recall == 0) ? 0. : (2.*$precision*$recall)/($precision + $recall)), $precision, $recall);
}