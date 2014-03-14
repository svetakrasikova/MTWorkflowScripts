#!/local/build/myperl/bin/perl -wT
#
# Originally developed by François Masselot and/or Mirko Plitt
# ©2011–2012 Autodesk Development Sàrl
# Last modified on 29 Mar 2012 by Ventsislav Zhechev
#
# ChangeLog
# v3.2
# Added a dead loop that makes sure that we got all strings back from the MT Info Server.
#
# v3.1.4
# Removed the KEEPALIVE sockoption, as it is not needed.
#
# v3.1.3
# Added a loop so that the dispatcher will try to connect to the service until it is available.
#
# v3.1.2
# All error messages are now only printed out to STDERR to avoid their propagation in WS.
#
# v3.1.1
# Turned on autoflush on the MT Info Service socket.
#
# v3.1
# Now we are closing the infoSocket and STDOUT properly before dying if we are unhappy with the response from the MT Info Service.
#
# v3
# Removed all translation-related code and switched to simply sending all data to the MT Info Service for handling.
#
# v2.2
# Switched to a stricter version of UTF-8 encoding
#
# v2.1
# If we have less jobs than servers, we’ll only leave as many servers in the list as needed.
# Adjusted job size for cases where we have less segments than servers.
#
# v2.0
# Now contacts the MT Info Service for server and port information for the requested targetLocale.
# The data to be processed is split into jobs of at most 25 segments.
# Connections to Moses servers are established individually for each job.
# The health of the servers is checked in advance to avoid allocating jobs to non-functioning servers.
#
############################

use strict;
use utf8;

use Encode qw/encode decode/;
use IO::Socket::INET;

$| = 1;
$" = "";

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
$ENV{PATH} = "";

die "Usage: $0 <targetLocale> <sourceFileName>\n" unless @ARGV == 2;


my ($targetLocale, $sName) = @ARGV;
$sName = $sName =~ m!^([/\w\.-]*ws_mt_[\w_]+.tmp)$! ? $1 : "";
$targetLocale =~ s/(?<=\w\w\w)_(?=\w)/ /g;

print STDERR (encode "utf-8", "Could not recognise file name!\n") && die unless $sName;

open (STDOUT, ">$sName.out") or print STDERR (encode "utf-8", "Cannot write file $sName.out: $!\n") && die;

#Read in source data
open (SRC, "<$sName") or print STDERR (encode "utf-8", "Cannot read file $sName: $!\n") && die;
#binmode SRC, ":encoding(utf-8)";
my @segments = map {chomp; decode "utf-8", $_} <SRC>;
close SRC;

unless (@segments) {
	close STDOUT;
	return;
}

for (;;) {
	#Connect to the MT Info Service
	my $infoSocket;
	while (!$infoSocket) {
		$infoSocket = new IO::Socket::INET (PeerHost => "neucmslinux.autodesk.com", PeerPort => 2000);
		sleep(60) unless $infoSocket;
	}
	#or print STDERR (encode "utf-8", "Cannot contact MT Info Service!\n") && die;
	$infoSocket->autoflush(1);
	#$infoSocket->sockopt(SO_KEEPALIVE, 1);

	print $infoSocket encode("utf-8", "{translate => ".(scalar @segments).", targetLanguage => $targetLocale}\n");
	print $infoSocket encode("utf-8", "$_\n") foreach @segments;
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

	my @outStrings = <$infoSocket>;
	$infoSocket->shutdown(0);
	$infoSocket->close();
	
	if ($#outStrings == $#segments) {
		print STDOUT @outStrings;
		last;
	} else {
		next;
	}
}

close STDOUT;


1;