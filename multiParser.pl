#!/usr/bin/perl -ws
#
# multiParser.pl
# A simple taskfarming utility wrapper for single-threaded parsers
#
# ©2011–2015 Autodesk Development Sàrl
#
# ChangeLog
# v2.1.3		Last modified by Ventsislav Zhechev on 22 Jan 2015
# Staggered the start of the parser threads to avoid STDERR congestion.
# Added status messages.
#
# v2.1.2		Last modified by Ventsislav Zhechev on 08 May 2013
# Empty strings are no longer sent to the parser.
# Removed unnecessary checks for jobs availability in the Thread::Queue, thus significantly reducing CPU utilisation.
#
# v2.1.1		Last modified by Ventsislav Zhechev on 24 Jan 2013
# Made sure that STDOUT and STDERR are unbuffered.
#
# v2.1			Last modified by Ventsislav Zhechev on 07 May 2012
# Added an option to output the sequential ID of the segement being output.
#
# v2.0.2
# Changed the flow control in the parse subroutine.
#
# v2.0.1
# Added an extra zero to the queue the make extra sure that we exit when we’re done parsing.
#
# v2.0
# Switched to using Thread::Queue for simplified job distribution.
#
# v1.0
# Initial version
#
#####################

use strict;

use IPC::Open2;
#use Time::HiRes qw/nanosleep/;

use threads;
use threads::shared;
use Thread::Queue;

our ($input, $output, $parser_cmd, $threads, $useID);
die "Usage: $0 -parser_cmd=\"…\" [-input=…] [-output=…] [-threads=…] [-useID]\n" unless defined $parser_cmd;

$threads ||= 2;
$input ||= '-';
$output ||= '-';

if ($input ne '-') {
	close STDIN;
	open (STDIN, "<$input")
	or die "Cannot read file $input\n";
}
if ($output ne '-') {
	close STDOUT;
	open (STDOUT, ">$output")
	or die "Cannot write to file $output\n";
}

$| = 1;
select STDERR;
$| = 1;

my $jobQueue = Thread::Queue->new();

my %outputCache :shared = ();
my $lastOutput :shared = 0;
my @threads;

sub outputOrCache {
	my $sentID = shift;
	my $output = shift;
	
	lock %outputCache;
	
	unless ($sentID == $lastOutput+1) {
		$outputCache{$sentID} = $output;
		return;
	}
	
	print STDOUT ($useID ? "$sentID\t" : "").$output;
	++$lastOutput;
	#DEBUG
#	print STDERR "ID$lastOutput\n";
	#DEBUG
	while (defined $outputCache{$lastOutput+1}) {
		++$lastOutput;
		print STDOUT ($useID ? "$lastOutput\t" : "").$outputCache{$lastOutput};
		#DEBUG
#		print STDERR "id$lastOutput\n";
		#DEBUG
		undef $outputCache{$lastOutput};
	}
}

my $parse = sub {
	my $id = shift;
	sleep $id*2-1;
	
	$parser_cmd =~ s/\.log/.$id.log/;
	local (*PARSE_IN, *PARSE_OUT);
	my $parse_pid = open2(\*PARSE_OUT, \*PARSE_IN, $parser_cmd)
	or die "Could not start parser with command “$parser_cmd”!\n";

	print STDERR "In thread $id: Started parser with command “$parser_cmd”!\n";
	
	select PARSE_IN;
	$| = 1;
	select PARSE_OUT;
	$| = 1;
	
	for (;;) {
		my $pendingJobs = $jobQueue->pending();
		if ($pendingJobs) {
			print STDERR "In thread $id: $pendingJobs jobs pending for parsing!\n" unless $pendingJobs % 10000;
		}
		my $job = $jobQueue->dequeue();
		if ($job == 0) {
			print STDERR "Thread $id: Got end-of-work signal. Killing parser…\n";
			close PARSE_IN;
			close PARSE_OUT;
			kill "KILL", $parse_pid;
			
			return;
		} else {
			if ($job->[1] =~ /^\s*$/) {
				&outputOrCache(@$job);
			} else {
				print PARSE_IN $job->[1];
				&outputOrCache($job->[0], scalar(<PARSE_OUT>));
			}
		}
		
	}
};


print STDERR "Starting $threads threads for parsing…\n";
push @threads, threads->create($parse, $_) foreach (1..$threads);

my $counter = 0;
while (<STDIN>) {
	unless ($. % 10000) {
		print STDERR "…";
		print STDERR "[multiparse in: $.]" unless $. % 500000;
	}
	$jobQueue->enqueue([++$counter => $_]);
}

print STDERR "All data ingested ($counter).\nSending end-of-work signal to parser threads…\n";
$jobQueue->enqueue(0) foreach (0..$threads);
$_->join() foreach @threads;

close STDIN;
close STDOUT;


1;