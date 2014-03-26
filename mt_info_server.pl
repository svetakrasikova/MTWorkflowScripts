#!/usr/local/bin/perl -wTs
#
# ©2011–2014 Autodesk Development Sàrl
# Created on 17 Oct 2011 by Ventsislav Zhechev
#
# ChangeLog
# v1.10.6		Modified on 04 Mar 2014 by Ventsislav Zhechev
# Increased the Moses read timeout to 60sec.
#
# v1.10.5		Modified on 14 Feb 2014 by Ventsislav Zhechev
# All error messages sent to clients now start with ‘ ’.
#
# v1.10.4		Modified on 13 Feb 2014 by Ventsislav Zhechev
# Improved the statistics collecting routines.
# Removed the dependency on a fiscal year parameter.
#
# v1.10.3		Modified on 06 Feb 2014 by Ventsislav Zhechev
# Fixed a bug with the search for available servers after multiple Moses server timeout.
# Segregated the code for free MT server search in a separate method to simplify maintenance
# Added a fixed limit to the number of retries when searching for a free MT servers.
# 
# v1.10.2		Modified on 28 Jan 2014 by Ventsislav Zhechev
# Now we only allow one translate request per connection. If more translations are required, a reconnection is necessary.
#
# v1.10.1		Modified on 18 Dec 2013 by Ventsislav Zhechev
# Fixed a bug where an empty set of term translations from the Term Translation Central would not be accepted as a correct result.
#
# v1.10			Modified on 10 Dec 2013 by Ventsislav Zhechev
# Now we are checking online on the Term Translation Central for available glossary entries.
#
# v1.9.1		Modified on 09 Oct 2013 by Ventsislav Zhechev
# Small updates to some status messages.
# Slightly modified the parameters used when opening the server socket.
#
# v1.9			Modified on 08 Oct 2013 by Ventsislav Zhechev
# Significant improvements to the handling of dropped connections.
# Translation pre-processing tasks are now performed before checking for available live servers for translation. Before, the selected live servers could become busy while pre-processing.
# Slightly modified the parameters used when opening the server socket.
# Fixed a bug where the restartSerivce operation would not work when running with a non-standard hostname.
# Cleaned up some error and status messages.
# Minor code cleanup.
#
# v1.8.2		Modified on 24 Jun 2013 by Ventsislav Zhechev
# We now allow the ‘:’ character in the glossaries.
#
# v1.8.1		Modified on 27 May 2013 by Ventsislav Zhechev
# Added a few log messages.
# Fixed a bug where an extra new line was appended to segments that needed to be translated at a too early step in the processing workflow.
# Glossary matching is now case-insensitive.
# Now we are using the system’s sleep function rather than Perl’s during a service restart—otherwise ports weren’t freed on time.
#
# v1.8			Modified on 13 Mar 2013 by Ventsislav Zhechev
# Added timeout to primary user requests. This should aleviate the issue of handler processes being left alive after the client has left without closing the connection properly.
#
# v1.7.3		Modified on 01 Mar 2013 by Ventsislav Zhechev
# Compatibility fix for UIRef lookup API.
#
# v1.7.2		Modified on 08 Feb 2013 by Ventsislav Zhechev
# Updated the workaround for handling EN-PT_PT engines.
#
# v1.7.1		Modified on 18 Jan 2013 by Ventsislav Zhechev
# Added a temporary measure to handle EN to PT-PT translation using PT-BR engines.
#
# v1.7			Modified on 18 Jan 2013 by Ventsislav Zhechev
# Added a subroutine to process UI Reference annotations in the data by querying Solr for translations.
#
# v1.6.28		Modified on 09 Jan 2013 by Ventsislav Zhechev
# Now the hyphen is an allowed charachter in the values of commands. This modification was needed to support certain product names.
# Fixed a bug where the specifics of URL data would break the reading of the glossary data file.
#
# v1.6.27		Modified by Ventsislav Zhechev
# Added a subroutine to match URLs against a database of localised entries.
#
# v1.6.26		Modified by Ventsislav Zhechev
# Added an extra check for a proper return from the MT engine.
#
# v1.6.25		Modified by Ventsislav Zhechev
# The update command was useless and is now removed. It could not really force an update of serverSetup data, as it was running in a forked process.
# Improved the handling of glossary terms in the presence of dashes and underscores.
#
# v1.6.24		Modified by Ventsislav Zhechev
# The update command will now also update the product glossaries.
# Improved the detection of glossary terms.
#
# v1.6.23		Modified by Ventsislav Zhechev
# Added a hash to store product name correspondencies to short product codes.
# Relaxed the restrictions on the characters that can be used in the glossary file.
#
# v1.6.22		Modified by Ventsislav Zhechev
# Added a command for restarting the MT Info Service.
#
# v1.6.21		Modified by Ventsislav Zhechev
# Added a subroutine that matches glossary entries against input segments for translation.
#
# v1.6.20		Modified by Ventsislav Zhechev
# If a client wants to handle the scores returned by Moses, it has to indicate this by setting the getScore parameter to true. Otherwise, the scores will be stripped before returning the translations.
#
# v1.6.19		Modified by Ventsislav Zhechev
# Updated to properly understand the client reply when stopping an engine.
#
# v1.6.18		Modified by Ventsislav Zhechev
# Added ‘product’ to the list of commands, so that product information can be supplied with translation requests.
#
# v1.6.17		Modified by Ventsislav Zhechev
# Added the number of available servers for translation to the debug output.
#
# v1.6.16		Modified by Ventsislav Zhechev
# There was a bug on the moses_server side that is now fixed. A number of changes were made here to facilitate the new design.
#
# v1.6.15		Modified by Ventsislav Zhechev
# Added an option to point the script to a particular server setup file, rather than use the default, which will facilitate debugging.
#
# v1.6.14		Modified by Ventsislav Zhechev
# Another tentative fix for the previous bug.
#
# v1.6.13		Modified by Ventsislav Zhechev
# A potential fix for a strange bug where the translation thread could die unexpectedly.
#
# v1.6.12		Modified by Ventsislav Zhechev
# Now we’ll only warn rather than die on SIG{PIPE}.
# Fixed a bug where we might not be returning properly from the translation threads in case the client dropped connection.
#
# v1.6.11		Modified by Ventsislav Zhechev
# Fixed a bug, where a hostname supplied from the command line would remain tainted and prevent the script from launching.
# 
# v1.6.10		Modified by Ventsislav Zhechev
# Added some comments and streamlined the translation code.
#
# v1.6.9		Modified by Ventsislav Zhechev
# Improved the error handling during translation to reflect the improved behaviour of the Moses servers.
#
# v1.6.8		Modified by Ventsislav Zhechev
# Fixed a bug where the system would try endlessly to translate using unavailable engines, after reporting that no engine is isntalled for the language pair.
#
# v1.6.7		Modified by Ventsislav Zhechev
# Reduced the maximum number of translation server errors from 10 to 5.
#
# v1.6.6		Modified by Ventsislav Zhechev
# Now the server should be able to detect a dead client properly and seize processing the translation task.
#
# v1.6.5		Modified by Ventsislav Zhechev
# Small bugfixes.
#
# v1.6.4		Modified by Ventsislav Zhechev
# Fixed the error reporting when trying to stop an engine that was not running.
# Increased the timeout value to make sure we are not trying to start servers that are already running.
#
# v1.6.3		Modified by Ventsislav Zhechev
# Changed the default delay for searching for live MT servers to better cope with high-load situations.
#
# v1.6.2		Modified by Ventsislav Zhechev
# Improved the error message for requests for non-existent engines.
#
# v1.6.1		Modified by Ventsislav Zhechev
# Fixed a bug where setup data updates were not persistent. Eliminated the ‘update’ command, as it did not allow for persistent data.
# Fixed a bug where updating setup data would not delete existing entries in the data hashes.
# Fixed a bug where firewall blocked ports could result in big delays during server availability checks.
#
# v1.6			Modified by Ventsislav Zhechev
# The system is now able to reload its setup data online without the need for a restart. The operation ‘update’ is provided for this purpose.
# The check for live servers is now performed in parallel for all potential instances.
# Improved the translation performance, by fixing a bug in the local checking servers available for translation.
# 
# v1.5.25		Modified by Ventsislav Zhechev
# The ‘Stop’ command now communicates directly to the MT enignes rather than go via a shell command involving echo and nc.
# Modified the loop looking for live servers to perform translation.
#
# v1.5.24		Modified by Ventsislav Zhechev
# Improved the ‘Stop’ command in that it won’t block on slow servers.
#
# v1.5.23		Modified by Ventsislav Zhechev
# Added shortcuts for the mtprd* and ussclpdapcmsl* lines of servers, namely mtprd?? and ussclpdapcmsl??.
#
# v1.5.22		Modified by Ventsislav Zhechev
# Added new alternative language names for some languages and extended the language list to include all languages supported by WS.
#
# v1.5.21		Modified by Ventsislav Zhechev
# Now lowercases the languages regardless of whether the full name or a code was used.
#
# v1.5.20		Modified by Ventsislav Zhechev
# Temporarily added engines for some language pairs on mtprd* servers to fascilitate ussclpdapcmsl* server upgrade.
#
# v1.5.19		Modified by Ventsislav Zhechev
# Put a new EN-PT_BR engine in use.
#
# v1.5.18		Modified by Ventsislav Zhechev
# Reduced the number of engines for some laguages to reduce server load.
#
# v1.5.17		Modified by Ventsislav Zhechev
# Added provision to send data in smaller chunks to improve performance and reliability on slow connections.
#
# v1.5.16		Modified by Ventsislav Zhechev
# Added options to the server socket to make it work more reliably in borderline situations.
#
# v1.5.15		Modified by Ventsislav Zhechev
# Now we are writing out the time a client connection is closed to the log.
#
# v1.5.14		Modified by Ventsislav Zhechev
# Rearranged the checks for proper command syntax.
#
# v1.5.13		Modified by Ventsislav Zhechev
# Added a check for bad data for number of segments to translate.
#
# v1.5.12		Modified by Ventsislav Zhechev
# Added extra debugging info.
#
# v1.5.11		Modified by Ventsislav Zhechev
# Added a check to make sure that the client provided as many segments for translation as promised.
#
# v1.5.10		Modified by Ventsislav Zhechev
# Now the system will try and reacquire MT servers if it has leftover jobs.
#
# v1.5.9		Modified by Ventsislav Zhechev
# Adjusted translation transaction timeout values.
# The maximum translation job size is now restricted to 25 even if we only have one MT server to work with.
#
# v1.5.8		Modified by Ventsislav Zhechev
# Eliminated a race condition where two translation threads would try to grab the same job from the queue.
#
# v1.5.7		Modified by Ventsislav Zhechev
# Now we are removing any and all \r and \n from the end of input lines in case data is sent in with Windows file endings.
#
# v1.5.6		Modified by Ventsislav Zhechev
# Added a unique ID prefix to debug messages during translation jobs.
#
# v1.5.5		Modified by Ventsislav Zhechev
# The timeout used in &check() is now being set by the caller in order to provide the proper operation for each usage scenario.
#
# v1.5.4		Modified by Ventsislav Zhechev
# Fixed a bug where a failure to connect to an MT server would result in the discarding of the current translation job.
#
# v1.5.3		Modified by Ventsislav Zhechev
# Changed handling of TCP/IP connection errors. Now rather than send an error message to the client and kill the thread, the server in question is removed from the @liveServers list.
# Set a minimum translation job size to avoid hitting servers with too small jobs.
# Increased the maximum retry count for MT server errors.
# Now we are shuffling the @liveServers to distribute load more evenly among competing tasks.
#
# v1.5.2		Modified by Ventsislav Zhechev
# Updated Turkish engine availability.
#
# v1.5.1		Modified by Ventsislav Zhechev
# Fixed a bug when cleaning up uneeded servers for small translation tasks.
# Improved the output of processed translation jobs within a task.
# Added robustness to deal with unresponsive MT servers. A message is output to the client to report an MT error.
#
# v1.5			Modified by Ventsislav Zhechev
# Switched to using Thread::Queue for translation job processing.
# Implemented IO::Select for read/write timeouts when communicating with Moses.
#
# v1.4.3		Modified by Ventsislav Zhechev
# Updated the MT engine placement.
#
# v1.4.2		Modified by Ventsislav Zhechev
# Fixed bugs when no languages are specified.
# If you request translation into a language other than English, the system doesn’t ask you any more to specify source language.
# Fixed a bug where translation would not work properly if the last line of input did not end with EOL.
#
# v1.4.1		Modified by Ventsislav Zhechev
# Updated language definitions to avoid casing conflicts.
#
# v1.4			Modified by Ventsislav Zhechev
# Added the possibility to specify a list of servers.
# Added the possibility to specify languages using full English names.
#
# v1.3.1		Modified by Ventsislav Zhechev
# Fixed a few encoding glitches.
#
# v1.3			Modified by Ventsislav Zhechev
# Provided interface to perform translation. This requires the specification of a single source language and will produce translations in all corresponding target languages. Load balancing is provided for translation, utilising all available servers for the requested translations.
# Now &stop()  returns a list of stopped servers.
# Now &check() returns a list of running servers.
# Now &start() returns a list of started servers.
# If no engines were stopped, do not wait before running &start() if given the ‘restart’ command.
# Now only engines that were actually started will be checked after a ‘start’ command. If no new engines were started, no checking will be done and, therefore, no waiting.
#
# v1.2			Modified by Ventsislav Zhechev
# Switched to using a job queue so that the waits are done after all stops and starts, rather than individually by engine.
#
# v1.1.2		Modified by Ventsislav Zhechev
# Optimised the placement of MT engines on the mtprd* servers.
#
# v1.1.1		Modified by Ventsislav Zhechev
# Updated engine availability data
#
# v1.1			Modified by Ventsislav Zhechev
# Added collection of statistics on request.
#
# v1.0			Modified by Ventsislav Zhechev
#
####################

use strict;
no strict qw/refs/;
use utf8;

use lib "/local/users/cmsuser/perl5/lib/perl5";

use threads;
use threads::shared;
use Thread::Queue;

use Encode qw/encode decode/;
use IO::Select;
use IO::Socket::INET;
use POSIX qw/:sys_wait_h strftime floor ceil EINTR WNOHANG/;
use List::Util qw/min shuffle/;
use LWP::UserAgent;
use URI::Escape::XS qw/uri_escape/;


$| = 1;
$" = ", ";

select STDERR;
$| = 1;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
$ENV{PATH} = "/usr/bin:/local/cms/bin";

our $sleep;
sleep 60 if defined $sleep;

our $wait;
$wait ||= 60;

my $MAX_ERRORS = 5;

my ($checkupToken, $stopToken) = qw/ ÷◊÷/;
our ($hostname, $hostport, $DEBUG);

my (@languages, %localeMap, %engines, %ports, %servers, %segmenters);
our $serverSetupFile;
if ($serverSetupFile) {
	($serverSetupFile) = $serverSetupFile =~ m!^(/local/cms/bin/.*ini)$!;
} else {
	$serverSetupFile = "/local/cms/bin/serverSetup.ini";
}

my $serverSetupTStamp;

sub updateSetupData {
	my $firstRead = shift;
	if ($firstRead) {
		$serverSetupTStamp = -M $serverSetupFile;
	} else {
		my $newTStamp = -M $serverSetupFile;
		return 0 unless $newTStamp < $serverSetupTStamp;
		$serverSetupTStamp = $newTStamp;
	}
	print LOG encode("utf-8", "Updating server setup…\n");
	print STDERR encode("utf-8", "Updating server setup…\n") if $DEBUG;
	
	@languages = (); %localeMap = (); %engines = (); %ports = (); %servers = (); %segmenters = ();
	
	my $serverSetupData;
	open SSF, "<$serverSetupFile"
	or die "MT Info Service Setup File not available at $serverSetupFile!!!\n";
	local $/;
	$serverSetupData = <SSF>;
	close SSF;
	($serverSetupData) = $serverSetupData =~ /^([©à{}()\[\]\/=>\$\%\@\.,_\#\"\p{IsAlNum}\s]+)$/s;
	eval $serverSetupData;
	
	return 1;
}

my (%products, %glossary, %urls);
our $glossaryFile;
if ($glossaryFile) {
	($glossaryFile) = $glossaryFile =~ m!^(/local/cms/bin/.*gloss)$!;
} else {
	$glossaryFile = "/local/cms/bin/serverSetup.gloss";
}

my $glossaryTStamp;

sub updateGlossaryData {
	my $firstRead = shift;
	if ($firstRead) {
		$glossaryTStamp = -M $glossaryFile;
	} else {
		my $newTStamp = -M $glossaryFile;
		return 0 unless $newTStamp < $glossaryTStamp;
		$glossaryTStamp = $newTStamp;
	}
	print LOG encode("utf-8", "Updating glossary data…\n");
	print STDERR encode("utf-8", "Updating glossary data…\n") if $DEBUG;
	
	%products = ();
	%glossary = ();
	%urls = ();
	
	my $glossaryData;
	open GF, "<$glossaryFile"
	or die "MT Info Service Glossary File not available at $glossaryFile!!!\n";
	local $/;
	$glossaryData = decode "utf-8", <GF>;
	close GF;
	die "Bad MT Info Service Glossary File Data!!!\n"
	if $glossaryData =~ /\%urls.*\:[^\/\\\w].*\%glossary/s || $glossaryData =~ /\%urls.*\W\;\W.*\%glossary/s;
	($glossaryData) = $glossaryData =~ /^\#.*?\#\#\n([^\:\;]+\%urls.+\%glossary[^\;]+)$/s;
	eval $glossaryData;
	
	return 1;
}

my %commands = (
	sourceLanguage	=> 1,
	targetLanguage	=> 1,
	server					=> 1,
	port						=> 1,
	oper						=> 1,
	operation				=> 1,
	statistics			=> 1,
	translate				=> 1,
	segment					=> 1,
	product					=> 1,
	getScore				=> 1,
);


if ($hostname) {
	($hostname) = $hostname =~ /^(\w+)$/;
} else {
	$hostname = "neucmslinux";
}
$hostport ||= 2001;

# open server socket
my $server_sock = new IO::Socket::INET
	(LocalAddr => $hostname, LocalPort => $hostport, Listen => 1, ReuseAddr => 1, KeepAlive => 1)
	or die encode("utf-8", "Can’t bind server socket on $hostname:$hostport ($@)\n");

$server_sock->sockopt(SO_SNDLOWAT, 1);
$server_sock->sockopt(SO_SNDBUF, 16384);


my $tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
open LOG, ">/local/cms/LOG/mt_info_server_$tstamp.log"
or die encode("utf-8", "Cannot write to file /local/cms/LOG/mt_info_server_$tstamp.log\n");
print STDERR encode("utf-8", "Started MT Info Service on $hostname:$hostport at $tstamp".($DEBUG ? ". DEBUG" : "")."\n");
print LOG encode("utf-8", "Started MT Info Service on $hostname:$hostport at $tstamp".($DEBUG ? ". DEBUG" : "")."\n");

$SIG{CHLD} = 'IGNORE';

#Load system setup and glossaries at startup
updateSetupData 1;
updateGlossaryData 1;

my $finished = 0;
while (my $client_socket = $server_sock->accept()) {
	updateSetupData;
	updateGlossaryData;
	my $pid = fork();
	if ($pid) {
		next;
	}
	$client_socket->autoflush(1);

	$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
	print LOG encode("utf-8", "Connection from ".$client_socket->peerhost().":".$client_socket->peerport()." $tstamp… ");
	print STDERR encode("utf-8", "Connection from ".$client_socket->peerhost().":".$client_socket->peerport()." $tstamp…\n") if $DEBUG;
	
	my $restartService = 0;
	
	my $client_select = IO::Select->new();
	$client_select->add($client_socket);
	for (;;) {
		my ($client_sock) = $client_select->can_read(60);
		last if !defined $client_sock || $client_sock->eof();
		
		my $cmd = <$client_sock>;
		my $encodingError = 0;
		$cmd = decode("utf-8", $cmd, sub {$encodingError = 1});
		if ($encodingError) {
			print $client_sock encode("utf-8", " Your command is not UTF-8 compatible! Please retry…\n");
			next;
		}
		$cmd ||= "";
		
		if ($cmd =~ /$stopToken/) {
			print $client_sock encode("utf-8", "Command acknowledged. Stopping MT info service…\n");
			$finished = 1;
			last;
		}
		
		chomp $cmd;
		$cmd =~ s/\r*$//;
		unless ($cmd =~ /^\{\s*(\w+\s*=>\s*"?[\w?\[\] \(\),-]+"?,?\s*)*\}$/) {
			print $client_sock encode("utf-8", " Cannot interpret command “$cmd”! Aborting…\n");
			print STDERR encode("utf-8", "Bad command “$cmd” received from ".$client_socket->peerhost().":".$client_socket->peerport()."! Aborting…\n") if $DEBUG;
		} else {
			($cmd) = $cmd =~ /(^\{\s*(\w+\s*=>\s*"?[\w?\[\] \(\),-]+"?,?\s*)*\s*\}$)/;																											$cmd=~/\{/;
			$cmd =~ s/(?<==>)\s*([\w?\[\] \(\),-]+)(?=\s*(\}|,))/"$1"/g;
			print STDERR encode("utf-8", "Executing command “$cmd” for ".$client_socket->peerhost().":".$client_socket->peerport()."…\n") if $DEBUG;
			$cmd = eval $cmd;
			my ($srcLang, $trgLang, $server, $port, $oper, $collectStats, $translate, $update, $product, $getScore) = (@{$cmd}{qw/sourceLanguage targetLanguage server port operation statistics translate update product getScore/});

			my $commandError = 0;
			if ($oper) {
				$oper =~ s/^ +| +$//g;
				$oper = lc $oper;
				if ($oper eq "restartservice") {
					$restartService = 1;
					print $client_sock encode "utf-8", "Restarting MT Info Service! Service will be available again in 60 seconds…\n";
					last;
				} elsif ($oper eq "start" || $oper eq "stop" || $oper eq "check" || $oper eq "restart") {
					$port = 1;
					$server ||= 1;
				} else {
					print $client_sock encode("utf-8", " Unknown operation “$oper” requested! ");
					$commandError = 1;
				}
			}
			foreach (keys %$cmd) {
				unless ($commands{$_}) {
					print $client_sock encode("utf-8", " Unknown property “$_”! ");
					$commandError ||= 1;
				}
			}
			if ($commandError) {
				print $client_sock encode("utf-8", "Aborting…\n");
				next;
			}
		
			$translate = 0 unless defined $translate && $translate =~ /^\s*\d+\s*$/;
			if ($srcLang && $srcLang =~ /\]/ && $translate) {
				print $client_sock encode("utf-8", " You can only specify one source language when requesting translation! Aborting…\n");
				next;
			}
			if ($trgLang) {
				$trgLang =~ s/^ +| +$//g;
				$trgLang = lc $trgLang;
				$trgLang = $localeMap{lc $trgLang} unless $trgLang =~ /^\p{IsAlpha}\p{IsAlpha}(_\p{IsAlpha}{2,4})?$/;
				unless ($trgLang) {
					print $client_sock encode("utf-8", " Unknown target language specified! Aborting…\n");
					next;
				}
			}
			if ($srcLang) {
				$srcLang =~ s/^ +| +$//g;
				$srcLang = lc $srcLang;
				$srcLang = $localeMap{lc $srcLang} unless $srcLang =~ /^\p{IsAlpha}\p{IsAlpha}(_\p{IsAlpha}{2,4})?$/;
				unless ($srcLang) {
					print $client_sock encode("utf-8", " Unknown source language specified! Aborting…\n");
					next;
				}
			}
			if ($translate) {
				if (!$srcLang) {
					if ($trgLang && $trgLang ne "en") {
						$srcLang = "en";
						$port = 1;
						$server ||= 1;
					} else {
						print $client_sock encode("utf-8", " Please specify source language for translation! Aborting…\n");
						next;
					}
				} else {
					$port = 1;
					$server ||= 1;
				}
			}

			if ($server) {
				if ($server eq "?") {
					$server = 1;
				} else {
					$server = "[$server]" if $server =~ /\?\?/ && !($server =~ /]/);
					$server =~ s/mtprd\?\?/mtprd01, mtprd02, mtprd03, mtprd04, mtprd05, mtprd06, mtprd07, mtprd08, mtprd09, mtprd10, mtprd11, mtprd12/;
					$server =~ s/ussclpdapcmsl\?\?/ussclpdapcmsl01, ussclpdapcmsl02, ussclpdapcmsl03, ussclpdapcmsl04, ussclpdapcmsl05, ussclpdapcmsl06, ussclpdapcmsl07, ussclpdapcmsl08, ussclpdapcmsl09, ussclpdapcmsl10, ussclpdapcmsl11, ussclpdapcmsl12/;
					if ($server =~ /]/) {
						$server =~ s/([\w\.]+)/"$1"/g;
						$server = eval $server;
					}
				}
			}

			my $jobQueue = {};
			foreach $srcLang ($srcLang ? ($srcLang) : @languages) {
				my $translateData = [];
				if ($translate) {
					my $encodingError = 0;
					foreach (1..$translate) {
						if (my $line = <$client_sock>) {
							$encodingError = 0;
							$line = decode("utf-8", $line, sub {$encodingError = 1});
							if ($encodingError) {
								print $client_sock encode("utf-8", " Malformed UTF-8 encountered! Please retry…\n");
								print STDERR encode("utf-8", "Malformed UTF-8 encountered from ".$client_socket->peerhost().":".$client_socket->peerport()."!\n") if $DEBUG;
								last;
							}
							$line =~ s/[\h\v]+$//;
							push @$translateData, "$line";
						} else {
							print $client_sock encode("utf-8", " Too few segments provided for translation! Requested translation of $translate segments, but provided only ".($_-1).". Please retry…\n");
							print STDERR encode("utf-8", "Too few segments provided for translation by ".$client_socket->peerhost().":".$client_socket->peerport()."! ($translate vs ".($_-1).").\n") if $DEBUG;
							$encodingError = 1;
							last;
						}
					}
					last if $encodingError;
				}
				foreach $trgLang ($trgLang ? ($trgLang) : @languages) {
					next if $srcLang eq $trgLang || ($srcLang ne "en" && $trgLang ne "en");
					my $reply = "{sourceLanguage => \"$srcLang\", targetLanguage => \"$trgLang\"";
					$reply .= ", " if $server || $port;
					if ($server && $server eq "1") {
						my @srvs = map {"\"$_\""} @{$servers{$srcLang}->{$trgLang}};
						$reply .= "server => [@srvs]";
						$reply .= ", " if $port;
					} elsif ($server) {
						my %srvs = map {$_ => 1} @{$servers{$srcLang}->{$trgLang}};
						unless (ref $server) {
							unless ($srvs{$server}) {
								print $client_sock encode("utf-8", " No engine for ‘$srcLang => $trgLang’ available on server ‘$server’!\n");
								next;
							}
							$reply .= "server => [\"$server\"]";
						} else {
							my @goodSrvs;
							foreach (@$server) {
								unless ($srvs{$_}) {
									print $client_sock encode("utf-8", " No engine for ‘$srcLang => $trgLang’ available on server ‘$_’!\n");
									next;
								} else {
									push @goodSrvs, "\"$_\"";
								}
							}
							$reply .= "server => [@goodSrvs]";
						}
						$reply .= ", " if $port;
					}
					$reply .= "port => ".($ports{$srcLang}->{$trgLang} || -1) if $port;
					
					$reply .= "}\n";
					
					unless ($oper || $translate) {
						print $client_sock encode("utf-8", $reply);
					} else {
						my $engine = $engines{$srcLang}->{$trgLang};
						if ($engine) {
							if ($engine eq "n/a") {
								print $client_sock encode("utf-8", "{engine => \"n/a\", translate => 0}\n") if $translate;
								print $client_sock encode("utf-8", " $srcLang => $trgLang engine not installed!\n");
							} else {
								$engine =~ s/\#/"_".(uc $srcLang)."-".(uc $trgLang)."_"/e;
							}
							if ($oper) {
								push @{$jobQueue->{$oper}}, [$reply, $client_sock, $engine, $collectStats];
							} elsif ($translate) {
								&translate($reply, $engine, $translateData, $client_sock, $product, $getScore) unless $engine eq "n/a";
							}
						} else {
							print $client_sock encode("utf-8", " No engines available for $srcLang => $trgLang MT!\n");
						}
					}
				}
			}
			
			if (%$jobQueue) {
				while (my $job = shift @{$jobQueue->{restart}}) {
					push @{$jobQueue->{stop}}, $job;
					push @{$jobQueue->{start}}, $job;
				}
				
				my $prevTask = defined $jobQueue->{stop};
				my $stoppedServers = [];
				if ($prevTask) {
					push @$stoppedServers, @{&stop(@$_)} foreach @{$jobQueue->{stop}};
				}
				
				if ($prevTask && @$stoppedServers && defined $jobQueue->{start}) {
					print $client_sock encode("utf-8", "Waiting 55sec for server port".(@{$jobQueue->{stop}} > 1 ? "s" : "")." to be freed…");
					sleep 55;
					print $client_sock encode("utf-8", " done!\n");
				}
				
				$prevTask = defined $jobQueue->{start};
				foreach my $job (@{$jobQueue->{start}}) {
					my $startedServers = &start(@$job);
					my $newReply = eval $job->[0];
					$newReply = "{sourceLanguage => \"$newReply->{sourceLanguage}\", targetLanguage => \"$newReply->{targetLanguage}\", port => $newReply->{port}, ";
					my @srvs = map {"\"$_\""} @{$startedServers};
					if (@srvs) {
						$newReply .= "server => [@srvs]}\n";
						$job->[0] = $newReply;
						push @{$jobQueue->{check}}, $job;
					}
				}

				if ($prevTask) {
					if (defined $jobQueue->{check} && @{$jobQueue->{check}}) {
						print $client_sock encode("utf-8", "Waiting ${wait}sec for engine".(@{$jobQueue->{check}} > 1 ? "s" : "")." to load…");
						sleep $wait;
						print $client_sock encode("utf-8", " done!\n");
					} else {
						print $client_sock encode("utf-8", "All requested engines already running!\n");
					}
				}
				
				&check(15, @$_) foreach @{$jobQueue->{check}};
			}
			
			last if $translate;
		}
	}
	$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
	print LOG encode("utf-8", "closed $tstamp.\n");
	print STDERR encode("utf-8", "Closed connection to ".$client_socket->peerhost().":".$client_socket->peerport()." $tstamp.\n") if $DEBUG;
	$client_socket->shutdown(2);
	$client_socket->close();
	
	
	if ($finished) {
		$server_sock->shutdown(2);
		$server_sock->close();

		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print STDERR encode("utf-8", "Stopped MT Info Service on $hostname:$hostport at $tstamp\n");
		print LOG encode("utf-8", "Stopped MT Info Service on $hostname:$hostport at $tstamp\n");

		close LOG;
		
		exit 0;
	} elsif ($restartService) {
		$server_sock->shutdown(2);
		$server_sock->close();
		
		$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
		print STDERR encode("utf-8", "Stopped MT Info Service on $hostname:$hostport at $tstamp\n");
		print LOG encode("utf-8", "Stopped MT Info Service on $hostname:$hostport at $tstamp\n");
		
		close LOG;
		
		($hostport) = $hostport =~ /^(\d+)$/;
		for (;;) {
			exec "/local/cms/bin/mt_info_server.pl -hostname=$hostname -hostport=$hostport -sleep -DEBUG 2>>/local/cms/nohup.out"
			or print STDERR encode("utf-8", "Could not restart service! Retrying…\n");
		}
	}
	
	exit 0 unless $pid;
}


sub check {
	my ($timeOut, $data, $client_sock, $engine, $collectStats) = @_;
	$timeOut ||= 1;
	$data = eval $data;
	
	my $engineStats :shared = shared_clone {lines => 0, words => 0, connections => 0, restarts => 0};
	my $liveServers :shared = shared_clone [];

	my $serverCheck = sub {
		my $server = shift;
		my $error = 0;
		my $select = IO::Select->new();
		my $SOCK = new IO::Socket::INET (PeerHost => "$server", PeerPort => $data->{port}, Timeout => $timeOut) or $error = 1;
		if ($SOCK && !$error) {
			$select->add($SOCK);
			($SOCK) = $select->can_write($timeOut);
			unless ($SOCK) {
				($SOCK) = $select->handles();
				close $SOCK;
				$error = 1;
			}
		}
		unless ($error) {
			print $SOCK encode "utf-8", "$checkupToken\n";
			($SOCK) = $select->can_read($timeOut);
			unless ($SOCK) {
				($SOCK) = $select->handles();
				close $SOCK;
				$error = 1;
			}
		}
		unless ($error) {
			my $result = <$SOCK>;
			close $SOCK;
			if ($result) {
				chomp $result;
				$result = decode "utf-8", $result;
				$result =~ s/ //g;
				#The next line strips the Moses score from the result, in case it is there.
				$result =~ s/-?\d+.*?$//;
			}
			$error = (($result && $result eq $checkupToken) ? 0 : 1);
		}
		print $client_sock encode("utf-8", "Engine $engine ".($error ? "NOT " : "    ")."running on $server:$data->{port}.\n") if defined $client_sock;
		unless ($error) {
			lock $liveServers;
			push @$liveServers, $server;
		}
		
		if ($collectStats && $engine ne "n/a") {
			my $eng = $engine;
			$eng =~ s/PT-PT/PT-BR/;
			my $statistics = `ssh $server '/local/cms/bin/countMosesWords.pl -logDir=/local/cms/LOG -filterEngine=$eng' 2>/dev/null`;
			($statistics) = $statistics =~ /(^\{\s*(\w+\s*=>\s*"?[\w?-]+"?,?\s*)*\s*\}$)/;
			if ($statistics) {
				$statistics = eval $statistics;
				{ lock $engineStats;
					$engineStats->{$_} += $statistics->{$_} foreach keys %{$engineStats};
				}
			}
		}
	};

	my @threads = map { scalar threads->create($serverCheck, $_) } @{$data->{server}};
	$_->join() foreach @threads;
	
	print $client_sock encode("utf-8", "{engine => \"$engine\", lines => $engineStats->{lines}, words => $engineStats->{words}, connections => $engineStats->{connections}, restarts => $engineStats->{restarts}}\n") if defined $client_sock && $collectStats && $engine ne "n/a";
	
	$liveServers;
}

sub stop {
	my ($data, $client_sock, $engine) = @_;
	$data = eval $data;
	
	my $stoppedServers = [];
	foreach my $server (@{$data->{server}}) {
		print $client_sock encode("utf-8", "Stopping engine $engine on $server:$data->{port}… ");
		my $error = 0;
		my $SOCK = new IO::Socket::INET (PeerHost => "$server", PeerPort => $data->{port}, Timeout => 15) or $error = 1;
		if ($error) {
			print $client_sock encode("utf-8", "Engine $engine WAS NOT running on $server:$data->{port}!!!\n");
			next;
		} else {
			print $SOCK encode("utf-8", "$stopToken\n");
			my $select = IO::Select->new();
			$select->add($SOCK);
			($SOCK) = $select->can_read(30);
			unless ($SOCK) {
				($SOCK) = $select->handles();
				print $client_sock encode("utf-8", "No reply received from $server:$data->{port}!!! ");
				$error = 1;
			} else {
				my $result = <$SOCK>;
#				print STDERR encode "utf-8", "Received the following reply to ‘stop’ command: $result";
				$error = !($result && $result =~ /^Command acknowledged from/);
			}
			close $SOCK;
		}
		print $client_sock encode("utf-8", ($error ? "Could not stop $engine on $server:$data->{port}!!!\n" : "stopped.\n"));
		push @$stoppedServers, $server unless $error;
	}
	
	$stoppedServers;
}

sub start {
	my ($data, $client_sock, $engine) = @_;
	my %liveServers = map {$_ => 1} @{&check(60, $data, undef, $engine)};
	$data = eval $data;
	
	#Temporary measure to handle EN to PT-PT translation using PT-BR engines.
	$engine =~ s/PT_PT/PT_BR/;
	#Temporary measure until the EN–EN_GB engine is deployed with a proper name.
	$engine =~ s/EN_GB/EN_UK/;
	
	my $startedServers = [];
	foreach my $server (@{$data->{server}}) {
		if ($liveServers{$server}) {
			print $client_sock encode("utf-8", "Engine $engine already running on $server:$data->{port}!!!\n");
		} else {
			print $client_sock encode("utf-8", "Starting engine $engine on $server:$data->{port}… ");
			my $result = system("ssh -n $server \"cd /local/cms; nohup moses_server.ventzi.pl -engine=$engine -hostport=$data->{port} >>nohup.out 2>\&1 \&\" 2>/dev/null");
			if ($result == 0 || $result == -1) {
				print $client_sock encode("utf-8", "done!\n");
				push @$startedServers, $server;
			} else {
				print $client_sock encode("utf-8", "Failed to start engine $engine on $server:$data->{port}!!!\n");
			}
		}
	}
	
	$startedServers;
}

sub findMTServers {
	my ($confText, $engine, $client_sock, $ID) = @_;
	# Loop until at least one available server is found.
	my %temp;
	my $retryCount = 0;
	for (;;) {
		%temp = map {$_ => 1} @{&check(1, $confText, undef, $engine)};
		if (%temp || ++$retryCount > 20) {
			last;
		} else {
			print STDERR encode("utf-8", "$ID: "."All servers busy; retrying (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
			sleep(2);
		}
	}
	if (%temp) {
		return %temp;
	} else {
		print STDERR encode("utf-8", "$ID: "."Retry limit reached. Closing down (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
		return ();
	}
}

sub translate {
	my ($confText, $engine, $input, $client_sock, $product, $getScore) = @_;
	# For debug and logging purposes. Pick a random ID to assign to this translation session and use it throughout when printing out debug messages.
	my $ID = floor rand(99999);
	$ID = "0".$ID while length $ID < 5;
	
	my $config = eval $confText;

	# Check for matching URLs
	&matchURLs($config->{targetLanguage}, $input);
	# Check for matching glossary terms
	&matchGlossary($config->{targetLanguage}, $product, $input) if $product;
	# Check for UIRefs that can be pretranslated
	&translateUIRefs($config->{targetLanguage}, $product, $input) if $product;
	
	my %temp = &findMTServers($confText, $engine, $client_sock, $ID);
	unless (%temp) {
		print $client_sock encode "utf-8", " No servers available to process task! Please retry later…\n";
		return;
	}
	my $liveServers :shared = shared_clone \%temp;
	
	print $client_sock "{engine => \"$engine\", translate => ".(scalar @$input)."}\n";
	
	# Calculate the optimum job size based on the number of available servers and the number of available segments
	my $jobSize = ceil(@$input / (keys %$liveServers));
	$jobSize = 25 if $jobSize > 25;
	$jobSize = min(scalar @$input, 5) if $jobSize < 5;
	print STDERR encode("utf-8", "$ID: "."Job size set to $jobSize; translating using $engine (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
	
	# Distribute the available segments into jobs of size $jobSize
	my $jobs :shared = shared_clone { map {$_ => [@{$input}[($_ * $jobSize)..min(($_+1) * $jobSize-1, $#{$input})]]} (0..(floor(@$input / $jobSize) - (@$input % $jobSize == 0))) };
	print STDERR encode("utf-8", "$ID: ".(scalar keys %$jobs)." jobs set up for processing ".(scalar @$input)." segments on ".(scalar keys %$liveServers)." servers…\n") if $DEBUG;

	my $lastDoneJob :shared = -1;
	my $output :shared = shared_clone {};
	my $jobQueue = Thread::Queue->new();
	my $usedIDs :shared = shared_clone {};
	
	my $lostClient :shared = 0;
	local $SIG{PIPE} = sub {lock $lostClient; $lostClient = 1; print STDERR encode("utf-8", "$ID: "."SIGPIPE caught: Client (".$client_sock->peerhost().":".$client_sock->peerport().") lost while processing with engine $engine!\n"); $SIG{PIPE} = sub {}};

	my $translate = sub {
		my ($host, $port) = @_;
		my $mustExit = 0;
		print STDERR encode("utf-8", "$ID: "."Started a process for handling server $host with engine $engine!\n") if $DEBUG;
		
		for (;;) {
			{ lock $lostClient;
				if ($lostClient) {
					print STDERR encode("utf-8", "$ID: "."Client (".$client_sock->peerhost().":".$client_sock->peerport().") lost while processing on server $host with engine $engine!\n") if $DEBUG;
					$mustExit = 1;
				}
			}
			return if $mustExit;
			my $job;
			{ lock $jobQueue;
				if ($jobQueue->pending()) {
					print STDERR encode("utf-8", "$ID: ".$jobQueue->pending()." jobs left in queue…\n") if $DEBUG;
					$job = $jobQueue->dequeue();
				}
			}
			last unless $job;
			my $dataRef;
			($job, $dataRef) = %$job;
			print STDERR encode("utf-8", "$ID: "."Processing job $job on server $host (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
			
			{ lock $output;
				$output->{$job} = shared_clone [[], 0];
			}

			my $mosesError = my $errorCounter = 0;
			for (;;) {
				{ lock $lostClient;
					if ($lostClient) {
						print STDERR encode("utf-8", "$ID: "."Client (".$client_sock->peerhost().":".$client_sock->peerport().") lost while processing on server $host with engine $engine!\n") if $DEBUG;
						$mustExit = 1;
					}
				}
				return if $mustExit;
				my $mosesSocket;
				unless ($mosesSocket = new IO::Socket::INET (PeerHost => "$host", PeerPort => $port)) {
					print STDERR encode "utf-8", "$ID: "."Cannot connect to $host:$port!\n" if $DEBUG;
					$mosesError = 1;
					$errorCounter = $MAX_ERRORS;
				}
				
				unless ($mosesError) {
					unless ($mosesSocket->peerhost()) {
						print STDERR encode "utf-8", "$ID: "."Host $host:$port apparently busy!\n" if $DEBUG;
						$mosesError = 1;
					} else {
						$mosesSocket->autoflush(1);
						my $select = IO::Select->new();
						$select->add($mosesSocket);
#						print STDERR encode "utf-8", "$ID: "."Started sending segments to $host:$port…\n" if $DEBUG;
						
						foreach my $segment (@$dataRef) {
							($mosesSocket) = $select->can_write(1);
							unless ($mosesSocket) {
								print STDERR encode "utf-8", "$ID: "."Write timeout to $host:$port!\n" if $DEBUG;
								$mosesError = 1;
								last;
							}
							print $mosesSocket encode "utf-8", "$segment\n";
							
							($mosesSocket) = $select->can_read(60);
							unless ($mosesSocket) {
								print STDERR encode "utf-8", "$ID: "."Read timeout from $host:$port!\n" if $DEBUG;
								$mosesError = 1;
								last;
							}
							my $out = decode "utf-8", scalar <$mosesSocket>;
							unless (defined $out) {
								print STDERR encode "utf-8", "$ID: "."Couldn’t read a segment from $host:$port!\n" if $DEBUG;
								$mosesError = 1;
								last;
							}
							#If a client can accept the Moses score returned with each segment, this should be indicated by setting the ‘getScore’ parameter to true.
							$out =~ s/-?\d+.*$// unless $getScore;
							
							{ lock $output;
								push @{$output->{$job}->[0]}, shared_clone $out;
							}
						}
						
						if (($mosesSocket) = $select->handles()) {
							print STDERR encode "utf-8", "$ID: "."Closing connection to $host:$port!\n" if $DEBUG;
							$mosesSocket->shutdown(2);
							$mosesSocket->close();
							$select->remove($mosesSocket);
						}
					}
				}

				if ($mosesError) {
					{ lock $output;
						$output->{$job}->[0] = shared_clone [];
					}
					if ($errorCounter < $MAX_ERRORS) {
						$mosesError = 0;
						++$errorCounter;
						print STDERR encode("utf-8", "$ID: "."--> Error №$errorCounter for job $job on server $host…\n") if $DEBUG;
						sleep 1;
						next;
					} else {
						$jobQueue->insert(0, {$job => $dataRef});
						{ lock $liveServers;
							delete $liveServers->{$host};
						}
						last;
					}
				} else {
					print STDERR encode("utf-8", "$ID: "."--> No errors for job $job on server $host…\n") if $DEBUG;
					last;
				}
			}
			print STDERR encode("utf-8", "$ID: "."--> ERRORS for job $job on server $host…\n") if $DEBUG && $mosesError;
			last if $mosesError;
			{ lock $lostClient;
				if ($lostClient) {
					print STDERR encode("utf-8", "$ID: "."Client (".$client_sock->peerhost().":".$client_sock->peerport().") lost while processing on server $host with engine $engine!\n") if $DEBUG;
					$mustExit = 1;
				}
			}
			return if $mustExit;
			
			{ lock $lastDoneJob; lock $output;
				$output->{$job}->[1] = 1;
				
				my $toPrint = "";
				while ($lastDoneJob < (keys %$output) - 1 && defined $output->{$lastDoneJob + 1} && $output->{$lastDoneJob + 1}->[1]) {
					++$lastDoneJob;
					print STDERR encode("utf-8", "$ID: "."--> Printing job $lastDoneJob… (".$client_sock->peerhost().":".$client_sock->peerport().")\n") if $DEBUG;
					foreach my $segment (@{$output->{$lastDoneJob}->[0]}) {
						$toPrint .= $segment;
					}
				}
				if ($toPrint ne "") {
					my $select = IO::Select->new();
					$select->add($client_sock);
					my ($local_socket) = $select->can_write(5);
					unless ($local_socket) {
						lock $lostClient;
						$lostClient = $mustExit = 1;
						print STDERR encode("utf-8", "$ID: "."WRITE TIMEOUT: Client (".$client_sock->peerhost().":".$client_sock->peerport().") lost while processing on server $host with engine $engine!\n") if $DEBUG;
					}
					print $local_socket encode("utf-8", $toPrint) unless $mustExit;
				}
			}
			return if $mustExit;
		}

		print STDERR encode("utf-8", "$ID: "."Finished processing on server $host with engine $engine (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
		return;
	};
	
	# Enqueue the jobs in advance
	print STDERR encode("utf-8", "$ID: "."Enqueueing work…\n") if $DEBUG;
	$jobQueue->enqueue({$_ => $jobs->{$_}}) foreach sort {$a <=> $b} keys %$jobs;
	
	# Execution loop—in case some servers that we thought were available fail to complete their jobs in time.
	while ($jobQueue->pending()) {
		print STDERR encode("utf-8", "$ID: "."Creating MT threads (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
		my @threads = map { scalar threads->create($translate, $_, $config->{port}) } shuffle keys %$liveServers;
	
		$_->join() foreach @threads;

		if ($lostClient) {
			print STDERR encode("utf-8", "$ID: "."ERROR: Client (".$client_sock->peerhost().":".$client_sock->peerport().") lost while translating with engine $engine!\n") if $DEBUG;
			return;
		}

		print STDERR encode("utf-8", "$ID: "."--> ".(scalar keys %$liveServers)." servers left (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
		# We can only have ran out of live servers if there were server issues. In this case, we must still have pending jobs in the queue, so we need to look for live servers again.
		unless (%$liveServers) {
			print STDERR encode("utf-8", "$ID: "."Had errors on all servers. Trying to find new servers (".$client_sock->peerhost().":".$client_sock->peerport().")…\n") if $DEBUG;
			%temp = &findMTServers($confText, $engine, $client_sock, $ID);
			unless (%temp) {
				print $client_sock encode "utf-8", " No servers available to finish processing task! Please retry later…\n";
				return;
			}
			$liveServers = shared_clone \%temp;
		}
	
	}
		# We should not have leftover jobs.
#		print STDERR encode("utf-8", "$ID: "."Checking for leftover jobs…\n") if $DEBUG;
#		foreach my $job (($lastDoneJob + 1)..((keys %$output) - 1)) {
#			unless (defined $output->{$job} && $output->{$job}->[1]) {
#				print STDERR encode("utf-8", "$ID: "."--> Could not print job $job…\n") if $DEBUG;
#				print $client_sock encode("utf-8", "$ID: "." Could not process MT job! MT server error. Please contact ventsislav.zhechev\@autodesk.com and try again later! \n");
#				last;
#			}
#		}
}


sub matchGlossary {
	my ($targetLanguage, $product, $data) = @_;
	
	$product = $products{$product} if defined $products{$product};
	$product = $products{$product} if defined $products{$product};
	#	print STDERR encode "utf-8", "Matching glossary for product $product and language $targetLanguage…\n";

	my $www = LWP::UserAgent->new;
	$www->agent("MT Info Service");

	my $onlineTerms = {};
	my ($glossary) = $product =~ /^(.*)_gloss/;
	if ($glossary) {
		my $request = HTTP::Request->new(GET => 'http://ec2-50-16-68-84.compute-1.amazonaws.com/TermList.perl?language='.uri_escape($targetLanguage).'&glossary='.uri_escape($glossary));
		my $result = $www->request($request);
		if ($result->is_success) {
			my $content = decode "utf-8", $result->content;
			($content) = $content =~ m!({(?:\".*\",)?})!s;
			$onlineTerms = eval $content;
		}
	}
	
	return unless (defined $glossary{$product} && defined $glossary{$product}->{languages}->{$targetLanguage}) || %$onlineTerms;
	
	foreach my $term (@{$glossary{$product}->{terms}}) {
		next unless defined $term->{$targetLanguage};
		#		print STDERR encode "utf-8", "Trying out term “".$term->{term}."”…\n";
		for (my $id = 0; $id < @$data; ++$id) {
			my $tempData = lc $data->[$id];
			if ($tempData =~ /(?:^|\P{IsAlNum})(?<!\p{IsAlNum}[\-_])\Q$term->{term}\E(?:e?s)?(?![\-_]\p{IsAlNum})(?:\P{IsAlNum}|$)/) {
				#				print STDERR encode "utf-8", "…term found in line “".$data->[$id]."”\n";
				$data->[$id] =~ s/$/$term->{term}$term->{$targetLanguage}/;
			}
		}
	}
	foreach my $term (keys %$onlineTerms) {
		#		print STDERR encode "utf-8", "Trying out term “".$term."”…\n";
		for (my $id = 0; $id < @$data; ++$id) {
			my $tempData = lc $data->[$id];
			if ($tempData =~ /(?:^|\P{IsAlNum})(?<!\p{IsAlNum}[\-_])\Q$term\E(?:e?s)?(?![\-_]\p{IsAlNum})(?:\P{IsAlNum}|$)/) {
				#				print STDERR encode "utf-8", "…term found in line “".$data->[$id]."”\n";
				$data->[$id] =~ s/$/$term$onlineTerms->{$term}/;
			}
		}
	}
}


sub translateUIRefs {
	my ($targetLanguage, $product, $data) = @_;
	
	my %languageMap = (
	cs => "csy",
	de => "deu",
	es => "esp",
	fr => "fra",
	hu => "hun",
	it => "ita",
	jp => "jpn",
	ko => "kor",
	pl => "plk",
	pt_br => "ptb",
	ru => "rus",
	zh_hans => "chs",
	zh_hant => "cht",
	);
	
	return unless defined ($targetLanguage = $languageMap{$targetLanguage});
	
#	$product = $products{$product} if defined $products{$product};
#	$product = $products{$product} if defined $products{$product};
	
	my $www = LWP::UserAgent->new;
	$www->agent("MT Info Service");

	for (my $id = 0; $id < @$data; ++$id) {
		my %UIRefs;
		$data->[$id] =~ s§<uiref>(.*?)</uiref>§§
			my $UIRef = $1;
			if (!defined $UIRefs{$UIRef}) {
				my $request = HTTP::Request->new(GET => 'http://ec2-50-19-197-134.compute-1.amazonaws.com:8983/solr/lclookup?q1='.uri_escape(lc $UIRef).'&product='.$product.'&resource=Software&lang='.$targetLanguage);
				my $result = $www->request($request);
				if ($result->is_success) {
					my $content = decode "utf-8", $result->content;
					($content) = $content =~ m!<result name="response".*?<doc>.*?<str name="$targetLanguage">(.*?)</str>.*?</result>!s;
					$UIRefs{$UIRef} = $content;
				} else {
					$UIRefs{$UIRef} = "";
				}
			}
		$UIRefs{$UIRef} eq "" ? $UIRef : "<uiref translation=\"$UIRefs{$UIRef}\">$UIRef</uiref>";
		§gxe;
	}
}


sub matchURLs {
	my ($targetLanguage, $data) = @_;
	local $" = "";
	
	for (my $id = 0; $id < @$data; ++$id) {
		next unless $data->[$id] =~ m!\.\p{IsAlnum}+/! || $data->[$id] =~ m!:/! || $data->[$id] =~ m!@(?=\p{IsAlnum}+\.)! || $data->[$id] =~ /(?:^|\W)\p{IsAlnum}+\.[\p{IsAlnum}\.]+\.\p{IsAlpha}+(?=\W|$)/;
		
		my @urls;
		$data->[$id] =~ s/(^|[\s◊}]+)([\p{IsAlnum}(\[<\\\/])((?:[^ \\\/{]++[\\\/]++)+[^ \\\/{]*)(?!\{)([*\$\p{IsAlnum}>)\/\\>\]])(?=[\p{Punctuation}\s{◊]+|$)/
			my ($fs, $b, $d, $e) = ($1, $2, $3, $4);
			if ($b eq "(") {
				$b = "◊(◊ ";
			} else {
				$d="$b$d";
				$b="";
			}
			if ($e eq ")") {
				$e = " ◊)◊";
			} else {
				$d="$d$e";
				$e="";
			}
			push @urls, $d if $d =~ m![:\.]!;
			$d = "$b$d$e";
			$d =~ s!([._\/\\:*+?=<>\[\](){}-])!◊$1◊!g if $d =~ m![\\\/]!;
			
			"$fs$d"
			/ge;
			
		$data->[$id] =~ s/(^|\W)(\p{IsAlnum}+\.[\p{IsAlnum}\.]+\.\p{IsAlpha}{2,3})(?=\W|$)/push @urls, $2; "$1◊$2◊"/ge;
		$data->[$id] =~ s/(^|\W)(\p{IsAlnum}+[\p{IsAlnum}\.]+\@[\p{IsAlnum}\.]+\.\p{IsAlpha}+)(?=\W|$)/push @urls, $2; "$1◊$2◊"/ge;
			
		@urls = %{{map {$_ => $urls{$_}->{$targetLanguage}} grep {defined $urls{$_}->{$targetLanguage}} @urls}};
		$data->[$id] =~ s/◊//g;
		$data->[$id] =~ s/\n$/@urls\n/ if @urls;
	}
}


1;
