#!/usr/local/bin/perl -wTs
#
# file: moses_server.ventzi.pl
#
# ©2009–2014 Autodesk Development Sàrl
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
#
# ChangeLog
# v3.8.10		modified on 14 Aug 2014 by Ventsislav Zhechev
# Added a JP-specific check to fix a specific placeholder disorder.
#
# v3.8.9		modified on 06 May 2014 by Ventsislav Zhechev
# Removed erroneously leftover options for Moses to output search graphs.
#
# v3.8.8		modified on 05 May 2014 by Ventsislav Zhechev
# Fixed a bug in the PH order checks.
#
# v3.8.7		modified on 17 Oct 2013 by Ventsislav Zhechev
# Fixed a bug in the processing of glossary terms where only the first glossary term might be replaced in each segment.
#
# v3.8.6		modified on 12 Jul 2013 by Ventsislav Zhechev
# Fixed a bug in the processing of glossary terms where substitution could be made within the markup of already processed terms.
#
# v3.8.5		modified on 06 Jun 2013 by Ventsislav Zhechev
# Fixed a bug in the processing of glossary terms where string comparison was used instead of number comparison during sorting.
#
# v3.8.4		modified on 15 May 2013 by Ventsislav Zhechev
# Fixed a bug that prevented the use of preprocessor commands supplied as a command line parameter
#
# v3.8.3		modified on 01 Mar 2013 by Ventsislav Zhechev
# Fixed a bug with the handling of glossary replacements. In particular, the issue could occur with short URLs that are a substring of the localised version of a long URL. For example: www.autodesk.com is a substring of http://www.autodesk.com.cn that is the localised version of http://www.autodesk.com
#
# v3.8.2		modified on 14 Feb 2013 by Ventsislav Zhechev
# Added code to preserve source white space padding in the output.
#
# v3.8.1		modified on 24 Jan 2013 by Ventsislav Zhechev
# Fixed a bug with the regex matching glossary entries.
#
# v3.8		modified on 16 Jan 2013 by Ventsislav Zhechev
# Added provision to process annotated UI references.
# Fixed the handling of Moses error output on neucmslinux.
#
# v3.7.9
# Added a check to make sure that the MT engine is installed in the expected location.
#
# v3.7.8
# Improved the handling of potentially tainted variables.
# Fixed the handling of Moses error output on VENTZI’s machine.
# Fixed a bug where positive Moses scores weren’t captured.
#
# v3.7.7
# Now we are sending back a Moses score of ‘0’ for cases where no translation could be generated due to an error.
#
# v3.7.6
# Improved the handling of glossary terms in the presence of dashes and underscores.
#
# v3.7.5
# Improved the detection of glossary terms.
# Improved the detection of Moses engine readiness.
#
# v3.7.4
# Removed some unnecessary package includes.
#
# v3.7.3
# Added code to use supplied glossary terms and their translations. The terms and translations have to be passed on by the client in a -separated list after each relevant segment. For this to work, Moses is explicitly started with the -xml-input flag set to ‘exclusive’.
#
# v3.7.2
# Modified the treatment of unknown words to be more permissive of what characters may be present in a word.
# Added code to extract the Moses transation scores and provide them to the client after a  delimiter.
#
# v3.7.1
# Set $SIG{PIPE} to IGNORE—we do not expect Moses to die any more and dropped connections should be handled elsewhere.
#
# v3.7
# Removed the complicated thread system to improve perfomance and error resistance.
#
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

use utf8;

use Encode qw/encode decode/;
use IO::Socket::INET;
use IO::Select;
use Sys::Hostname;
use IPC::Open2;
use IPC::Open3;
use POSIX qw/strftime/;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)}; # Make %ENV safer
$ENV{PATH} = "/usr/bin:/usr/local/bin:/local/cms/bin:/local/cms/moses/mosesdecoder/moses-cmd/src:/local/cms/bin/opennlp/bin";

$| = 1;
select STDERR;
$| = 1;


our ($moses, $engine, $hostname, $hostport, $preprocess, $base_dir, $perl_path, $VENTZI);
die encode "utf-8", "Usage: $0 -engine=… [-hostname=…] -hostport=… [-preprocess=…] [-moses=…] [-base_dir=…] [-perl_path=…]\n"
unless defined $engine && defined $hostport;

$VENTZI = 1 if defined $VENTZI;
$engine =~ s,/$,,;
($engine) = $engine =~ /^([\p{IsAlNum}_-]{7,})$/;
$moses ||= "moses".($VENTZI ? "-ventzi" : "");
#($moses) = $moses =~ /^(moses(?:-ventzi)?)$/;
my ($srclang, $tgtlang) = map {lc $_} ($engine =~ /(?:^|_)(\p{IsAlpha}+(?:_\p{IsAlpha}+)?)-(\p{IsAlpha}+(?:_\p{IsAlpha}+)?)_/); #extract the language codes from the engine name
if (defined $hostname) {
	($hostname) = $hostname =~ /(\p{IsAlpha}+)/;
} else {
	$hostname = &hostname();
}
($hostport) = $hostport =~ /(\d{4})/;
if ($base_dir) {
	($base_dir) = $base_dir =~ m!^(/\w+/\w+(?:/\w+)?/?)$!;
	$base_dir .= "/" unless $base_dir =~ m!/$!;
} else {
	$base_dir = $VENTZI ? "/Volumes/LaCie_Work/Autodesk/" : "/local/cms/";
}
if ($perl_path) {
	$perl_path .= "/" unless $perl_path =~ m!/$!;
} else {
	$perl_path = $VENTZI ? "/usr/bin/" : "/usr/local/bin/";
}

my $MOSES_INI   = "${base_dir}$engine/model/moses.ini".($VENTZI ? ".ventzi" : "");
my $RECASER_INI = "${base_dir}$engine/recaser/moses.ini".($VENTZI ? ".ventzi" : "");
die encode "utf-8", "Engine not found in default location “${base_dir}$engine”!\n" unless -e $MOSES_INI && -e $RECASER_INI;

#######
#sub is_tainted {
#	return ! eval {
#		join('',@_), kill 0;
#		1;
#	};
#}
#if ( is_tainted($hostport) ) { die "tainted"; } else { die "not tainted"; }
#######

# open server socket
my $server_sock = new IO::Socket::INET
(LocalAddr => $hostname, LocalPort => $hostport, Listen => 1)
or die encode "utf-8", "Can’t bind server socket on $hostname:$hostport! Aborting…\n";

$server_sock->sockopt(SO_REUSEADDR, 1);

my $tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
my $logFileName = "${base_dir}LOG/${engine}_script_$tstamp.log";
open LOG, ">$logFileName"
or die encode "utf-8", "Cannot write to file $logFileName\n";
print STDERR encode "utf-8", "Logging $engine to $logFileName\n";
select LOG;
$| = 1;
print LOG encode "utf-8", "$tstamp: Starting Moses $engine, $srclang > $tgtlang on $hostname:$hostport\n";

my ($reorder, $segment);
if (defined $preprocess) {
	($preprocess) = $preprocess =~ m!^(/usr/.*?bin/perl -.?.?s /.+?/.+?.pl .*)$!;
} else {
	$reorder = $tgtlang =~ /^jp/ ? ["${perl_path}perl", '-s', "${base_dir}bin/reorder_jpn.pl", "-parser_cmd=/usr/bin/java -Xmx1024m -jar ${base_dir}bin/opennlp/lib/opennlp-tools-1.5.1-incubating.jar Parser ${base_dir}bin/opennlp/data/en-parser-chunking.bin 2>${base_dir}LOG/${engine}_opennlp_$tstamp.log"] : "";
	$segment = $srclang =~ /^jp|^zh/ ? ["${perl_path}perl", '-s', "${base_dir}bin/word_segmenter.pl", '-segmenter=kytea', "-model=${base_dir}share/kytea/".($srclang =~ /^jp/ ? 'jp-0.3.0-utf8-1.mod' : 'lcmc-0.3.0-1.mod')] : "";
	$preprocess ||= $reorder || $segment;
}

require "${base_dir}bin/tokenise.pl"
or die encode "utf-8", "Could not load tokeniser at ${base_dir}bin/tokenise.pl\n";
my $tokeniserData = &initTokeniser($srclang, 0);
require "${base_dir}bin/detokenise.pl"
or die encode "utf-8", "Could not load tokeniser at ${base_dir}bin/detokenise.pl\n";
my $detokeniserData = &initDetokeniser($tgtlang);


# spawn moses and pre-/post-processor
my ($pre_in, $pre_out);
local(*MOSES_IN, *MOSES_OUT, *RECASER_OUT);
$> = $<;
$) = $(;
open \*MOSES_LOG, ">${base_dir}LOG/${engine}_moses_$tstamp.log"
or die encode "utf-8", "Could not write moses log file at “${base_dir}LOG/${engine}_moses_$tstamp.log”\n";
select \*MOSES_LOG;
$| = 1;
my $pid_moses = open3(\*MOSES_IN, \*MOSES_OUT, \*MOSES_ERR, "$moses -xml-input exclusive -f $MOSES_INI")
or die encode "utf-8", "Could not start decoder with command “$moses -f $MOSES_INI”\n";
select \*MOSES_ERR;
$| = 1;
for (;;) {
	my $logLine = <MOSES_ERR>;
	print MOSES_LOG $logLine;
	if ($logLine =~ /Created input-output object/) {
		print MOSES_LOG encode "utf-8", "≈≈≈Starting regular STDERR reading from here≈≈≈\n";
		last;
	}
}
my $firstRun = 1;
my $pid_recaser = open2(\*RECASER_OUT, "<&MOSES_OUT", $moses, '-report-all-factors', '-v', '0', '-dl', '0', '-f', $RECASER_INI)
or die encode "utf-8", "Could not start recaser with command “$moses -report-all-factors -v 0 -dl 0 -f $RECASER_INI”\n";
select \*MOSES_IN;
$| = 1;
select \*RECASER_OUT;
$| = 1;

my $pid_preprocess = 0;
if ($preprocess) {
	$pid_preprocess = open2($pre_out, $pre_in, ref($preprocess) eq "ARRAY" ? @$preprocess : ($preprocess))
	or die encode "utf-8", "Could not start pre-processor with command “$preprocess”\n";
	select $pre_in;
	$| = 1;
}


#local $SIG{PIPE} = sub { $tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time())); die encode "utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Connection dropped / Preprocessor or Moses pipe is broken. Aborting on $tstamp…\n" };
local $SIG{PIPE} = 'IGNORE';


while (my $client_sock = $server_sock->accept()) {
	my $clientHost = $client_sock->peerhost;
	my $clientPort = $client_sock->peerport;
	#DEBUG
	$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
	print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got a new client to work with: ".$clientHost.":".$clientPort." $tstamp\n");
	
	if ($client_sock->fileno()) {
		#DEBUG
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Started reading from ".$clientHost.":".$clientPort." $tstamp.\n");
		
		my $mustExit = 0;
		
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print LOG encode "utf-8", "Open ".$clientHost.":".$clientPort." $tstamp";
#		print STDERR encode "utf-8", "Open ".$clientHost.":".$clientPort." $tstamp";
		
		$client_sock->autoflush(1);
		
		my $select = IO::Select->new();
		$select->add($client_sock);
		
		my $wc = my $linecount = 0;
		
		for (;;) {
			my ($client_sock) = $select->can_read(5);
			
			if (!defined $client_sock || $client_sock->eof()) {
#				$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
#				print STDERR encode "utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Looks like we need to close the line at $tstamp; src lines: $linecount; words: $wc\n";
				last;
			}
			
			my $src = eval { scalar <$client_sock> };
			
			last unless defined $src && !$@;
			
			my $encodingError = 0;
			$src = decode("utf-8", $src, sub {$encodingError = 1});
			if ($encodingError) {
				print $client_sock encode("utf-8", &checkPH($src, "### Non MT-Translatable: UTF-8 error ###")."0\n");
				print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got UTF-8 error from ".$clientHost.":".$clientPort." ($@) $tstamp.\n");
				next;
			}
			
			if ($src =~ /÷◊÷/) {
				$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
				print $client_sock encode("utf-8", "Command acknowledged from ".$clientHost.":".$clientPort.". Stopping engine $engine on $tstamp…\n");
				$mustExit = 1;
				sleep 1;
				last;
			}
			
			chomp $src;
			
			#Shortcircuit for empty input.
			if ($src =~ /^\s*$/) {
				print $client_sock "\n";
				next;
			}
			
			my %gloss = ();
			($src, %gloss) = split //, $src if $src =~ /^[^]/;
			my @tags = ();
			($src, @tags) = split m'#!@%!#', $src;
			
			my (%PHMap, $PHID);
			$PHMap{$_} = ++$PHID foreach ($src =~ /(?<=\{)\d+(?=\})/g);
			$src =~ s/(?<=\{)(\d+)(?=\})/$PHMap{$1}/g;
			%PHMap = reverse %PHMap;
			
			if ($reorder && (my $words = () = split ' ', $src, -1) > 50) {
				print $client_sock encode("utf-8", &checkPH($src, "### Non MT-Translatable: too long ###", \%PHMap)."0\n");
			} else {
				my $pre_src = $src;

				my (%UIRefs, $UIRefID);
				$pre_src =~ s/<uiref translation=(.*?)<\/uiref>/$UIRefs{++$UIRefID} = $1; "$UIRefID"/ge;
				
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
					print $client_sock encode("utf-8", &checkPH($src, "### Non MT-Translatable: too long ###", \%PHMap)."0\n");
				} else {
					$wc += $words;
					
					foreach my $gloss (sort {length $b <=> length $a} keys %gloss) {
						if ($pre_src =~ />/) {
							$pre_src =~ s/(^|[^\"]>|[^\p{IsAlNum}\">])(?<!\p{IsAlNum}[\-_])\Q$gloss\E(?:e?s)?(?![\-_]\p{IsAlNum})(?=[^\p{IsAlNum}\"<]|<[^\/]|$)/$1<gloss translation="$gloss{$gloss}">$gloss<\/gloss>/g;
						} else {
							$pre_src =~ s/(^|[^\p{IsAlNum}\"])(?<!\p{IsAlNum}[\-_])\Q$gloss\E(?:e?s)?(?![\-_]\p{IsAlNum})(?=[^\p{IsAlNum}\"]|$)/$1<gloss translation="$gloss{$gloss}">$gloss<\/gloss>/g;
						}
					}
					
					$pre_src =~ s/(\d+)/<uiref translation=$UIRefs{$1}<\/uiref>/g;
					
					print MOSES_IN encode "utf-8", "$pre_src\n";
					my $mosesScore;
					my $limit = $VENTZI ? ($firstRun ? 12 : 8) : ($firstRun && $hostname ne "neucmslinux" && $hostname ne "mt" ? 10 : 7);
					$firstRun &&= 0;
					foreach (1..$limit) {
						my $logLine = <MOSES_ERR>;
						print MOSES_LOG $logLine;
						if ($logLine =~ /BEST TRANSLATION:/) {
							my ($total, $penalty) = $logLine =~ /\[total=(-?[\d\.]+)\] <<(?:-?[\d\.]+, ){2,2}(-?[\d\.]+),/;
							$mosesScore = $total - $penalty;
						}
					}
					my $trg = decode "utf-8", scalar <RECASER_OUT>;
#					last if $killed;
					chomp $trg;
					my %unknowns = map {$_ => 1} $trg =~ /(?:^|\s+)([^\s]+)(?=\|UNK\|UNK\|UNK)/g;
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

					#Preserve source white space padding in the target.
					my ($whiteSpacePadding) = $src =~ /(\s+)$/;
					$trg .= $whiteSpacePadding if defined $whiteSpacePadding;
					($whiteSpacePadding) = $src =~ /^(\s+)/;
					$trg = "$whiteSpacePadding$trg" if defined $whiteSpacePadding;
					
					print $client_sock encode("utf-8", "$trg$mosesScore\n");
					
					++$linecount;
				}
			}
		}
		
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print LOG encode "utf-8", " ÷÷÷ Close $tstamp; src lines: $linecount; words: $wc\n";
#		print STDERR encode "utf-8", "Closing the line at $tstamp; src lines: $linecount; words: $wc\n";
		$client_sock->shutdown(2);
		$client_sock->close();
		if ($mustExit) {
			$server_sock->shutdown(2);
			$server_sock->close();
			last;
		}
		
	} else {
		#DEBUG
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": !!! This client was dead on arrival: ".$clientHost.":".$clientPort." $tstamp\n");
	}
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
	if ($tgtlang eq "jp" && $src =~ /^\{1}.*\{2}$/ && $trg !~ /^\{1}.*\{2}$/) {
		$trg =~ s/{\d}/ /g;
		$trg = "{1}$trg\{2\}";
	} else {
		my @toClose;
		my $tagOrderError;
		foreach my $ph ($trg =~ /\{(\d+)\}/g) {
			my $trgTag = $tags->[$ph-1] or last;
			my $tag;
			if (($tag) = $trgTag =~ m!^\s*</(\w+)[\s>]!m) {
				if (@toClose && $toClose[-1]->{tag} eq $tag) {
					pop @toClose;
				} else {
					++$tagOrderError;
					last;
				}
			} elsif (($tag) = $trgTag =~ m!^\s*<(\w+)[\s>]!m) {
				push @toClose, {tag => $tag, ph => $ph};
			}
		}
		if ($tagOrderError) {
			my $tag = 0;
			$trg =~ s/(?<=\{)\d+(?=\})/++$tag/ge;
		}
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