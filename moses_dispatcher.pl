#!/local/build/myperl/bin/perl -wT
#
# Originally developed by François Masselot and/or Mirko Plitt
# ©2011 Autodesk Development Sàrl
# Last modified on 04 Nov 2011 by Ventsislav Zhechev
#
# ChangeLog
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

use threads;
use threads::shared;

use Encode qw/encode decode/;
use IO::Socket::INET;
use POSIX qw/floor/;
use List::Util qw/min/;
#use Storable qw/dclone/;

$| = 1;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
$ENV{PATH} = "";

die "Usage: $0 <targetLocale> <sourceFileName>\n" unless @ARGV == 2;

my %localeMap = (
									Czech									=> "cs",
									German								=> "de",
									Spanish								=> "es",
									French								=> "fr",
									Hungarian							=> "hu",
									Italian								=> "it",
									Japanese							=> "jp",
									Korean								=> "ko",
									Polish								=> "pl",
									Brazilian_Portuguese	=> "pt_br",
									Russian								=> "ru",
									Turkish								=> "tr",
									Simplified_Chinese		=> "zh_hans",
									Traditional_Chinese		=> "zh_hant",
								);


my ($targetLocale, $sName) = @ARGV;
$sName = $sName =~ m!^([/\w\.-]*ws_mt_[\w_]+.tmp)$! ? $1 : "";

#Get server specs from the MT Info Service
my $infoSocket = new IO::Socket::INET (PeerHost => "neucmslinux.autodesk.com", PeerPort => 2000)
or print("Cannot contact MT Info Service!\n") && die;
binmode $infoSocket, ":encoding(utf-8)";
print $infoSocket "{server => ?, port => ?, sourceLanguage => en, targetLanguage => $localeMap{$targetLocale}}\n";
my $data = <$infoSocket>;
unless ($data =~ /^\{\s*(?:\w+\s*=>\s*"?(?:[\w?"]+|\[(?:[\w"]+,?\s*)+\])"?,?\s*)*\}$/) {
	print $data =~ /not installed/ ? "Requested engine not installed!\n" : "Bad response from MT Info Service: “$data”\n" and die;
} else {
	($data) = $data =~ /(^\{\s*(?:\w+\s*=>\s*"?(?:[\w?"]+|\[(?:[\w"]+,?\s*)+\])"?,?\s*)*\s*\}$)/;
	$data = eval $data;
}

my @liveServers;
for (my $i = 0; $i < @{$data->{server}}; ++$i) {
	print $infoSocket "{operation => check, targetLanguage => $data->{targetLanguage}, server => $data->{server}->[$i]\n";
	push @liveServers, $data->{server}->[$i] unless (scalar <$infoSocket>) =~ /NOT/;
}

$infoSocket->shutdown(2);
$infoSocket->close();

print("No MT servers running for the requested language!\n") && die unless @liveServers;

open (STDOUT, ">$sName.out") or print("Cannot write file $sName.out: $!\n") && die;

#Read in source data
open (SRC, "<$sName") or print("Cannot read file $sName: $!\n") && die;
binmode SRC, ":encoding(utf-8)";
my @segments = <SRC>;
close (SRC);

return unless scalar @segments;

my $jobSize = floor(@segments / @liveServers) || 1;
$jobSize = 25 if $jobSize > 25 && @liveServers > 1;

my $jobs :shared = shared_clone{
																map {$_ => [@segments[($_ * $jobSize)..min(($_+1) * $jobSize-1, $#segments)]]}
																		(0..(floor(@segments / $jobSize) - (@segments % $jobSize == 0)))
																};

pop @liveServers while @liveServers > (keys %$jobs);

my $lastReadJob :shared = -1;
#my $lastDoneJob :shared = -1;
my $output :shared = shared_clone {};



# This sub will be run in parallel by the threads
my $thread_body = sub {
	my ($host, $port) = @_;
	
	my $finished = 0;
	for (;;) {
		my $job;
		{ lock $lastReadJob;
			$job = ++$lastReadJob;
		}
		
		my $dataRef;
		{ lock $jobs;
#			print encode_utf8("$host:$port => ".((keys %$jobs) - $job)." jobs left to process…\n");
			if ($job < keys %$jobs) {
				$dataRef = $jobs->{$job};
			} else {
				$finished = 1;
			}
		}
		last if $finished;

		{ lock $output;
			$output->{$job} = shared_clone [[], 0];
		}
#		print encode_utf8("$host:$port => found ".scalar(@$dataRef)." segments for translation in job $job\n");
		
#		print encode_utf8("Connecting to engine on $host:$port…\n");
		
		my $mosesSocket = new IO::Socket::INET (PeerHost => "$host.autodesk.com", PeerPort => $port)
		or print("Cannot connect to $host:$port!\n") && die;
		binmode $mosesSocket, ":encoding(utf-8)";
		
		foreach my $segment (@$dataRef) {
			print $mosesSocket $segment;
			my $out = <$mosesSocket>;
			{ lock $output;
				push @{$output->{$job}->[0]}, shared_clone $out;
			}
		}
		
#		{ lock $lastDoneJob; lock $output;
#			$output->{$job}->[1] = 1;
#			
#			while ($lastDoneJob < $lastReadJob && defined $output->{$lastDoneJob + 1} && $output->{$lastDoneJob + 1}->[1]) {
#				++$lastDoneJob;
#				my $counter = 0;
##				print encode_utf8("====> Outputting job $lastDoneJob…\n");
##				print encode_utf8($lastDoneJob.".".(++$counter).": ".$_) foreach @{$output->{$lastDoneJob}->[0]};
#				print STDOUT encode_utf8($_) foreach @{$output->{$lastDoneJob}->[0]};
#			}
#		}
		
		$mosesSocket->shutdown(2);
		$mosesSocket->close();
	}
};

# Start all threads and wait for them all to finish
#print encode_utf8("Creating threads…\n");
my @threads = map { scalar threads->create($thread_body, $_, $data->{port}) } @liveServers;

$_->join() foreach @threads;

foreach my $job (sort {$a <=> $b} keys %$output) {
	print STDOUT encode("utf-8", $_) foreach @{$output->{$job}->[0]};
}

close STDOUT;


1;