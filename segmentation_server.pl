#!/usr/local/bin/perl -wTs
#
# file: segmentation_server.pl
#
# ©2012 Autodesk Development Sàrl
#
# Based on moses_server.ventzi.pl
# Created on 15 May 2012
#
# This script starts a segmentation service to run in the background.
# It binds itself to listen on some port, then spawns the segmentation process. When it gets a connection, it is read line by line, the lines are fed to the segmenter and the output is written to the port.
#
#
# Last modified on 25 Sep 2012 by Ventsislav Zhechev
#
# ChangeLog
# v2.0
# Now based off improved moses_server script.
#
# v1.0
# Initial version
# 
###########################################

use strict;

use utf8;

use Encode qw/encode decode/;
use IO::Socket::INET;
use IO::Select;
use Sys::Hostname;
use IPC::Open2;
use POSIX qw/strftime/;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
$ENV{PATH} = "/usr/bin:/usr/local/bin:/local/cms/bin:/local/cms/moses/mosesdecoder/moses-cmd/src:/local/cms/bin/opennlp/bin";

$| = 1;
select STDERR;
$| = 1;


our ($srclang, $hostname, $hostport, $base_dir, $perl_path, $VENTZI);
die encode "utf-8", "Usage: $0 -srclang=… [-hostname=…] -hostport=… [-base_dir=…] [-perl_path=…]\n"
unless defined $srclang && defined $hostport;

($srclang) = $srclang =~ /^(\w\w(?:(-|_)\w{2,4})?)$/;
die encode("utf-8", "No segmenter available for the requested language!\n") unless defined $srclang;

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

my $tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
my $logFileName = "${base_dir}LOG/${srclang}_segmenter_script_$tstamp.log";
open LOG, ">$logFileName"
or die encode "utf-8", "Cannot write to file $logFileName\n";
print STDERR encode "utf-8", "Logging segmenter for $srclang to $logFileName\n";
select LOG;
$| = 1;
print LOG encode "utf-8", "$tstamp: Starting segmenter for $srclang on $hostname:$hostport\n";

my $segment = $srclang =~ /^jp|^zh/ ? ["${perl_path}perl", '-s', "${base_dir}bin/word_segmenter.pl", '-segmenter=kytea', "-model=${base_dir}share/kytea/".($srclang =~ /^jp/ ? 'jp-0.3.0-utf8-1.mod' : 'lcmc-0.3.0-1.mod')] : "";


# spawn segmenter
my ($pre_in, $pre_out);
my $pid_preprocess = open2($pre_out, $pre_in, @$segment)
or die encode "utf-8", "Could not start segmenter with command “$segment”\n";
select $pre_in;
$| = 1;

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
				print $client_sock encode("utf-8", &checkPH($src, "### Non MT-Translatable: UTF-8 error ###")."\n");
				print STDERR encode("utf-8", $server_sock->sockhost.":".$server_sock->sockport.": Got UTF-8 error from ".$clientHost.":".$clientPort." ($@) $tstamp.\n");
				next;
			}
			
			if ($src =~ /÷◊÷/) {
				$tstamp = strftime("%Y.%m.%d_%H.%M.%S", localtime(time()));
				print $client_sock encode("utf-8", "Command acknowledged from ".$clientHost.":".$clientPort.". Stopping segmenter for $srclang on $tstamp…\n");
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
			
			print $pre_in encode "utf-8", "$src\n";
			$src = decode "utf-8", scalar <$pre_out>;
			chomp $src;
				
			$wc += () = split ' ', $src, -1;
					
			print $client_sock encode("utf-8", "$src\n");
			
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


print LOG encode "utf-8", "Stopped segmenter for $srclang on $tstamp\n";
print STDERR encode "utf-8", "Stopped segmenter for $srclang on $tstamp. Logged output to $logFileName\n";


close LOG;
close $pre_in;
close $pre_out;

kill("KILL", $pid_preprocess);



1;
