#!/usr/bin/perl -ws
#####################
#
# ©2012–2013 Autodesk Development Sàrl
#
# Created on 02 Jul 2012 by Ventsislav Zhechev based on evaluateByProduct.pl and generate_evaluation_sets.pl by Ventsislav Zhechev
#
# Changelog
# v0.4			Modified on 18 Mar 2013 by Ventsislav Zhechev
# CFS is replaced with JFS in the output.
# Metric order in the output is changed for better readability.
# Now we output segment ID as the first field as a reference for the original segment order.
# Now we output both source and target segment length, as well as source-to-target length ratio.
#
# v0.3.2		Modified on 17 Mar 2013 by Ventsislav Zhechev
# Modified to correctly exlude segments where either the test target or the reference target are missing.
#
# v0.3.1		Modified on 14 Feb 2013 by Ventsislav Zhechev
# Added a version parameter to output into a specific folder.
#
# v0.3			Modified on 29 Nov 2012 by Ventsislav Zhechev
# Added a check to make sure that all necessary command-line options are provided.
#
# v0.2			Modified by Ventsislav Zhechev
# Added Levenshtein edit distance calculation.
#
# v0.1.1		Modified by Ventsislav Zhechev
# Added a check for the case where no relevant data was collected.
#
# v0.1
# First version.
#
#####################

use strict;
no strict "refs";

use utf8;

use List::Util qw[min];
use Cwd;

use Encode qw/encode decode/;
#use IO::Compress::Bzip2 qw/$Bzip2Error/;
use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;
use IO::Socket::INET;

use IPC::Open2;

$| = 1;

require "/OptiBay/ADSK_Software/tokenise.pl";


our ($input, $language, $testPHs, $translateFuzzy, $prodTest, $version, $mosesFuzzy);
$prodTest = 1 if defined $mosesFuzzy;
our ($meteorPath, $meteorScript, $terTool, $gtmTool);
our ($noTer, $noGtm, $noMeteor);
die encode "utf-8", "Usage: $0 -input=… -language=… [-testPHs] [-translateFuzzy] [-prodTest] [-version] {-meteorPath=… -meteorScript=…|-noMeteor} {-terTool=…|-noTer} {-gtmTool=…|-noGtm}\n"
unless defined $input && defined $language && ((defined $meteorPath && defined $meteorScript) || defined $noMeteor) && (defined $terTool || defined $noTer) && (defined $gtmTool || defined $noGtm);

my $base_dir = "/OptiBay/ADSK_Software/";
my $preprocess = $language =~ /^jp|^zh/ ? ["/usr/bin/perl", '-s', "/OptiBay/ADSK_Software/word_segmenter.pl", '-segmenter=kytea', "-model=/Users/ventzi/Desktop/Autodesk/segmentation/kytea-models/".($language =~ /^jp/ ? 'jp-0.3.0-utf8-1.mod' : 'lcmc-0.3.0-1.mod')] : "";

my ($pre_in, $pre_out);
my $pid_preprocess = 0;
if ($preprocess) {
	$pid_preprocess = open2($pre_out, $pre_in, @$preprocess)
	or die encode "utf-8", "Could not start pre-processor with command “$preprocess”\n";
	select $pre_in;
	$| = 1;
}


my $enTok = initTokeniser("en", 1);
my $tgTok = initTokeniser($language, 1);

sub movePHs {
	my $line = shift;
	my $count = $line =~ s/\{\d+\}//g;
	$line .= " {$_}" foreach 1..$count;
	return $line;
}

my %data;
my @fuzzy;
print STDERR encode "utf-8", "Ingesting data…";
{
	local $/ = "◊÷\n";
	my $in = new IO::Uncompress::Bunzip2 $input
	or die encode "utf-8", "Cannot open file “$input”: $Bunzip2Error\n";
	
	while (my $line = decode "utf-8", scalar <$in>) {
		chomp $line;
		next unless $line;
		my @line = split //, $line;
		#[0]: source; [1]: test target; [2]: ref target; [3]: product ("a__b__c"); [4]: WS word count or N/A; [5]: type; ([6]: WPD; [7]: ProdInc)
		next unless defined $line[3];
		$line[$_] =~ s/^null$// foreach (0..2);
		next if $line[0] =~ /^\s*$/ || $line[1] =~ /^\s*(\{\d+\}\s?)*\s*$/ || $line[2] =~ /^\s*$/; #Skips segments with empty source, target or reference or with target containing only WS placeholders (i.e. bad fuzzy target)
#		next if $line[1] =~ /^\s*$/ || $line[2] =~ /^\s*$/;
		next if $line[3] =~ /TESTING/;
		$line[3] =~ tr!/ :!___!;
		my @cat = split /__/, $line[3];
		my $type = $line[5];
		$type = "null" if $type =~ /^\s*$/;
#		next unless lc $type eq "fuzzy" || lc $type eq "mt" || defined $prodTest;
		$line[$_] =~ s/[\t\r\n]+/ /g foreach (0..2);
		
		my $origSrc = $line[0] if defined $translateFuzzy && lc $type eq "fuzzy";
		my $scfs = &levenshtein($line[1], $line[2], 1);
		foreach my $id (0..2) {
			$line[$id] = tokenise($id ? $tgTok : $enTok, $line[$id]);
			if ($id) {
				if ($preprocess) {
					local $/ = "\n";
					print $pre_in encode "utf-8", "$line[$id]\n";
					$line[$id] = decode "utf-8", scalar <$pre_out>;
					chomp $line[$id];
				}
				$line[$id] = movePHs($line[$id]) if $testPHs;
			}
		}
		
		push @fuzzy, [$origSrc, undef, @line[2..3], $type] if defined $translateFuzzy && lc $type eq "fuzzy";
		
		push @{$data{__data__}}, [@line[0..2], @cat, $type, $scfs];
		$data{$cat[0]}->{$cat[1]}->{$cat[2]}->{$type} = {} unless defined $data{$cat[0]}->{$cat[1]}->{$cat[2]}->{$type};
		my $currentData = $data{$cat[0]}->{$cat[1]}->{$cat[2]}->{$type};
		$currentData->{"SCFS"} += $scfs;
		if (defined $prodTest) {
			push @{$data{__data__}->[-1]}, ($line[6] || 0, $line[7] || 0);
			$currentData->{"WPD"} += $line[6] || 0;
			$currentData->{"ProdInc"} += $line[7] || 0;
		}
		++$currentData->{__count__};
		++$data{$cat[0]}->{$cat[1]}->{$cat[2]}->{__count__};
		++$data{$cat[0]}->{$cat[1]}->{__count__};
		++$data{$cat[0]}->{__count__};
	}

	close $in;
}
print STDERR encode "utf-8", "done!\n";

die encode "utf-8", "No data collected!\n" unless defined $data{__data__};

if (defined $translateFuzzy) {
	print STDERR encode "utf-8", "Translating fuzzy matches…";
	for (;;) {
		#Connect to the MT Info Service
		my $infoSocket;
		while (!$infoSocket) {
			$infoSocket = new IO::Socket::INET (PeerHost => "neucmslinux", PeerPort => 2001);
			sleep(60) unless $infoSocket;
		}
		$infoSocket->autoflush(1);
		#$infoSocket->sockopt(SO_KEEPALIVE, 1);
		
		print $infoSocket encode("utf-8", "{translate => ".(scalar @fuzzy).", targetLanguage => $language}\n");
		print $infoSocket encode("utf-8", "$_->[0]\n") foreach @fuzzy;
		$infoSocket->shutdown(1); #Won’t be writing anything else, so close socket for writing. This also sends EOF.
		
		my $data = <$infoSocket>; #Read return control sequence from MT Info Service.
		unless ($data =~ /^\{\s*(?:\w+\s*=>\s*"?(?:[\w\-?"]+|\[(?:[\w\-"]+,?\s*)+\])"?,?\s*)*\}$/) {
			$infoSocket->shutdown(0);
			$infoSocket->close();
			print STDERR encode("utf-8", "Bad response from MT Info Service: “$data”\n");
			close STDOUT;
			die;
		}
		
		#($data) = $data =~ /(^\{\s*(?:\w+\s*=>\s*"?(?:[\w\-?"]+|\[(?:[\w\-"]+,?\s*)+\])"?,?\s*)*\s*\}$)/;
		#$data = eval $data;
		#To add a check for matching number of returned segments.
		
		my @outStrings;
		my $select = IO::Select->new();
		$select->add($infoSocket);
		foreach (@fuzzy) {
			($infoSocket) = $select->can_read(60);
			last unless $infoSocket;
			
			my $line = decode "utf-8", scalar <$infoSocket>;
			chomp $line;
			push @outStrings, $line;
		}
		($infoSocket) = $select->handles();
		if ($infoSocket) {
			$infoSocket->shutdown(0);
			$infoSocket->close();
		}
		
		if ($#outStrings == $#fuzzy) {
			$fuzzy[$_]->[1] = $outStrings[$_] foreach 0..$#outStrings;
			last;
		} else {
			next;
		}
	}
	print STDERR encode "utf-8", "done!\n";
	print STDERR encode "utf-8", "Preparing translated fuzzy data…";
	foreach my $fuzzy (@fuzzy) {
		foreach my $id (0..1) {
			$fuzzy[$id] = tokenise($tgTok, $fuzzy[$id]);
			if ($preprocess) {
				print $pre_in encode "utf-8", "$fuzzy[$id]\n";
				$fuzzy[$id] = decode "utf-8", scalar <$pre_out>;
				chomp $fuzzy[$id];
			}
			$fuzzy[$id] = movePHs($fuzzy[$id]) if $testPHs;
		}
		
		my @cat = split /__/, $fuzzy[3];
		my $type = "$fuzzy[4]_MT";
		
		push @{$data{__data__}}, [@fuzzy[0..2], @cat, $type];
		++$data{$cat[0]}->{$cat[1]}->{$cat[2]}->{$type}->{__count__};
		++$data{$cat[0]}->{$cat[1]}->{$cat[2]}->{__count__};
		++$data{$cat[0]}->{$cat[1]}->{__count__};
		++$data{$cat[0]}->{__count__};
	}
	print STDERR encode "utf-8", "done!\n";
}

if ($preprocess) {
	close $pre_in;
	close $pre_out;
	waitpid $pid_preprocess, 0;
}


my $folderPath = "$language".(defined $version ? ".$version" : "").".bysegment";
system "mkdir", "-p", $folderPath;
system "mkdir", "-p", "$folderPath/eval";

print STDERR encode "utf-8", "Outputting to files ‘$folderPath/eval/*_en_$language.*’…";
my $fileNameBase = "$folderPath/eval/…en_$language.sgm";
foreach my $handle ("src_", "ref_", "tst_") {
	my $fileName = $fileNameBase;
	$fileName =~ s/…/$handle/;
	open ${"out_$handle"}, ">$fileName"
	or die "Could not open $fileName\n";
	$handle =~ /^(.*?)_/;
	print ${"out_$handle"} (encode "utf-8", "<${1}set setid=\"Autodesk\" srclang=\"en\" trglang=\"$language\">\n<DOC docid=\"1\" sysid=\"$handle\">\n");
	
	#‘Trans’ format for TER
	unless ($handle =~ m"^src_") {
		$fileName =~ s/sgm$/trans/;
		open ${"trans_$handle"}, ">$fileName"
		or die "Could not open $fileName\n";
	}
}

${"${_}Length"} = 0 foreach ("src_", "ref_", "tst_");

for (my $ID = 0; $ID < @{$data{__data__}}; ++$ID) {
	my %line;
	@line{"src_", "tst_", "ref_"} = @{$data{__data__}->[$ID]}[0..2];
	
	foreach my $setup ("src_", "ref_", "tst_") {
		${"${setup}Length"} += scalar(split ' ', $line{$setup}, -1);

		print ${"out_$setup"} (encode "utf-8", "<seg id=".($ID+1).">".$line{$setup}."</seg>\n");
		
		#Trans format for TER
		#Contains just plain lines with the segment ID in parentheses after a space at the end of each line.
		print ${"trans_$setup"} (encode "utf-8", $line{$setup}." (".($ID+1).")\n") unless ($setup =~ m"^src_");
	}
	
	#Edit Distance calculation
	my $currentRecord = $data{__data__}->[$ID];
	my $currentData = $data{$currentRecord->[3]}->{$currentRecord->[4]}->{$currentRecord->[5]}->{$currentRecord->[6]};
	my $led = &levenshtein($line{"tst_"}, $line{"ref_"});
	my @led = (min($currentRecord->[7], $led), $led);
	push @$currentRecord, @led;
	@{$currentData}{"JFS", "WFS"} =
	map {defined $_ ? $_ + shift @led : shift @led} @{$currentData}{"JFS", "WFS"};
	#WER calculation
	my @wer = (&per($line{"tst_"}, $line{"ref_"}), scalar(split ' ', $line{"src_"}, -1), scalar(split ' ', $line{"tst_"}, -1));
	push @$currentRecord, @wer;
	@{$currentData}{"PER", "Precision", "Recall", "SLength", "TLength"} =
	map {defined $_ ? $_ + shift @wer : shift @wer} @{$currentData}{"PER", "Precision", "Recall", "SLength", "TLength"};
	$currentData->{"Length.ratio"} = $currentData->{"SLength"} / $currentData->{"TLength"}*1.;
	push @$currentRecord, $currentData->{"Length.ratio"};
}

foreach my $setup ("src_", "ref_", "tst_") {
	$setup =~ m"^(.*?)_";
	print ${"out_$setup"} (encode "utf-8", "</DOC>\n</${1}set>\n");
	close ${"out_$setup"};
	
	#Trans format for TER
	close ${"trans_$setup"} unless $setup =~ m"^src_";
}

print STDERR encode "utf-8", "done!\n"; #Outputting to temporary files.
print STDERR encode "utf-8", "Average $_ length: ".(${"${_}_Length"}/@{$data{__data__}})."; Total $_ tokens: ".(${"${_}_Length"})."\n" foreach ("src", "ref", "tst");

$terTool =~ s/ /\\ /g unless defined $noTer;
$gtmTool =~ s/ /\\ /g unless defined $noGtm;

my ($prefix, $suffix) = $fileNameBase =~ /^(.*)…(.*)\.sgm$/;
my $baseDir = cwd();

unless (defined $noGtm) {
	print STDERR encode "utf-8", "Computing GTM scores…";
	system(decode "utf-8", "java -Xmx2048M -jar $gtmTool +s -d -e 3 \"$baseDir/${prefix}tst_$suffix.sgm\" \"$baseDir/${prefix}ref_$suffix.sgm\" >\"$baseDir/$prefix$suffix.gtm\" 2>/dev/null");
	print STDERR encode "utf-8", "done\n";
}

unless (defined $noTer) {
	print STDERR encode "utf-8", "Computing TER scores…";
	system(decode "utf-8", "java -Xmx2048M -jar $terTool -o ter -n \"$baseDir/$prefix$suffix\" -s -r \"$baseDir/${prefix}ref_$suffix.trans\" -h \"$baseDir/${prefix}tst_$suffix.trans\" >/dev/null 2>/dev/null");
	print STDERR encode "utf-8", "done\n";
}

unless (defined $noMeteor) {
	print STDERR encode "utf-8", "Computing METEOR scores…";
	system(decode "utf-8", "cd \"$meteorPath\"; /usr/bin/perl $meteorScript --keepPunctuation -s tst_ -t \"$baseDir/${prefix}tst_$suffix.sgm\" -r \"$baseDir/${prefix}ref_$suffix.sgm\" --plainOutput -outFile \"$baseDir/$prefix$suffix.meteor\" >/dev/null 2>/dev/null");
	print STDERR encode "utf-8", "done\n";
}

print STDERR encode "utf-8", "Finished scoring data sets!\n";


my @scores;

open (my $stats, ">$folderPath/productStats.txt")
or die encode "utf-8", "Cannot write file “$folderPath/productStats.txt”\n";


my @metrics = ();
unshift @metrics, "meteor" unless defined $noMeteor;
unshift @metrics, "ter" unless defined $noTer;
unshift @metrics, "gtm" unless defined $noGtm;

foreach my $metric (@metrics) {
	open ${"in_$metric"}, "<$baseDir/$prefix$suffix.$metric"
	or die encode "utf-8", "Could not read score file “$prefix$suffix.$metric”\n";
}
${"in_ter"}->getline() foreach (1..2);


my $scoreFileName = "$folderPath/$suffix.scores.txt";
print STDERR encode "utf-8", "Scores will be written to “$scoreFileName”\n";
print STDERR encode "utf-8", "Collecting scores…";
open my $scoreOut, ">$scoreFileName"
or die encode "utf-8", "Could not write “$scoreFileName”\n";
print $scoreOut encode "UTF-16LE", chr(0xFEFF);
print $scoreOut encode "UTF-16LE", "ID\tMatch\tProduct\tRelease\tComponent\t";
print $scoreOut encode "UTF-16LE", "SLength\tTLength\tLength.ratio\tJFS\tJFS.rank\tSCFS\tWFS\t";
print $scoreOut encode "UTF-16LE", "WPD\tProdIncrease\t" if defined $prodTest && !defined $mosesFuzzy;
print $scoreOut encode "UTF-16LE", "Moses\tFuzzy\t" if defined $mosesFuzzy;
print $scoreOut encode "UTF-16LE", "METEOR\t" unless defined $noMeteor;
print $scoreOut encode "UTF-16LE", "GTM\t" unless defined $noGtm;
print $scoreOut encode "UTF-16LE", "TER\t" unless defined $noTer;
print $scoreOut encode "UTF-16LE", "PER\tPrecision\tRecall\t";
print $scoreOut encode "UTF-16LE", "Source\tPre-edit\tPost-edit\n";

for (my $ID = 0; $ID < @{$data{__data__}}; ++$ID) {
	my $data = $data{__data__}->[$ID];
	my ($meteor, $gtm, $ter);
	unless (defined $noMeteor) {
		$meteor = ${"in_meteor"}->getline();
		$meteor =~ s/^.* (\d+(?:\.\d+)?)\s*$/$1/;
	}
	unless (defined $noGtm) {
		$gtm = ${"in_gtm"}->getline();
		$gtm =~ s/^.* (\d+(?:\.\d+)?)\s*$/$1/;
	}
	unless (defined $noTer) {
		$ter = ${"in_ter"}->getline();
		$ter =~ s/^.* (\d+(?:\.\d+)?)\s*$/$1/;
	}
	
	
	$meteor =~ s/\./,/ unless defined $noMeteor;
	$gtm =~ s/\./,/ unless defined $noGtm;
	$ter =~ s/\./,/ unless defined $noTer;
	@{$data}[7..17] = map {s/\./,/; $_} @{$data}[7..17];
	
	print $scoreOut encode "UTF-16LE", join "\t", ($ID, @{$data}[6, 3..5, -3..-1, -8], "", @{$data}[7, -7]);
	print $scoreOut encode "UTF-16LE", "\t".(join "\t", @{$data}[8..9]) if defined $prodTest;
#	print $scoreOut encode "UTF-16LE", "\t".(join "\t", @{$data}[10..11]);
	print $scoreOut encode "UTF-16LE", "\t$meteor" unless defined $noMeteor;
	print $scoreOut encode "UTF-16LE", "\t$gtm" unless defined $noGtm;
	print $scoreOut encode "UTF-16LE", "\t$ter" unless defined $noTer;
	print $scoreOut encode "UTF-16LE", "\t".(join "\t", @{$data}[-6..-4, 0..2])."\n";
	
}

close $scoreOut;
close $stats;
close ${"in_$_"} foreach @metrics;

print STDERR encode "utf-8", "done!\n";

print STDERR encode "utf-8", "Archiving temporary files to “$folderPath/eval.$suffix.tbz”…";
system("tar -cjf $folderPath/eval.$suffix.tbz $folderPath/eval; rm -rf $folderPath/eval");
print STDERR encode "utf-8", "done\n";




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


sub levenshtein {
	my ($src, $trg, $characterMode) = @_;
	$characterMode ||= 0;
	return ($characterMode == 1 ? &levenshtein_([split '', $src], [split '', $trg]) : &levenshtein_([split ' ', $src], [split ' ', $trg]));
}


sub levenshtein_ {
	my ($src, $trg) = @_;
	
	my @chart = ([0]);
	$chart[$_]->[0] = $_ foreach 1..@$src;
	$chart[0]->[$_] = $_ foreach 1..@$trg;
	for (my $j = 1; $j <= @$trg; ++$j) {
		for (my $i = 1; $i <= @$src; ++$i) {
			$chart[$i]->[$j] = $src->[$i-1] eq $trg->[$j-1] ? $chart[$i-1]->[$j-1] : min($chart[$i-1]->[$j], $chart[$i]->[$j-1], $chart[$i-1]->[$j-1]) + 1;
		}
	}
	
	return @$src > @$trg ? (1.*(@$src - $chart[scalar @$src]->[scalar @$trg])/@$src) : (1.*(@$trg - $chart[scalar @$src]->[scalar @$trg])/@$trg);
}


1;