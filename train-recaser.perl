#!/usr/bin/perl -w
#
# $Id: train-recaser.perl 1326 2007-03-26 05:44:27Z bojar $
# Previously modified by Ondřej Bojar and others
#
# ©2011–2014 Autodesk Development Sàrl
#
# ChangeLog
# v2.7.3		Last modified by Ventsislav Zhechev on 15 Apr 2014
# Updated to use EN_GB for British English.
# Improved some error messages.
#
# v2.7.2		Last modified by Ventsislav Zhechev on 18 Apr 2013
# Added a -max-lexical-reordering 0 parameter to the call to the train-model.perl script
#
# v2.7.1		Last modified by Ventsislav Zhechev on 22 Jan 2013
# Added a special handling for PT_BR as a target language when creating the language model.
#
# v2.7			Last modified by Ventsislav Zhechev on 25 May 2012
# Added an option that controls whether the phrase table gets binarised.
#
# v2.6			Last modified by Ventsislav Zhechev
# Added a special handling for EN_UK as a target language when creating the language model.
#
# v2.5.2		Last modified by Ventsislav Zhechev
# Added an extra debug message in the data preparation code.
# Adjusted thread assignment to reduce memory wastage.
#
# v2.5.1		Last modified by Ventsislav Zhechev
# Added provision for passing the device ID to the train-model.perl script.
#
# v2.5			Last modified by Ventsislav Zhechev
# The main training script was changed to eliminate empty lines from the data, so that we do not have to do any filtering here.
# 
# v2.4			Last modified by Ventsislav Zhechev
# The building of the recaser language model can be done in parallel to the data preparation. This will give a slight reduction in overall runtime.
#
# v2.3.1		Last modified by Ventsislav Zhechev
# Unfortunately, empty lines in the data cause problems for further processing and we need to filter them out. Because of this we cannot simply copy the source corpus.
#
# v2.3			Last modified by Ventsislav Zhechev
# It is not necessary to filter the data based on segment length for the recaser training. Because of this, we can simply copy the source corpus as the cased version of the data, rather than decompressing and compressing it again.
# 
# v2.2.4		Last modified by Ventsislav Zhechev
# Now we are only expecting bzip2-compressed source, as this is what our training script produces.
#
# v2.2.3		Last modified by Ventsislav Zhechev
# For the data preparation step, the three different output streams now work in three separate threads, apart from the input reading thread. In this way, we are decompressing the input in one thread and compressing the output in three other threads, thus achieving a performance boost on multi-CPU machines.
#
# v2.2.2		Last modified by Ventsislav Zhechev
# Lowercasing wasn’t working properly for UTF-8 data, when binmode was set to the file handles. Fixed by decoding/encoding the data only for lowercasing.
# Sentence tokenisation is now performed only on plain spaces and tabs, igonring e.g. ideographic space.
#
# v2.2.1		Last modified by Ventsislav Zhechev
# Added special rules for lowercasing Turkish.
#
# v2.2			Last modified by Ventsislav Zhechev
# Removed some unnecessary regex checks.
# Switched to a stricter UTF-8 processing.
#
# v2.0			Last modified by Ventsislav Zhechev
# Made it possible to read-in a gzipped corpus and modified the script to write out bzip2-ed data.
#
####################

use strict;

use threads;
use Thread::Queue;

use Getopt::Long "GetOptions";

use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;
use IO::Compress::Bzip2 qw/$Bzip2Error/;

use Encode qw/encode decode/;

# apply switches
my ($DIR,$CORPUS,$SCRIPTS_ROOT_DIR,$CONFIG);
my $NGRAM_COUNT = "ngram-count";
my $TRAIN_SCRIPT = "train-model.perl";
my $MAX_LEN = 1;
my $FIRST_STEP = 1;
my $LAST_STEP = 11;
my $LANGUAGE = "";
my $DEVICE = "disk0";
my $BINARISE = 1;
die("Usage: $0 --dir recaser --corpus cased")
unless &GetOptions(	'first-step=i' => \$FIRST_STEP,
										'last-step=i' => \$LAST_STEP,
										'corpus=s' => \$CORPUS,
                    'config=s' => \$CONFIG,
										'dir=s' => \$DIR,
										'ngram-count=s' => \$NGRAM_COUNT,
										'train-script=s' => \$TRAIN_SCRIPT,
		      					'scripts-root-dir=s' => \$SCRIPTS_ROOT_DIR,
		      					'max-len=i' => \$MAX_LEN,
										'language=s' => \$LANGUAGE,
										'device=s' => \$DEVICE,
										'binarise=i' => \$BINARISE,
);

# check and set default to unset parameters
die("please specify working dir --dir") unless defined($DIR);
die("please specify --corpus") if !defined($CORPUS) && $FIRST_STEP <= 2 && $LAST_STEP >= 1;

mkdir($DIR) unless -e $DIR;
#&truecase()           if 0 && $FIRST_STEP == 1;
if ($FIRST_STEP <= 2 && $LAST_STEP >= 3) {
	my $pid = fork();
	if ($pid) {
		&train_lm()           if $FIRST_STEP <= 2;
		waitpid $pid, 0;
	} else {
		&prepare_data()       if $FIRST_STEP <= 3 && $LAST_STEP >= 3;
		exit(0);
	}
}
&train_recase_model() if $FIRST_STEP <= 10 && $LAST_STEP >= 3;
&cleanup()            if $LAST_STEP == 11;

### subs ###

#sub truecase {
#	# to do
#}

sub train_lm {
	if (-e "$DIR/cased.srilm.gz") {
		print STDERR "Reusing existing language model!\n";
		return;
	}
	print STDERR "(2) Train language model on cased data @ ".`date`;
	my $cmd = "$NGRAM_COUNT -text $CORPUS -lm $DIR/cased.srilm.gz -interpolate -".($LANGUAGE eq "en_gb" ? "wb" : "kn")."discount";
	print STDERR $cmd."\n";
	system($cmd) == 0
	or die "Recaser language model training failed!\n";
}

sub prepare_data {
	if (-e "$DIR/aligned.cased.bz2" && -e "$DIR/aligned.lowercased.bz2" && -e "$DIR/aligned.a.bz2") {
		print STDERR "Reusing existing alignment data!\n";
		return;
	}
	print STDERR "\n(3) Preparing data for training recasing model @ ".`date`;
	

	system 'cp', '-p', $CORPUS, "$DIR/aligned.cased.bz2";
#	my $casedQueue = Thread::Queue->new();
#	my $printCased = sub {
#		my $CASED = new IO::Compress::Bzip2 "$DIR/aligned.cased.bz2", BlockSize100K => 9
#		or die "Could not write $DIR/aligned.cased.bz2 ($Bzip2Error)!\n";
#		
#		while (defined(my $line = $casedQueue->dequeue())) {
#			print $CASED encode "utf-8", $line;
#		}
#		
#		$CASED->close();
#	};
	
	my $lowercasedQueue = Thread::Queue->new();
	my $printLowercased = sub {
		my $LOWERCASED = new IO::Compress::Bzip2 "$DIR/aligned.lowercased.bz2", BlockSize100K => 9
		or die "Could not write $DIR/aligned.lowercased.bz2 ($Bzip2Error)!\n";
		
		while (defined(my $line = $lowercasedQueue->dequeue())) {
			$line =~ tr/İI/iı/ if $LANGUAGE =~ /tr/;
			print $LOWERCASED encode "utf-8", lc $line;
		}
		
		$LOWERCASED->close();
		print STDERR "Finished outputting lowercased data.";
	};
	
	my $alignmentQueue = Thread::Queue->new();
	my $printAlignment = sub {
		my $ALIGNMENT = new IO::Compress::Bzip2 "$DIR/aligned.a.bz2", BlockSize100K => 9
		or die "Could not write $DIR/aligned.a.bz2 ($Bzip2Error)!\n";
		
		while (defined(my $line = $alignmentQueue->dequeue())) {
#			unless ($line =~ /^\s*$/) {
				my $i=0;
				foreach (split /[ \t]/, $line) {
					print $ALIGNMENT "$i-$i ";
					++$i;
				}
#			}
			print $ALIGNMENT "\n";
		}
		
		$ALIGNMENT->close();
		print STDERR "Finished outputting alignment data.";
	};
	
	my $mainThread = sub {
		my $CORP = new IO::Uncompress::Bunzip2($CORPUS)
		or die "Coud not read corpus $CORPUS ($Bunzip2Error)!\n";
		
		select STDERR;
		$| = 1;
	
		while (my $line = <$CORP>) {
			$line = decode "utf-8", $line;
			
			print STDERR "[generate: $.]" unless $. % 500000;
			print STDERR "." unless $. % 10000;
			
#			next if $line =~ /^\s*$/;

#			$casedQueue->enqueue($line);
			$lowercasedQueue->enqueue($line);
			$alignmentQueue->enqueue($line);
		}
	
		close $CORP;
		print STDERR "Finished queuing data.";
	
#		$casedQueue->enqueue(undef);
		$lowercasedQueue->enqueue(undef);
		$alignmentQueue->enqueue(undef);
	};

	$_->join() foreach (scalar threads->create($mainThread),
#	scalar threads->create($printCased),
	scalar threads->create($printLowercased), scalar threads->create($printAlignment));
}

sub train_recase_model {
	my $first = $FIRST_STEP < 4 ? 4 : $FIRST_STEP;
	print STDERR "\n(4) Training recasing model @ ".`date`;
	my $cmd = "$TRAIN_SCRIPT -root-dir $DIR -model-dir $DIR -temp-dir /tmp -first-step $first -alignment a -corpus-dir \"$DIR\" -corpus aligned -f lowercased -e cased -max-phrase-length $MAX_LEN -lm 0:3:$DIR/cased.srilm.gz:0 -device $DEVICE -binarise $BINARISE -max-lexical-reordering 0";
	$cmd .= " -scripts-root-dir $SCRIPTS_ROOT_DIR" if $SCRIPTS_ROOT_DIR;
	$cmd .= " -config $CONFIG" if $CONFIG;
	print STDERR "$cmd\n";
	system($cmd) == 0
	or die "Recase model training failed!\n";
}

sub cleanup {
	print STDERR "\n(11) Cleaning up @ ".`date`;
	system "rm -f $DIR/aligned*; rm -f $DIR/lex*";
}
