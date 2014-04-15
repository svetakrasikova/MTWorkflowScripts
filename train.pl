#!/usr/bin/perl -ws
#
# train.pl
# Versatile script for training Autodesk MT systems based on Moses
#
# ©2011–2014 Autodesk Development Sàrl
# Originally a shell script by François Masselot
# Last modified by Ventsislav Zhechev
#
# ChangeLog
# v3.6.4		Modified by Ventsislav Zhechev on 09 Apr 2014
# Ensured EN_GB is processed properly. (We no longer use EN_UK as a language code.)
#
# v3.6.3		Modified by Ventsislav Zhechev on 08 Jan 2014
# Fixed the product name processing to allow the proper pre-processing of source-language data.
#
# v3.6.2		Modified by Ventsislav Zhechev on 18 Dec 2013
# Fixed a bug where an unexisting option was passed on to the train-recaser.perl script.
#
# v3.6.1		Modified by Ventsislav Zhechev on 17 Dec 2013
# Made the processing of product names optional to be turned one by a command-line parameter.
#
# v3.6			Modified by Ventsislav Zhechev on 27 Jun 2013
# Moved the processing of product names for product-specific terminology extraction to this script in order to properly handle JP and ZH* pre-processing.
#
# v3.5.4		Modified by Ventsislav Zhechev on 08 May 2013
# Added a -max-lexical-reordering parameter to the proper Moses and recaser command lines. The recaser uses a value of 0; the values for the proper Moses training are language-pair specific and will be setup later.
#
# v3.5.3		Modified by Ventsislav Zhechev on 28 Mar 2013
# Improved the command line parameter validation.
#
# v3.5.2		Modified by Ventsislav Zhechev on 07 Feb 2013
# Added code to copy the recaser moses.ini files from the XX-EN training folder to the language-specific engine.
#
# v3.5.1		Modified by Ventsislav Zhechev
# The training will now fail if data cannot be extracted from EN-XX system during XX-EN training, eg. when the proper archive file name was not specified.
# Added extra checks to archive only the proper files during XX-EN training.
#
# v3.5			Modified by Ventsislav Zhechev
# Added a requirement to provide the name of an EN-X training archive to reuse corpus and GIZA++ data in an X-EN training. The EN side needs to be recreated for JP-EN training, as we reorder it during EN-JP training. This makes it necessary to also rerun GIZA++.
#
# v3.4.2		Modified by Ventsislav Zhechev
# Modified the settings to use a different discount algorithm for the target language model for PT_BR.
#
# v3.4.1		Modified by Ventsislav Zhechev
# Parametrised the fiscal year prefix.
#
# v3.4			Modified by Ventsislav Zhechev
# Added an option that controls whether the phrase table gets binarised.
#
# v3.3.2		Modified by Ventsislav Zhechev
# Fixed a bug where passing through \r line breaks could lead to erratic results.
# Undid the fix in v3.3.1 as it was not necessary in the end.
#
# v3.3.1		Modified by Ventsislav Zhechev
# Fixed a bug where the masking of special characters was erroneously performed after rather than before data pre-processing.
#
# v3.3			Modified by Ventsislav Zhechev
# Modified the settings to use a different discount algorithm for the language model when the target language is EN_UK.
#
# v3.2.2		Modified by Ventsislav Zhechev
# Added a bug where the target corpus won’t be tokenised unless we planned to do full Moses training.
#
# v3.2.1		Modified by Ventsislav Zhechev
# We are now correctly passing the device ID to the recaser training script.
#
# v3.2			Modified by Ventsislav Zhechev
# Added provision to only perform target language language model and recaser training.
#
# v3.1.3		Modified by Ventsislav Zhechev
# Fixed the tokeniser to work properly with preprocessors that require a steady input of data to speed-up processing. For this, the processing is split between a writer and a reader threads to keep the preprocessor buffers saturated. The best example for a preprocessor that needs this type of treatment is a multi-threaded parser.
#
# v3.1.2		Modified by Ventsislav Zhechev
# Added commands to fix the moses.ini files for use in the Autodesk production environment.
#
# v3.1.1		Modified by Ventsislav Zhechev
# We are removing empty lines within the tokeniser subroutine for the case where it is used for the recaser training. The subroutine and variable names should be changend to reflect this.
#
# v3.1			Modified by Ventsislav Zhechev
# Now we are starting recaser training from the very beginning, as it doesn’t rely on anything else anyway.
# !!!IMPORTANT!!! There could be problems with logging.
#
# v3.0.2		Modified by Ventsislav Zhechev
# Fixed a bug where the preprocess pipe wasn’t closed on time and the preprocess task got stuck waiting for input.
#
# v3.0.1		Modified by Ventsislav Zhechev
# Fixed a number of issues with the naming of temporary files.
#
# v3.0			Modified by Ventsislav Zhechev
# Corpus cleaning is now integrated in this script.
# The target language model is now based on the complete target corpus.
# The training of the target language model and the cleaning of the corpus for GIZA++ are now done in parallel.
#
# v2.9.1		Modified by Ventsislav Zhechev
# It is no longer necessary to specify the tokeniser path, as there is a default.
#
# v2.9			Modified by Ventsislav Zhechev
# Updated to work with the new version of the tokeniser, which cannot be used in a pipe, but instead needs to be accessed from this script directly. The tokenisation code is now isolated in a separate subroutine.
# Removed some code that could erroneously engage reordering on the target side.
# We no longer allow the user to specify a lowercasing script, as this is handled internally in this script.
#
# v2.8.3		Modified by Ventsislav Zhechev
# Added a parameter to modify the tokenisation of cased data for the recaser training.
#
# v2.8.2		Modified by Ventsislav Zhechev
# Added special rules for lowercasing Turkish.
#
# v2.8.1		Modified by Ventsislav Zhechev
# Fixed checking of command-line options for the case where an engine name is provided instead of source and target language codes.
# Fixed configuration logging when the user selected not to build a recaser.
# The selected IO device is now passed on as a parameter to train-model.perl
#
# v2.8			Modified by Ventsislav Zhechev
# Fixed lowercasing to properly deal with different locales in UTF8 by default. If an external script is supplied for lowercasing, it has to take care of the issue.
#
# v2.7			Modified by Ventsislav Zhechev
# Fixed a bug in the clean-up process after archiving the interim files.
#
# v2.6			Modified by Ventsislav Zhechev
# Added Korean as a language where reordering may be performed.
#
# v2.5			Modified by Ventsislav Zhechev
# Added an option to specify the maximum lexical reordering distance when training with Moses. Default is set to 10 for zh-*, ko, jp, de and to 6 for all other languages.
# Fixed a bug with the handling of the $seg_script parameter.
#
#####################
my $version = "v3.6.4";
my $last_modified = "09 Apr 2014";

use strict;
#use threads;
#use threads::shared;
#use Thread::Queue;

use utf8;
use File::Spec qw(splitpath rel2abs);
use Encode qw(decode encode);
use Benchmark;

use IO::Handle;
use IO::Compress::Bzip2 qw/$Bzip2Error/;
use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;
use IPC::Open2;
#use IPC::Open3;

$| = 1;

binmode STDERR, ":encoding(utf-8)";
select STDERR;
$| = 1;

# Import the variables generated by the command-line switches
our ($engine, $corpus, $source, $target, $lm_path, $moses_path, $bin_dir, $base_path, $first_step, $last_step, $log_dir, $seg_script, $segmenter, $seg_path, $seg_model, $reorder_cmd, $build_lm, $build_recaser, $force, $device, $binarise, $fiscal_year, $archive, $perProduct);

unless (defined($corpus) && ((defined($source) && defined($target)) || defined($engine)) && defined($lm_path) && defined($moses_path) && defined($bin_dir) && defined($fiscal_year) && (!(((defined $target && defined $source) || (defined $engine && $engine =~ m!_xx/?!i)) && $target eq "en" && $source ne "xx") || defined($archive))) {
	print STDERR "Usage: $0 -corpus=… {-source=… -target=… | -engine=…} -lm_path=… -moses_path=… -bin_dir=… [-base_path=…] [-first_step=…] [-last_step=…] [-log_dir=…] [-seg_script=… -segmenter=… [-seg_path=…] [-seg_model=…]] [-reorder_cmd=\"…\"] [-build_lm=…] [-build_recaser=…] [-force] [-binarise] -fiscal_year=fy?? [-archive=…] [-perProduct]\n";
	exit(1);
}

binmode STDIN, ":encoding(utf-8)";
binmode STDOUT, ":encoding(utf-8)";

if ($engine) {
	my ($src, $trg) = $engine =~ /^fy\d+_([\w_]+)-([\w_]+)_\w(?:\/?)$/;
	if ($source && $target && ($source ne $src || $target ne $trg)) {
		die "Source and/or target language does not correspond to engine name!!! Aborting…\n";
	} elsif (!$source || !$target) {
		($source, $target) = ($src, $trg);
	}
}

$source = uc $source;
$target = uc $target;
my $currentDir = File::Spec->rel2abs(File::Spec->curdir());
unless ($engine && (-e "$currentDir/$engine" || $currentDir =~ /\Q$engine/)) {
	foreach ('a'..'z') {
		$engine = "${fiscal_year}_$source-${target}_$_";
		last unless -e "$currentDir/$engine";
	}
	mkdir "$currentDir/$engine";
}
$source = lc $source;
$target = lc $target;
chdir "$currentDir/$engine" unless $currentDir =~ /\Q$engine/;

$device ||= "disk0";
$binarise = 1 unless defined $binarise;
$first_step ||= 1;
$last_step ||= 9;
if (defined $base_path)
	{$base_path =~ s/ /\\ /g} else
	{$base_path = "/OptiBay/ADSK_Software"}
if (defined $log_dir)
	{$log_dir =~ s/ /\\ /g} else
	{$log_dir = "LOG"}
$log_dir = File::Spec->rel2abs(File::Spec->curdir())."/$log_dir" unless $log_dir =~ m!^/!;
$seg_script =~ s/ /\\ /g if defined $seg_script;
$segmenter ||= "";
if (defined $seg_path)
	{$seg_path =~ s/ /\\ /g} else
	{$seg_path = "/usr/local/bin"}
if (defined $seg_model)
	{$seg_model =~ s/ /\\ /g} else
	{$seg_model = ""}
$reorder_cmd ||= "" if defined $reorder_cmd;
my ($vol, $dir, $corpusFile) = File::Spec->splitpath($corpus);
my $corpusDir = File::Spec->rel2abs(File::Spec->curdir())."/corpus";
my $corpusclean = "corpus.clean";
mkdir($corpusDir) unless -e $corpusDir;
$lm_path = File::Spec->rel2abs(File::Spec->curdir())."/$lm_path" unless $lm_path =~ m!^/!;
$build_recaser = File::Spec->rel2abs(File::Spec->curdir())."/$build_recaser" if (defined($build_recaser) && !($build_recaser =~ m!^/!));
my $segment_source = $source eq "jp" || $source =~ m"^zh";
my $segment_target = $target eq "jp" || $target =~ m"^zh";
if ($segment_source || $segment_target) {
	$seg_script = "$base_path/word_segmenter.pl" unless $seg_script;
	$segmenter = "kytea" unless $segmenter;
	die "You have to specify segmenter model for kytea when one of your languages is JA, ZH_HANS or ZH_HANT!\n" if $segmenter eq "kytea" && !$seg_model;
}


unless (-e $log_dir) {
	mkdir($log_dir)
	or die "Could not create LOG path: $log_dir\n";
}
my $date = decode("utf-8", `/bin/date +%F-%T`);
chomp $date;
my $logFile = "$log_dir/train_$source-$target-$date.log";
open LOG, ">:encoding(utf-8)", $logFile;
select LOG;
$| = 1;

## Print out configuration
print LOG "Training Setup\nScript $version last modified on $last_modified\nCorpus: $corpus\nSource: $source\nTarget: $target\nBase Script Path: $base_path\nLanguage Model Path: $lm_path\nMoses Path: $moses_path\nGIZA++ Binaries Path: $bin_dir\nFirst Training Step: $first_step\nLast Training Step: $last_step\nLog File Path: $log_dir".($segmenter ? "\nSegmenter script: $seg_script\nSegmenter tool: $segmenter\nSegmenter tool path: $seg_path".($seg_model ? "\nSegmenter model: $seg_model" : "") : "").($reorder_cmd ? "\nReorder command: $reorder_cmd" : "")."\n".(defined $build_recaser ? "Building recaser at path: $build_recaser\n" : "").($binarise ? "B" : "NOT b")."inarising source\n≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≤≥≥≥≥≥≥≥≥≥≥≥≥≥≥≥≥≥≥\n\n";

if ($target eq "en" && $source ne "xx") {
	print STDERR "Extracting reusable data from en–$source system…\n";
	system("cd $currentDir/$engine; /usr/bin/tar -xvf \"$currentDir/$archive\" ".($source eq "jp" ? "-q corpus/corpus.tok.jp.bz2" : "corpus/* giza*")) == 0
	or die "Could not properly extract data from en-$source system!\n";
}

my ($startTime, $endTime, $pid);

sub tokeniser {
#	my $productQueue = new Thread::Queue;
	my ($language, $srcCorpus, $trgCorpus, $preprocess, $saveCase) = @_;
	
	my $tokData = initTokeniser($language, $saveCase);

	if ($preprocess) {
		# Preprocessing requested—split into two threads.
		local (*PREPROCESS_IN, *PREPROCESS_OUT);
		my $preprocess_pid = open2(\*PREPROCESS_OUT, \*PREPROCESS_IN, $preprocess)
		and print STDERR "Launched preprocessing with “$preprocess”!\n"
		or die "Could not launch preprocessing with “$preprocess”!\n";

		my $preprocessThread = fork();
		unless ($preprocessThread) {
			print STDERR "Preprocess fork started!\n";
			close PREPROCESS_IN;
			my $TOKENISED_OUT = new IO::Compress::Bzip2 "$trgCorpus"
			or die "Could not write tokenised corpus “$trgCorpus”: $Bzip2Error!\n";
			
			while (<PREPROCESS_OUT>) {
				my $line = decode "utf-8", $_;
				$line =~ tr/|<>()/│﹤﹥﹙﹚/;
				#Add product code to each token
				if (defined $perProduct) {
					chomp $line;
#					my $product = $productQueue->dequeue();
					my $product = <PREPROCESS_OUT>;
					$line .= "◊$product\n" if $product;
				}
				print $TOKENISED_OUT encode "utf-8", $line;
			}
			
			close PREPROCESS_OUT;
			close $TOKENISED_OUT;
			
			exit(0);
		}
		
		close PREPROCESS_OUT;
		
		# Wait a bit for the preprocessor to load into memory.
		sleep 10;
		
		my $CORPUS_IN = new IO::Uncompress::Bunzip2 "$srcCorpus"
		and print STDERR "Started reading source corpus “$srcCorpus” for preprocessing!\n"
		or die "Could not read source corpus “$srcCorpus”: $Bunzip2Error!\n";

		while (<$CORPUS_IN>) {
			chomp;
			my $line = decode "utf-8", $_;
			next if $line =~ /^\s*$/;
			($line, my $product) = split /◊/, $line;
			$product ||= "";
#			$productQueue->enqueue($product) if defined $perProduct;
			$line =~ tr/İI/iı/ if !$saveCase && $language =~ /tr/;
			$line =~ tr/\r/ /;
			$line = tokenise($tokData, $saveCase ? $line : lc $line);
			print PREPROCESS_IN encode "utf-8", "$line\n";
			print PREPROCESS_IN "$product\n" if defined $perProduct;
#			$line = decode "utf-8", scalar <PREPROCESS_OUT>;
#			$line =~ tr/|<>()/│﹤﹥﹙﹚/;
#			#Add product code to each token
#			$line =~ s/(\s|$)/◊$product$1/g if defined $perProduct && $product;
#			print $TOKENISED_OUT encode "utf-8", $line;
		}
		
		close $CORPUS_IN;		
		
#		$preprocessThread->join();
		close PREPROCESS_IN;
		close PREPROCESS_OUT;

		waitpid($preprocessThread, 0);
		waitpid($preprocess_pid, 0);
	} else {
		# No special preprocessing requested.
		my $CORPUS_IN = new IO::Uncompress::Bunzip2 "$srcCorpus"
		or die "Could not read source corpus “$srcCorpus”: $Bunzip2Error!\n";
		my $TOKENISED_OUT = new IO::Compress::Bzip2 "$trgCorpus"
		or die "Could not write tokenised corpus “$trgCorpus”: $Bzip2Error!\n";

		while (<$CORPUS_IN>) {
			chomp;
			my $line = decode "utf-8", $_;
			next if $line =~ /^\s*$/;
			($line, my $product) = split /◊/, $line;
			$product ||= "";
			$line =~ tr/İI/iı/ if !$saveCase && $language =~ /tr/;
			$line =~ tr/\r/ /;
			$line = tokenise($tokData, $saveCase ? $line : lc $line)."\n";
			$line =~ tr/|<>()/│﹤﹥﹙﹚/;
			#Add product code to each token
			$line =~ s/(\s|$)/◊$product$1/g if defined $perProduct && $product;
			print $TOKENISED_OUT encode "utf-8", $line;
		}
		
		close $CORPUS_IN;
		close $TOKENISED_OUT;
	}
}

# Load tokeniser script.
require "$base_path/tokenise.pl";

# fork if both of the following trainings are to be performed
my $forked = 0;
if (defined $build_lm && defined $build_recaser) {
	$forked = 1;
	$pid = fork();
}

if (!$forked || !$pid) {
	## Train target language recaser system
	if (defined $build_recaser && (defined $force || !(-e "$build_recaser/moses.ini"))) {
		sleep(1) if $forked;
		print STDERR "Building target recaser model…\n";
		print LOG "Building target recaser model…\n";
		close LOG;
		my $start = new Benchmark;
		unless (!(defined $force) && -e "$build_recaser/corpus.tok.$target.bz2") {
			mkdir $build_recaser unless -e $build_recaser;
			tokeniser($target, "$corpus.$target.bz2", "$build_recaser/corpus.tok.$target.bz2", ($segment_target ? "$seg_script -segmenter=$segmenter -seg_path=$seg_path".($seg_model ? " -model=$seg_model" : "") : ""), 1);
		}
		print STDERR "\n";
		system("$base_path/train-recaser.perl --dir $build_recaser --corpus $build_recaser/corpus.tok.$target.bz2 --ngram-count ".($build_lm ? "$build_lm/" : "")."ngram-count --train-script \"$moses_path/scripts/training/train-model.perl\" --language $target --device $device --binarise $binarise >>$logFile") == 0
		or die "Target recasing model training failed with exit code ".($? >> 8).": $!\n";
		system "/usr/bin/perl -i.bak -pe 's!^\\d(.*phrase-table)\\.bz2\$!1\$1!' $build_recaser/moses.ini";
		system "/usr/bin/perl -i.ventzi -pe 's,Volumes/.*/Autodesk,local/cms,;s/1 0 0 5/0 0 5/;s/ .*?(msd-.*-fe).*? / \$1 /' $build_recaser/moses.ini";
		
		open LOG, ">>:encoding(utf-8)", $logFile;
		my $end = new Benchmark;
		print LOG "Building target recaser completed in ", timestr(timediff($end, $start), 'all'), "\n";
		print STDERR "Target recaser training complete!\n";
	}
	exit(0) if $forked;
}


## Perform tokenisation
unless (!(defined $force) && -e "$corpusDir/corpus.tok.$source.bz2" && -e "$corpusDir/corpus.tok.$target.bz2") {
	print LOG "Tokenising in parallel…\n";
	$startTime = new Benchmark;
	my $tok_pid = fork();
	if ($tok_pid) {
		unless ($first_step > $last_step) {
			tokeniser($source, "$corpus.$source.bz2", "$corpusDir/corpus.tok.$source.bz2", ($segment_source ? "$seg_script -segmenter=$segmenter -seg_path=$seg_path".($seg_model ? " -model=$seg_model" : "") : "").((($segment_target || $target eq "ko") && defined $reorder_cmd) ? " $reorder_cmd" : "")) unless -e "$corpusDir/corpus.tok.$source.bz2";
		}
		print STDERR "Source tokenisation complete!\n";
		waitpid($tok_pid, 0);
	} else {
		tokeniser($target, "$corpus.$target.bz2", "$corpusDir/corpus.tok.$target.bz2", ($segment_target ? "$seg_script -segmenter=$segmenter -seg_path=$seg_path".($seg_model ? " -model=$seg_model" : "") : "")) unless -e "$corpusDir/corpus.tok.$target.bz2";
		print STDERR "Target tokenisation complete!\n";
		exit(0);
	}
	$endTime = new Benchmark;
	print LOG "Tokenising completed in ", timestr(timediff($endTime, $startTime), 'all'), "\n";
}

	
my $sub_fork = !(!(defined $force) && -e "$corpusDir/$corpusclean.$source" && -e "$corpusDir/$corpusclean.$target") && (defined $build_lm && (defined $force || !(-e "$lm_path/lm5bin")));
my $sub_pid = $sub_fork ? fork() : 0;
	
## Corpus cleaning
if (($sub_pid || !$sub_fork) && !(!(defined $force) && -e "$corpusDir/$corpusclean.$source" && -e "$corpusDir/$corpusclean.$target" || $first_step > $last_step)) {
	print LOG "Cleaning…\n";
	$startTime = new Benchmark;
	print STDERR "Cleaning corpora for use with GIZA++… ";
	my $srcCorpusIn = new IO::Uncompress::Bunzip2("$corpusDir/corpus.tok.$source.bz2")
	or die "Cannot open source corpus at “$corpusDir/corpus.tok.$source.bz2” ($Bunzip2Error)\n";
	my $trgCorpusIn = new IO::Uncompress::Bunzip2("$corpusDir/corpus.tok.$target.bz2")
	or die "Cannot open target corpus at “$corpusDir/corpus.tok.$target.bz2” ($Bunzip2Error)\n";
	open my $srcCorpusOut, ">$corpusDir/$corpusclean.$source"
	or die "Cannot write source corpus to “$corpusDir/$corpusclean.$source”\n";
	open my $trgCorpusOut, ">$corpusDir/$corpusclean.$target"
	or die "Cannot write target corpus to “$corpusDir/$corpusclean.$target”\n";
	my $inLines = my $outLines = 0;
	my $minTokens = 1; my $maxTokens = 50; my $ratio = 9;
	while (my ($srcLine, $trgLine) = ($srcCorpusIn->getline(), $trgCorpusIn->getline())) {
		last unless defined $srcLine && defined $trgLine;
		
		++$inLines;
		print STDERR "." unless $inLines % 10000;
		print STDERR "($inLines)" unless $inLines % 100000;
		
		chomp $srcLine; chomp $trgLine;
		next if $srcLine eq '' || $trgLine eq '';
		
		$srcLine = decode "utf-8", $srcLine;
		$trgLine = decode "utf-8", $trgLine;
		#Count number of spaces and tabs—the number of tokens is that plus one.
		my $srcTokens = 1 + $srcLine =~ s/\s+/ /g;
		my $trgTokens = 1 + $trgLine =~ s/\s+/ /g;
		next if $srcLine =~ /^\s*$/ || $trgLine =~ /^\s*$/;
		next if $srcTokens < $minTokens || $srcTokens > $maxTokens || $trgTokens < $minTokens || $trgTokens > $maxTokens || $srcTokens/$trgTokens > $ratio || $trgTokens/$srcTokens > $ratio;
		
		++$outLines;
		print $srcCorpusOut encode "utf-8", "$srcLine\n";
		print $trgCorpusOut encode "utf-8", "$trgLine\n";
	}
	close $srcCorpusOut; close $trgCorpusOut;
	print STDERR "\n";
	
	die "Source corpus ended prematurely!\n" if defined $trgCorpusIn->getline();
	die "Target corpus ended prematurely!\n" if defined $srcCorpusIn->getline();
	close $srcCorpusIn; close $trgCorpusIn; 
	
	print STDERR "Input sentences: $inLines  Output sentences:  $outLines\n";
	print STDERR "Corpus cleaning complete!\n";
	print LOG "Input sentences: $inLines  Output sentences:  $outLines\n";
	
	$endTime = new Benchmark;
	print LOG "Cleaning completed in ", timestr(timediff($endTime, $startTime), 'all'), "\n";
	waitpid($sub_pid, 0) if $sub_fork;
}

## Train target language model
if ((!$sub_pid || !$sub_fork) && (defined $build_lm && (defined $force || !(-e "$lm_path/lm5bin")))) {
	print STDERR "Training target language model…\n";
	print LOG "Building target language model…\n";
	my $start = new Benchmark;
	unless (-e $lm_path) {
		mkdir($lm_path)
		or die "Could not create LM path: $lm_path\n";
	}
	system(($build_lm ne "1" ? "$build_lm/" : "")."ngram-count -order 5 -unk -interpolate -".($target eq "en_gb" ? "wb" : "kn")."discount -memuse -text $corpusDir/corpus.tok.$target.bz2 -lm $lm_path/lm5bin -write-binary-lm") == 0
	or die "Target language model training failed with exit code ".($? >> 8).": $!\n";
	my $end = new Benchmark;
	print LOG "Building target language model completed in ", timestr(timediff($end, $start), 'all'), "\n";
	print STDERR "Training target language model complete!\n";
	exit(0);
}


## Proper Moses training
unless (!(defined $force) && -e "./model/moses.ini" || $first_step > $last_step) {
	sleep 5;
	$date = decode("utf-8", `/bin/date`);
	chomp $date;
	print LOG "$date: Starting $source-$target training on $corpus ($corpusDir/$corpusclean)\n".`iostat -dI $device`."\n";
	
	my $command = "$moses_path/scripts/training/train-model.perl -parallel -first-step $first_step -last-step $last_step -bin-dir \"$bin_dir\" -temp-dir /tmp -verbose -continue -root-dir . -f $source -e $target -corpus-dir \"$corpusDir\" -corpus \"$corpusclean\" -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:5:$lm_path/lm5bin:0 -device $device -binarise $binarise -max-lexical-reordering 6";
	print LOG "RUNNING: “$command”\n";
	close LOG;
	
	system("$command >>$logFile") == 0
	or die "\nTraining FAILED with exit code ".($? >> 8).": $!\n";
	
	open LOG, ">>:encoding(utf-8)", $logFile;
	
	$date = decode("utf-8", `/bin/date`);
	chomp $date;
	print LOG "$date: Ended $source-$target training on $corpus ($corpusDir/$corpusclean)\n".`iostat -dI $device`."\n";
	
	
	## Patch the moses.ini file
	system "/usr/bin/perl -i.bak -pe 's!^\\d(.*phrase-table)\\.bz2\$!1\$1!; s!^(.*)\\..*?\\-fe\\.gz\$!\$1!' ./model/moses.ini";
	system "/usr/bin/perl -i.ventzi -pe 's,Volumes/.*/Autodesk,local/cms,;s/1 0 0 5/0 0 5/;s/ .*?(msd-.*-fe).*? / \$1 /' ./model/moses.ini";
}

waitpid($pid, 0) if $forked && $pid;

## Copy recaser moses.ini file for XX-EN trainings.
if ($source ne "xx" && $target eq "en") {
	print LOG "Copying recaser setup files from XX-EN folder…\n";
	mkdir "recaser";
	system("cp -p $build_recaser/moses.* recaser/.") == 0
	or warn "Could not copy recaser setup files!\n";
}

## Archive interim files
$date = decode("utf-8", `/bin/date`);
chomp $date;
print LOG "$date: Archiving interim files…\n";
$date =~ s/\s+/\\ /g;
$date =~ s/:/⁚/g;
my $archiveFile = "../${engine}_interim_files_$date.tbz2";
print STDERR "Archiving to $archiveFile…\n";
system("tar -cvjf $archiveFile corpus ".($first_step > $last_step ? "" : "giza.* model/aligned.grow-diag-final-and* model/lex.* ").(defined $build_recaser && ($source eq "xx" || $target ne "en") ? "recaser/corpus.tok.$target.bz2 " : "")."&& rm -rf corpus ".($first_step > $last_step ? "" : "giza.* model/aligned.grow-diag-final-and* model/lex.* ").(defined $build_recaser && ($source eq "xx" || $target ne "en") ? "recaser/corpus.tok.$target.bz2" : "")) == 0
or warn "Archiving the interim files failed with exit code ".($? >> 8).": $!\n";

$date = decode("utf-8", `/bin/date`);
chomp $date;
print LOG "Training COMPLETE $date!\nLog written to: $logFile\n";
close LOG;


1;