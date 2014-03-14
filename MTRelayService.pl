#!/usr/local/bin/perl -wTs
#
# ©2013 Autodesk Development Sàrl
# Created on 12 Jul 2013 by Ventsislav Zhechev
#
# ChangeLog
# v0.2			Modified on 24 Sep 2013 by Ventsislav Zhechev
# Improved end-of-communication-with-client handling.
#
# v0.1			Modified on 12 Jul 2013 by Ventsislav Zhechev
# Initial version.
#
####################

use strict;
use utf8;

use IO::Select;
use IO::Socket::INET;
use Sys::Hostname;

use threads;
use threads::shared;


$| = 1;

select STDERR;
$| = 1;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
$ENV{PATH} = "";


our ($hostname, $hostport);
if ($hostname) {
	($hostname) = $hostname =~ /^([\w.]+)$/;
} else {
	$hostname = &hostname();
#	$hostname = "translatemt";
}
$hostport ||= 3000;

my $stopToken = "÷◊÷";


# open server socket
my $server_sock = new IO::Socket::INET
(LocalAddr => $hostname, LocalPort => $hostport, Listen => 1)
or die "Cannot bind server socket on $hostname:$hostport\n";


while (my $client_socket = $server_sock->accept()) {
	my $pid = fork();
	next if $pid;
	$client_socket->autoflush(1);

	my $finished :shared = 0;
	
	my $mtInfoServiceSocket;
	unless ($mtInfoServiceSocket = new IO::Socket::INET (PeerHost => "10.35.136.43", PeerPort => 2001)) {
		print STDERR "Cannot connect to 10.35.136.43:2001!\n";
		last;
	}
#	unless ($mtInfoServiceSocket = new IO::Socket::INET (PeerHost => "ussclsdcmslnx01.autodesk.com", PeerPort => 2001)) {
#		print STDERR "Cannot connect to ussclsdcmslnx01.autodesk.com:2001!\n";
#		last;
#	}
	
	$mtInfoServiceSocket->autoflush(1);
	
	my $reader = sub {
		my $client_select = IO::Select->new();
		$client_select->add($client_socket);
		
		my $currentJob = 0;
		for (;;) {
			my ($client_sock) = $client_select->can_read(15);
			if (!defined $client_sock) {
				print STDERR "undefined \$client_sock\n";
				next;
			} elsif ($client_sock->eof()) {
				print STDERR "EOF reached\n";
				last;
			}
			
			my $cmd = <$client_sock>;
			next unless defined $cmd && $cmd;
			if ($cmd =~ /^$stopToken/) {
				lock $finished;
				$finished = 1;
				last;
			}
			
			print $mtInfoServiceSocket $cmd;
		}

		$mtInfoServiceSocket->shutdown(1);
	};
	my $writer = sub {
		
		for (;;) {
			my $out = <$mtInfoServiceSocket>;
			last if $mtInfoServiceSocket->eof();
			last unless defined $out;
			
			my $end = 0;
			{ lock $finished;
				$end = $finished;
			}
			last if $end;
			
			print $client_socket $out;
		}
		
		$mtInfoServiceSocket->shutdown(0);
		$mtInfoServiceSocket->close();
	};
	
	my @threads = map {threads->create($_)} ($reader, $writer);
	
	$_->join foreach @threads;
	
	$client_socket->shutdown(2);
	$client_socket->close();

	{ lock $finished;
		if ($finished) {
			$server_sock->shutdown(2);
			$server_sock->close();
		
			exit 0;
		}
	}
	
	exit 0 unless $pid;
}





1;