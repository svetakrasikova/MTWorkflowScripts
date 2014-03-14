#!/usr/local/bin/perl -ws
#
# file: moses_server.ventzi.pl
#
# ©2011–2012 Autodesk Development Sàrl
#
# Originally by Mirko Plitt
# Created on 08 Jun 2009
#
# In parts based on code by Herve Saint-Amand (Universität des Saarlandes)
#
# This script starts Moses to run in the background.
# It binds itself to listen on some port, then spawns the Moses process. When it gets a connection, it is read line by line, the lines are fed to Moses, encapsulated in a pre-/post-process scripts and the translations are written to the port.
#
#
# Last modified on 29 Aug 2012 by Ventsislav Zhechev
#
# ChangeLog
# v3.6
# Added provision reduce the impact of PH order errors.
#
# v3.5.10
# Fixed a bug to properly cycle the queues when the first input contains bad UTF-8.
#
# v3.5.9
# Changed the exit conditions for the main program to account for the status of the translation thread.
# If the translation thread is dead without reporting clean exit, we attempt to restart it and continue operation.
#
# v3.5.8
# Fixed a bug in the SIG{PIPE} handler that was triggered when any of the queues was empty.
#
# v3.5.7
# We are now removing \r line breaks from segments to avoid errors.
# Undid the fix in v3.5.6 as it was not necessary in the end.
#
# v3.5.6
# Fixed a bug where the masking of special characters was erroneously performed after rather than before data pre-processing.
#
# v3.5.5
# Adjusted the position of some debug output during the initial read of client data.
# Modified the check for bad state of the client socket.
#
# v3.5.4
# Encapsulated the reading from the client in the translation thread on a suspicion that an early death of the thread may be occurring there in some situations.
#
# v3.5.3
# Added code to restart the translation thread in case it dies.
#
# v3.5.2
# Fixed the handling of the situation where the client did not send any data within the expected time limit.
#
# v3.5.1
# Added timestamps to the debug output.
#
# v3.5
# Modified the logic for shutting down the engine.
# Added some debug output to thoroughly trace the server-client interaction.
#
# v3.4.6
# Made changes to error handling in cases of lost connection.
#
# v3.4.5
# Fixed a bug in the code processing sentence-initial capitalisation.
#
# v3.4.4
# Added a provision to match the source segment-inital capitalisation (except when we are dealing with German).
#
# v3.4.3
# Added some debug output to try to tracedown a deadlock situation.
# Adjusted the timeout for waiting for incoming data from the client.
# Added a shortcircuit for quick handling of empty lines.
# Made STDERR output unbuffered.
#
# v3.4.2
# Added some extra debugging output.
# A small fix to the handling of EOF sent early from the client.
#
# v3.4.1
# Fixed a bug where we would erroneously turn off the engine when the client did not provide any data to translate.
#
# v3.4
# Rather than only handling one connection at a time, now we have a connection queue where incomming connections wait for their turn to be processed.
# This fixes a bug where a thread could die unexpectedly when the client was lost.
#
# v3.3.1
# Added log output to track incomming connections while the server is busy.
#
# v3.3
# Translations are now performed in a detached thread, leaving the main thread available to accept incoming connections. In this way, we can indicate that we are busy translating, by immediately cancelling any incomming connection while there is still a live translation thread.
#
# v3.2.2
# Added code and options to facilitate debugging.
#
# v3.2.1
# Fixed a bug that prevented the discovery of unknown tokens in the source string.
#
# v3.2
# Switched to using separate open3/open2 calls for launching the decoder and recaser in order to avoid involving the shell.
#
# v3.1
# We are now launching the segmenter or reorderer by passing a list of arguments to open2() to avoid involving the shell.
#
# v3.0
# Modified to included pre- and postprocessing code in order to reduce the number of active Perl interpreters during regular operation.
#
# v2.11
# Added provision to copy exactly the white space around PlaceHolders from source to target.
#
# v2.10
# Unknown words are now carried over to the translation in their original case. If there are several intances of an unknown word in the source that match when lowercased, what is carried over will match the case of only the first source instance for all target instances.
# Added an error message for the case where the input contains too many punctuation marks to prevent hogging down the tokeniser.
#
# v2.9.2
# Added a provision for handling actual tag data provided after a delimiter on each line to be translated.
# At present, these tags are simply ignored.
#
# v2.9.1
# Fixed a regression where the error strings for segments too long for MT would be returned with renumbered WorldServer Placeholders.
#
# v2.9
# Now we are renumbering the WorldServer PlaceHolders to start from 1 for each segment, thus trying to aleviate the problem that most PlaceHolders in text to be translated are treated as unknown words.
#
# v2.8.11
# Added options to the socket that will fascilitate faster restarting of the engines, as well as allow for guaranteed data delivery at engine shutdown.
#
# v2.8.10
# Fixed a bug where placeholders weren’t transfered to the target in cases where the source was not MT translatable (due to bad UTF-8 or length).
#
# v2.8.9
# Fixed a bug where the file name of the log file would be reported wrongly when stopping the engine.
#
# v2.8.8
# Added a timer to make sure the client indeed intends to provide content for translation.
#
# v2.8.7
# Switched to killing preprocessing tasks when translating into JPN in order to reduce waiting for the reordering process to finish.
#
# v2.8.6
# Added an extra check to make sure the client is actually alive and talking to us.
#
# v2.8.5
# Switched to killing Moses rather than waiting for it to cleanup and close down.
#
# v2.8.4
# Updated PATH variable to correspond to Moses binary placement on MT servers.
# Added -T switch to make the script more secure.
#
# v2.8.3
# Made sure that all output is unbuffered.
# Made it a requirement to specify the hostport so that this information doesn’t have to be hardcoded here.
#
# v2.8.2
# Adjusted the location of the recaser in *–EN translation cases.
#
# v2.8.1
# Made the masking of special characters internal, rather than launching extra Perl instances in the pre-/postprocessing pipelines.
#
# v2.8
# Added provision for segmenting JP and ZH source.
#
# v2.7
# Switched to a stricter version of UTF8 encoding and proper Unicode-based lowercasing.
#
# v2.6
# Fixed a bug affecting the PlaceHolder checking in cases where the pre-processing might destroy/alter some of the source-side PlaceHolders.
#
# v2.5
# Fixed bugs in information output to $client_sock and WorldServer PlaceHolder checking.
#
# v2.4.1
# Now will close the server port when exiting.
#
# v2.4
# Added handling of malformed UTF-8 input.
#
# v2.3
# Now we try to bind the server socket before we launch Moses to avoid unnecessary CPU and memory usage in cases where the port is still busy.
# Streamlined placeholder handling.
# Now a trailing / after an engine name is automatically stripped off.
#
# v2.2
# Added WorldServer placeholder handling.
# Added engine name to log file names.
#
# v2.1
# Now the script will get the hostname on its own.
# Added a provision to shut down the engine remotely by supplying the string ÷◊÷
#
# v2.0
# Added options to supply pre- and post-processing commands. These should be used to provide tokenisation, detokenisation and other text manipulations.
# Added a table of port assignments for available language pairs.
#
# v1.0
# Switched to named command-line arguments
# Added the option to run a segmenter if necessary
# 
###########################################

use strict;

use threads;
use threads::shared;
use Thread::Queue;

use utf8;

use Encode qw/encode decode/;
use IO::Socket::INET;
use IO::Select;
use Sys::Hostname;
use IPC::Open2;
use IPC::Open3;
use POSIX 'strftime';

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
$ENV{PATH} = "/usr/bin:/usr/local/bin:/local/cms/bin:/local/cms/moses/mosesdecoder/moses-cmd/src:/local/cms/bin/opennlp/bin";

$| = 1;
select STDERR;
$| = 1;


our ($moses, $engine, $hostname, $hostport, $preprocess, $base_dir, $perl_path, $VENTZI);
die encode "utf-8", "Usage: $0 -engine=… [-hostname=…] -hostport=… [-preprocess=…] [-moses=…] [-base_dir=…] [-perl_path=…]\n"
unless defined $engine && defined $hostport;

$engine =~ s,/$,,;
($engine) = $engine =~ /^([\p{IsAlNum}_-]{7,})$/;
$moses ||= "moses".($VENTZI ? "-ventzi" : "");
my ($srclang, $tgtlang) = map {lc $_} ($engine =~ /(?:^|_)(\p{IsAlpha}+(?:_\p{IsAlpha}+)?)-(\p{IsAlpha}+(?:_\p{IsAlpha}+)?)_/); #extract the language codes from the engine name
$hostname ||= &hostname();
if ($base_dir) {
	$base_dir .= "/" unless $base_dir =~ m!/$!;
} else {
	$base_dir = $VENTZI ? "/Volumes/OptiBay/Autodesk/" : "/local/cms/";
}
if ($perl_path) {
	$perl_path .= "/" unless $perl_path =~ m!/$!;
} else {
	$perl_path = $VENTZI ? "/usr/bin/" : "/usr/local/bin/";
}

# open server socket
my $server_sock = new IO::Socket::INET
(LocalAddr => $hostname, LocalPort => $hostport, Listen => 1)
or die encode "utf-8", "Can’t bind server socket on $hostname:$hostport! Aborting…\n";

$server_sock->sockopt(SO_REUSEADDR, 1);


my $MOSES_INI   = "${base_dir}$engine/model/moses.ini".($VENTZI ? ".ventzi" : "");
my $RECASER_INI = "${base_dir}$engine/recaser/moses.ini".($VENTZI ? ".ventzi" : "");

my $tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
my $logFileName = "${base_dir}LOG/${engine}_script_$tstamp.log";
open LOG, ">$logFileName"
or die encode "utf-8", "Cannot write to file $logFileName\n";
print STDERR encode "utf-8", "Logging $engine to $logFileName\n";
select LOG;
$| = 1;
print LOG encode "utf-8", "$tstamp: Starting Moses $engine, $srclang > $tgtlang on $hostname:$hostport\n";

my $reorder = $tgtlang =~ /^jp/ ? ["${perl_path}perl", '-s', "${base_dir}bin/reorder_jpn.pl", "-parser_cmd=/usr/bin/java -Xmx1024m -jar ${base_dir}bin/opennlp/lib/opennlp-tools-1.5.1-incubating.jar Parser ${base_dir}bin/opennlp/data/en-parser-chunking.bin 2>${base_dir}LOG/${engine}_opennlp_$tstamp.log"] : "" unless defined $preprocess;
my $segment = $srclang =~ /^jp|^zh/ ? ["${perl_path}perl", '-s', "${base_dir}bin/word_segmenter.pl", '-segmenter=kytea', "-model=${base_dir}share/kytea/".($srclang =~ /^jp/ ? 'jp-0.3.0-utf8-1.mod' : 'lcmc-0.3.0-1.mod')] : "" unless defined $preprocess;
$preprocess ||= $reorder || $segment;

require "${base_dir}bin/tokenise.pl"
or die encode "utf-8", "Could not load tokeniser at ${base_dir}bin/tokenise.pl\n";
my $tokeniserData = &initTokeniser($srclang, 0);
require "${base_dir}bin/detokenise.pl"
or die encode "utf-8", "Could not load tokeniser at ${base_dir}bin/detokenise.pl\n";
my $detokeniserData = &initDetokeniser($tgtlang);


# spawn moses and pre-/post-processor
my ($pre_in, $pre_out);
local(*MOSES_IN, *MOSES_OUT, *RECASER_OUT);
open \*MOSES_ERR, ">${base_dir}LOG/${engine}_moses_$tstamp.log"
or die encode "utf-8", "Could not write moses log file at “${base_dir}LOG/${engine}_moses_$tstamp.log”\n";
my $pid_moses = open3(\*MOSES_IN, \*MOSES_OUT, ">&MOSES_ERR", "$moses -f $MOSES_INI")
or die encode "utf-8", "Could not start decoder with command “$moses -f $MOSES_INI”\n";
my $pid_recaser = open2(\*RECASER_OUT, "<&MOSES_OUT", $moses, '-report-all-factors', '-v', '0', '-dl', '0', '-f', $RECASER_INI)
or die encode "utf-8", "Could not start recaser with command “$moses -report-all-factors -v 0 -dl 0 -f $RECASER_INI”\n";
select \*MOSES_IN;
$| = 1;
select \*RECASER_OUT;
$| = 1;

my $pid_preprocess = 0;
if ($preprocess) {
	$pid_preprocess = open2($pre_out, $pre_in, @$preprocess)
	or die encode "utf-8", "Could not start pre-processor with command “$preprocess”\n";
	select $pre_in;
	$| = 1;
}


my $finished :shared = 0;
my $jobs = Thread::Queue->new();
my $ready = Thread::Queue->new();
local $SIG{PIPE} = sub { lock $jobs; lock $ready; $jobs->extract(0, $jobs->pending() || 1); $ready->extract(0, $ready->pending() || 1); $ready->enqueue(1); $tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time())); die encode "utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Connection dropped / Preprocessor or Moses pipe is broken. Aborting on $tstamp…\n" };

my $translate = sub {
	for (;;) {
		my $data = $jobs->dequeue();
		my $end_ = 0;
		{ lock $finished;
			$end_ = !$data && $finished;
		}
		if ($end_) {
			$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
			print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": We appear to have finished processing. Sending shutdown signal to main thread $tstamp.\n");
			$ready->enqueue(0);
			return;
		}
		
		my $client_sock = $data->{sock} ? IO::Handle->new_from_fd($data->{sock}, "r+") : undef;
		
		unless (defined $client_sock) {
			$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
			print LOG encode "utf-8", "Client ".($data->{host} && $data->{port} ? "$data->{host}:$data->{port} " : "")."dropped connection on $tstamp!\n";
			$ready->enqueue(1);
			next;
		}
		
		$client_sock->autoflush(1);
		
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print LOG encode "utf-8", "Open $data->{host}:$data->{port} $tstamp";
		
		my $wc = my $linecount = 0;
		my $firstRead = 1;
		my $select = IO::Select->new();
		$select->add($client_sock);
		while (($client_sock) = $select->can_read(5)) {
			if ($client_sock->eof()) {
				if ($firstRead) {
					$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
					print STDERR encode "utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Received EOF early from $data->{host}:$data->{port} $tstamp\n";
					print LOG encode "utf-8", "  ÷÷÷ Received EOF early from $data->{host}:$data->{port} $tstamp";
					$ready->enqueue(1);
				}
				$firstRead = 0;
				last;
			}
			
			my $src = eval { scalar <$client_sock> };
			
			unless (defined $src && !$@) {
				if ($firstRead) {
					$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
					if ($@) {
						print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got error reading from $data->{host}:$data->{port} $tstamp.\n");
					} else {
						print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got nothing to read from $data->{host}:$data->{port} $tstamp.\n");
					}
					$ready->enqueue(1);
					$firstRead = 0;
				}
				last;
			}
			
			#DEBUG
			$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
			print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Started reading from $data->{host}:$data->{port} ($@) $tstamp.\n") if ($firstRead);
			
			my ($lineno) = $src =~ s/^(\d+:\s*)//;
			$lineno ||= "";
			
			my $encodingError = 0;
			$src = decode("utf-8", $src, sub {$encodingError = 1});
			if ($encodingError) {
				print $client_sock encode("utf-8", "$lineno".&checkPH($src, "### Non MT-Translatable: UTF-8 error ###")."\n");
				print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got UTF-8 error from $data->{host}:$data->{port} ($@) $tstamp.\n");
				if ($firstRead) {
					$ready->enqueue(1);
					$firstRead = 0;
				}
				next;
			}
			
			if ($firstRead) {
				if ($src =~ /÷◊÷/) {
					$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
					print $client_sock encode("utf-8", "Command acknowledged. Stopping engine $engine on $tstamp…\n");
					{ lock $finished;
						$finished = 1;
					}
					$ready->enqueue(0);
					return;
				}
				
				$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
				print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Sent a signal to main thread that we have started reading from $data->{host}:$data->{port} $tstamp.\n") if ($firstRead);				
				$ready->enqueue(1);
				$firstRead = 0;
			}
			
			chomp $src;
			
			#Shortcircuit for empty input.
			if ($src =~ /^\s*$/) {
				print $client_sock "\n";
				next;
			}
			
			my @tags;
			($src, @tags) = split m'#!@%!#', $src;
			
			my (%PHMap, $PHID);
			$PHMap{$_} = ++$PHID foreach ($src =~ /(?<=\{)\d+(?=\})/g);
			$src =~ s/(?<=\{)(\d+)(?=\})/$PHMap{$1}/g;
			%PHMap = reverse %PHMap;
			
			
			if ($reorder && (my $words = () = split ' ', $src, -1) > 50) {
				print $client_sock encode("utf-8", "$lineno".&checkPH($src, "### Non MT-Translatable: too long ###", \%PHMap)."\n");
			} else {
				my $pre_src = $src;
				$pre_src =~ tr/İI/iı/ if $srclang eq "tr";
				$pre_src =~ tr/\r/ /;
				$pre_src = &tokenise($tokeniserData, lc $pre_src);
				if ($preprocess) {
					print $pre_in encode "utf-8", "$pre_src\n";
					$pre_src = decode "utf-8", scalar <$pre_out>;
					chomp $pre_src;
				}
				$pre_src =~ tr/|<>()/│﹤﹥﹙﹚/;
				
				if (($words = () = split ' ', $pre_src, -1) > 200 || (() = split /,\.\(\)/, $pre_src, -1) > 100) {
					print $client_sock encode("utf-8", "$lineno".&checkPH($src, "### Non MT-Translatable: too long ###", \%PHMap)."\n");
				} else {
					$wc += $words;
				
					print MOSES_IN encode "utf-8", "$pre_src\n";
					my $trg = decode "utf-8", scalar <RECASER_OUT>;
					chomp $trg;
					my %unknowns = map {$_ => 1} $trg =~ /(?:^|\s+)([\p{IsAlNum}\-\{\}\/\<\>\[\]\(\)~,=_–—@*\'\"‘’“”.]+)(?=\|UNK\|UNK\|UNK)/g;
					foreach my $unknown (keys %unknowns) {
						($unknowns{$unknown}) = $src =~ /(?:^|\W)(\Q$unknown\E)(?=\W|$)/gi;
						$trg =~ s/(^|\W)\Q$unknown\E\|UNK\|UNK\|UNK/$1$unknowns{$unknown}/g if $unknowns{$unknown};
					}
					
					$trg =~ s/\|UNK\|UNK\|UNK//g;
					$trg =~ tr/│﹤﹥﹙﹚/|<>()/;
					
					unless ($engine =~ /DE/) {
						my ($tmp) = $src =~ /^(\p{IsAlpha})\p{Lower}*(?:\s|$)/;
						$trg =~ s/^(\p{IsAlpha})(?=\w*(?:\s|$))/uc $1/e if $tmp && $tmp =~ /\p{Upper}/;
						$trg =~ s/^(\p{IsAlpha})(?=\w*(?:\s|$))/lc $1/e if $tmp && $tmp =~ /\p{Lower}/;
					}
					
					$trg = &checkPH($src, $trg, \%PHMap, \@tags);
					
					$trg = &detokenise($detokeniserData, $trg);
					print $client_sock encode("utf-8", "$lineno$trg\n");
					
					++$linecount;
				}
			}
		}
		
		if ($firstRead) {
			$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
			print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": We did not get any data from the client ".($data->{host} && $data->{port} ? "$data->{host}:$data->{port} " : "")." $tstamp.\n");
			$ready->enqueue(1);
		}

		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print LOG encode "utf-8", " ÷÷÷ Close $tstamp; src lines: $linecount; words: $wc\n";
		($client_sock) = $select->handles();
		$client_sock->close();
	}
};

my $transThread = threads->create($translate);

while (my $client_sock = $server_sock->accept) {
	if ($client_sock->fileno) {
		#DEBUG
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got a new client to work with: ".$client_sock->peerhost.":".$client_sock->peerport." $tstamp\n");

		$jobs->enqueue({sock => $client_sock->fileno, host => $client_sock->peerhost, port => $client_sock->peerport});
		unless ($ready->dequeue()) {
			$server_sock->shutdown(2);
			$server_sock->close();
			last;
		}
		
		unless ($transThread->is_running()) {
			#DEBUG
			$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
			print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Translation thread has died! Restarting… $tstamp\n");
			$transThread = threads->create($translate);
		}
	} else {
		#DEBUG
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": !!! This client was dead on arrival: ".$client_sock->peerhost.":".$client_sock->peerport." $tstamp\n");
	}
}

{ lock $finished;
	$finished = 1;
}

if ($transThread->is_running()) {
	$jobs->enqueue(undef);
	$transThread->join();
}

print LOG encode "utf-8", "Stopped $engine on $tstamp\n";
print STDERR encode "utf-8", "Stopped $engine on $tstamp. Logged output to $logFileName\n";


close LOG;
if ($preprocess) {
	close $pre_in;
	close $pre_out;
}
close \*MOSES_IN;
close \*MOSES_OUT;
close \*MOSES_ERR;
close \*RECASER_OUT;

($tgtlang =~ /jp/ ? kill("KILL", $pid_preprocess) : waitpid($pid_preprocess, 0)) if $pid_preprocess;
kill("KILL", $pid_moses);
kill("KILL", $pid_recaser);


sub checkPH {
	my ($src, $trg, $PHMap, $tags) = @_;
	
	#Collect source PHs
	my %srcPHs = map {($_ => 1)} $src =~ /\{(\d+)\}/g;
	#Collect info on source PH white space
	my %PHSpacing;
	$src =~ s/(\s*)\{(\d+)\}(\s*)/$PHSpacing{$2} = [$1, $3]; "$1\{$2\}$3"/ge;
	#Match against target PHs
	map {$srcPHs{$_} ? $srcPHs{$_} = 0 : $trg =~ s/\{$_\}//} $trg =~ /\{(\d+)\}/g;
	$trg =~ s/^\s+|\s+$//g;
	#Insert any source PHs missing in the target
	foreach my $ph (sort {$a <=> $b} keys %srcPHs) {
		if ($srcPHs{$ph}) {
			my $placed = 0;
			my $pos = $ph + 1;
			while (defined $srcPHs{$pos} && !$placed) {
				unless ($srcPHs{$pos}) {
					$placed = 1;
					$trg =~ s/(\{$pos\})/\{$ph\}$1/;
				} else {
					++$pos;
				}
			}
			next if $placed;
			$pos = $ph - 1;
			while (defined $srcPHs{$pos} && !$placed) {
				unless ($srcPHs{$pos}) {
					$placed = 1;
					$trg =~ s/(\{$pos\})/$1\{$ph\}/;
				} else {
					--$pos;
				}
			}
			next if $placed;
			$trg .= " \{$ph\}";
		}
	}
	
	#Check for PH order errors and renumber target PHs if errors are found
	my %toClose;
	my $tagOrderError;
	foreach my $ph ($trg =~ /\{(\d+)\}/g) {
		my $trgTag = $tags->[$ph-1] or last;
		my $tag;
		if (($tag) = $trgTag =~ m!^\s*</(\w+)[\s>]!m) {
			if (defined $toClose{$tag} && @{$toClose{$tag}}) {
				pop @{$toClose{$tag}};
			} else {
				++$tagOrderError;
				last;
			}
		} elsif (($tag) = $trgTag =~ m!^\s*<(\w+)[\s>]!m) {
			push @{$toClose{$tag}}, $ph;
		}
	}
	if ($tagOrderError) {
		my $tag = 0;
		$trg =~ s/(?<=\{)\d+(?=\})/++$tag/ge;
	}
	
	if ($PHMap) {
		#Recreate PH white space in target and remap PlaceHolders if necessary
		$trg =~ s/\s*\{(\d+)\}\s*/$PHSpacing{$1}->[0]\{$PHMap->{$1}\}$PHSpacing{$1}->[1]/g;
	} else {
		#Recreate PH white space in target
		$trg =~ s/\s*\{(\d+)\}\s*/$PHSpacing{$1}->[0]\{$1\}$PHSpacing{$1}->[1]/g;
	}
	
	$trg;	
}


1;