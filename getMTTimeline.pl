#!/usr/bin/perl -ws
#
# ©2014 Autodesk Development Sàrl
# Created on 03 Oct 2014 by Ventsislav Zhechev
#
# ChangeLog
# v0.3		modified on 09 Oct 2014 by Ventsislav Zhechev
# Parametrised the log file name and event list file name.
# Now we can read bzip2-ed files.
# A list of sessions with metadata is output in the eventFile encoded in UTF-16LE with BOM.
#
# v0.2		modified on 07 Oct 2014 by Ventsislav Zhechev
# Now we also output statistics per source language/target language/product.
# Also aggregates/prints cumulative statistics per product and per source language/target language.
# Improved handling of language codes.
#
# v0.1		modified on 06 Oct 2014 by Ventsislav Zhechev
# Initial version
# Prints out statistics from the current nohup.out file per product/target language/source language.
#
###########################

use strict;
use utf8;
use Encode qw/encode decode/;
use Net::SFTP::Foreign;
use Net::SFTP::Foreign::Constants ':flags';
use DateTime::Format::Builder;
use DateTime::Format::Duration;

use IO::Compress::Bzip2;
use IO::Uncompress::Bunzip2 qw/bunzip2/;

my %localeMap = (
	czech												=> "cs",
	danish											=> "da",
	german											=> "de",
	english_uk									=> "en_gb",
	"english uk"								=> "en_gb",
	"english (united kingdom)"	=> "en_gb",
	spanish											=> "es",
	finnish											=> "fi",
	french											=> "fr",
	hungarian										=> "hu",
	italian											=> "it",
	japanese										=> "jp",
	korean											=> "ko",
	dutch_netherlands						=> "nl",
	"dutch netherlands"					=> "nl",
	"dutch (netherlands)"				=> "nl",
	norwegian										=> "no",
	"norwegian (bokmal)"				=> "no",
	polish											=> "pl",
	brazilian_portuguese				=> "pt_br",
	"brazilian portuguese"			=> "pt_br",
	"portuguese (brazil)"				=> "pt_br",
	portuguese									=> "pt_pt",
	"portuguese (portugal)"			=> "pt_pt",
	russian											=> "ru",
	swedish											=> "sv",
	turkish											=> "tr",
	vietnamese									=> "vi",
	simplified_chinese					=> "zh_hans",
	"simplified chinese"				=> "zh_hans",
	"chinese (prc)"							=> "zh_hans",
	traditional_chinese					=> "zh_hant",
	"traditional chinese"				=> "zh_hant",
	"chinese (taiwan)"					=> "zh_hant",
);

$| = 1;

our ($server, $file, $eventFile);
die encode "utf-8", "Usage: $0 -server=… -file=… -eventFile=…\n"
unless defined $server && defined $file && defined $eventFile;
my $dir = "/local/cms";

my %toCheck;
my %userData;
my %connectionStats;
my %translationStats;
my $currentUserID = 0;
my (%MTStatsSTP, %MTStatsTSP, %MTStatsPTS);
my %MTVolumeStats;
my ($startTime, $endTime);

open my $eventList, ">$eventFile"
or die encode "utf-8", "Cannot write file MTEvents.1.txt!\n";
print $eventList encode "UTF-16LE", chr(0xFEFF);
print $eventList encode "UTF-16LE", "Client\tStart Timestamp\tEnd Timestamp\tDuration\tSegments\tSource Language\tTargetLanguage\tProduct\tCommands\tBad Commands\n";

my $dateParser = DateTime::Format::Builder->new();
$dateParser->parser(
	regex => qr/^(\d{4})\.(\d{2})\.(\d{2})_(\d{2})\.(\d{2})\.(\d{2})$/,
	params => [qw/year month day hour minute second/],
	extra => { time_zone => "CET" },
	on_fail => sub { my %args = @_; warn encode "utf-8", "Coudln’t parse date $args{input}!\n"; },
);
my $durationFormat = DateTime::Format::Duration->new(pattern => '%1mm %ed,%k:%M:%S', normalise => 'ISO');
my $durationLogFormat = DateTime::Format::Duration->new(pattern => '%H:%M:%S', normalise => 'ISO');

my $log;
my $sftp;
if ($file !~ /\.bz2$/) {
	$sftp = Net::SFTP::Foreign->new($server, user => 'cmsuser', key_path => '/Users/ventzi/.ssh/id_rsa');
	$sftp->die_on_error("Cannot connect to server $server: $!\n");
	$log = $sftp->open("$dir/$file", SSH2_FXF_READ) or die "Could not read $dir/$file on server $server!\n";
} else {
	open $log, "ssh -n cmsuser\@$server 'bzcat $dir/$file' 2>/dev/null |"
	or die encode "utf-8", "Cannot start ssh to read bzip2 file!\n";
}
while (my $line = decode "utf-8", scalar <$log>) {
	chomp $line;
	if ($line =~ /^Connection from ([\d.]+:\d{4,5}) (.*)…$/) {
		# First encounter of user
		my ($user, $timeStamp) = ($1, $dateParser->parse_datetime($2));
		unless ($startTime) {
			$startTime = $timeStamp;
			$durationFormat->set_base($timeStamp);
		}
#		print "Found user $user connecting on $timeStamp!\n";
		++$toCheck{$user};
		$userData{$user}->{timeStamp} = $timeStamp;
		$userData{$user}->{ID} = ++$currentUserID;
		$connectionStats{$currentUserID}->{user} = $user;
		$connectionStats{$currentUserID}->{start} = $timeStamp;
	} elsif ($line =~ /^Executing command “(.*)” for ([\d.]+:\d{4,5})…$/) {
		# Found the command the user is executing
		my ($command, $user) = ($1, $2);
		my $currentUser = $userData{$user}->{ID};
		die "Unknown user $user!\n" unless defined $currentUser;
		if ($command =~ /translate =>/) {
			$translationStats{$currentUser}->{user} = $user;
			my $data = eval $command;
			$data->{sourceLanguage} ||= "en";
			$data->{targetLanguage} ||= "en";
			$data->{sourceLanguage} = $localeMap{lc $data->{sourceLanguage}} if defined $localeMap{lc $data->{sourceLanguage}};
			$data->{targetLanguage} = $localeMap{lc $data->{targetLanguage}} if defined $localeMap{lc $data->{targetLanguage}};
			$data->{sourceLanguage} =~ tr/-/_/;
			$data->{targetLanguage} =~ tr/-/_/;
			$data->{product} ||= "none";
			@{$translationStats{$currentUser}}{qw/sourceLanguage targetLanguage translate product/} = @$data{qw/sourceLanguage targetLanguage translate product/};
			
			#Source Language -> Target Language -> Product
			my $stats = $MTStatsSTP{$data->{sourceLanguage}}->{$data->{targetLanguage}}->{$data->{product}};
			$stats = $MTStatsSTP{$data->{sourceLanguage}}->{$data->{targetLanguage}}->{$data->{product}} = {} unless defined $stats;
			$stats->{segments} += $data->{translate};
			++$stats->{sessions};
			$stats->{duration} = DateTime::Duration->new() unless defined $stats->{duration};
			#Source Language -> Target Language -> all
			$stats = $MTStatsSTP{$data->{sourceLanguage}}->{$data->{targetLanguage}}->{__all__};
			$stats = $MTStatsSTP{$data->{sourceLanguage}}->{$data->{targetLanguage}}->{__all__} = {} unless defined $stats;
			$stats->{segments} += $data->{translate};
			++$stats->{sessions};
			$stats->{duration} = DateTime::Duration->new() unless defined $stats->{duration};
			#Target Language -> Source Language -> Product
			$stats = $MTStatsTSP{$data->{targetLanguage}}->{$data->{sourceLanguage}}->{$data->{product}};
			$stats = $MTStatsTSP{$data->{targetLanguage}}->{$data->{sourceLanguage}}->{$data->{product}} = {} unless defined $stats;
			$stats->{segments} += $data->{translate};
			++$stats->{sessions};
			$stats->{duration} = DateTime::Duration->new() unless defined $stats->{duration};
			#Target Language -> Source Language -> all
			$stats = $MTStatsTSP{$data->{targetLanguage}}->{$data->{sourceLanguage}}->{__all__};
			$stats = $MTStatsTSP{$data->{targetLanguage}}->{$data->{sourceLanguage}}->{__all__} = {} unless defined $stats;
			$stats->{segments} += $data->{translate};
			++$stats->{sessions};
			$stats->{duration} = DateTime::Duration->new() unless defined $stats->{duration};
			#Product -> Target Language -> Source Language
			$stats = $MTStatsPTS{$data->{product}}->{$data->{targetLanguage}}->{$data->{sourceLanguage}};
			$stats = $MTStatsPTS{$data->{product}}->{$data->{targetLanguage}}->{$data->{sourceLanguage}} = {} unless defined $stats;
			$stats->{segments} += $data->{translate};
			++$stats->{sessions};
			$stats->{duration} = DateTime::Duration->new() unless defined $stats->{duration};
			#Product -> all
			$stats = $MTStatsPTS{$data->{product}}->{__all__};
			$stats = $MTStatsPTS{$data->{product}}->{__all__} = {} unless defined $stats;
			$stats->{segments} += $data->{translate};
			++$stats->{sessions};
			$stats->{duration} = DateTime::Duration->new() unless defined $stats->{duration};
		}
		$userData{$user}->{commands} ||= [];
		push @{$userData{$user}->{commands}}, $command;
	} elsif ($line =~ /^?Bad command “(.*)” received from ([\d.]+:\d{4,5})! Aborting…$/) {
		# Bad user not use good command…
		my ($command, $user) = ($1, $2);
		die "Unknown user $user!\n" unless defined $userData{$user}->{ID};
		++$userData{$user}->{badCommands};
	} elsif ($line =~ /^Closed connection to ([\d.]+:\d{4,5}) (.*)\.$/) {
		# Bye bye user!
		my ($user, $timeStamp) = ($1, $dateParser->parse_datetime($2));
		$endTime = $timeStamp;
#		print encode "utf-8", "Closed connection to $user at $timeStamp\n";
		my $currentUser = $userData{$user}->{ID};
		die "Unknown user $user!\n" unless defined $currentUser;
		$connectionStats{$currentUser}->{end} = $timeStamp;
		my $userStats = $translationStats{$currentUser};
		if (defined $userStats) {
			my $duration = $connectionStats{$currentUser}->{end}->subtract_datetime($connectionStats{$currentUser}->{start});
			$MTStatsSTP{$userStats->{sourceLanguage}}->{$userStats->{targetLanguage}}->{$userStats->{product}}->{duration}->add_duration($duration);
			$MTStatsSTP{$userStats->{sourceLanguage}}->{$userStats->{targetLanguage}}->{__all__}->{duration}->add_duration($duration);
			$MTStatsTSP{$userStats->{targetLanguage}}->{$userStats->{sourceLanguage}}->{$userStats->{product}}->{duration}->add_duration($duration);
			$MTStatsTSP{$userStats->{targetLanguage}}->{$userStats->{sourceLanguage}}->{__all__}->{duration}->add_duration($duration);
			$MTStatsPTS{$userStats->{product}}->{$userStats->{targetLanguage}}->{$userStats->{sourceLanguage}}->{duration}->add_duration($duration);
			$MTStatsPTS{$userStats->{product}}->{__all__}->{duration}->add_duration($duration);
		}
		
		print $eventList encode "UTF-16LE", "$user\t".$connectionStats{$currentUser}->{start}->ymd('-')." ".$connectionStats{$currentUser}->{start}->hms(':')."\t".$connectionStats{$currentUser}->{end}->ymd('-')." ".$connectionStats{$currentUser}->{end}->hms(':')."\t".$durationLogFormat->format_duration($connectionStats{$currentUser}->{end}->subtract_datetime($connectionStats{$currentUser}->{start}))."\t".(defined $userStats ? join "\t", @{$userStats}{qw/translate sourceLanguage targetLanguage product/} : "\t\t\t")."\t".(defined $userData{$user}->{commands} ? join ", ", @{$userData{$user}->{commands}} : "")."\t".(defined $userData{$user}->{badCommands} ? $userData{$user}->{badCommands} : 0)."\n";
#		print encode "utf-8", "$user\t".$connectionStats{$currentUser}->{start}->ymd('-')." ".$connectionStats{$currentUser}->{start}->hms(':')."\t".$connectionStats{$currentUser}->{end}->ymd('-')." ".$connectionStats{$currentUser}->{end}->hms(':')."\t".$durationLogFormat->format_duration($connectionStats{$currentUser}->{end}->subtract_datetime($connectionStats{$currentUser}->{start}))."\t".(defined $userStats ? join "\t", @{$userStats}{qw/translate sourceLanguage targetLanguage product/} : "\t\t\t")."\t".(defined $userData{$user}->{commands} ? join ", ", @{$userData{$user}->{commands}} : "")."\t".(defined $userData{$user}->{badCommands} ? $userData{$user}->{badCommands} : 0)."\n";
		
		delete($userData{$user});
	}
}
close $log;
$sftp->disconnect() if $file !~ /\.bz2$/;
close $eventList;


print encode "utf-8", "Start time: $startTime; End time: $endTime\n";

foreach my $sourceLanguage (sort {$a cmp $b} keys %MTStatsSTP) {
	foreach my $targetLanguage (sort {$a cmp $b} keys %{$MTStatsSTP{$sourceLanguage}}) {
		foreach my $product (sort {$a eq "__all__" && $b eq "none" ? -1 : ($a eq "none" && $b eq "__all__" ? 1 : ($a eq "__all__" || $a eq "none" ? -1 : ($b eq "__all__" || $b eq "none" ? 1 : (lc $a cmp lc $b))))} keys %{$MTStatsSTP{$sourceLanguage}->{$targetLanguage}}) {
			my $data = $MTStatsSTP{$sourceLanguage}->{$targetLanguage}->{$product};
			if ($product eq "__all__") {
				print encode "utf-8", "Total translation duration from “$sourceLanguage” into “$targetLanguage” for “__all__”: ".$durationFormat->format_duration($data->{duration})."; Sessions: $data->{sessions}; Segments: $data->{segments}\n";
				next;
			}
			print encode "utf-8", "Total translation duration from “$sourceLanguage” into “$targetLanguage” for “$product”: ".$durationFormat->format_duration($data->{duration})."; Sessions: $data->{sessions}; Segments: $data->{segments}\n";
		}
	}
}

foreach my $product (sort {$a cmp $b} keys %MTStatsPTS) {
	foreach my $targetLanguage (sort {$a cmp $b} keys %{$MTStatsPTS{$product}}) {
		if ($targetLanguage eq "__all__") {
			my $data = $MTStatsPTS{$product}->{$targetLanguage};
			print encode "utf-8", "Total translation duration for “$product” into “__all__” from “__all__”: ".$durationFormat->format_duration($data->{duration})."; Sessions: $data->{sessions}; Segments: $data->{segments}\n";
			next;
		}
		foreach my $sourceLanguage (sort {$a cmp $b} keys %{$MTStatsPTS{$product}->{$targetLanguage}}) {
			my $data = $MTStatsPTS{$product}->{$targetLanguage}->{$sourceLanguage};
			print encode "utf-8", "Total translation duration for “$product” into “$targetLanguage” from “$sourceLanguage”: ".$durationFormat->format_duration($data->{duration})."; Sessions: $data->{sessions}; Segments: $data->{segments}\n";
		}
	}
}



1;