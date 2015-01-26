#!/usr/bin/perl -ws
#
# ©2014–2015 Autodesk Development Sàrl
# Created on 11 Mar 2014 by Ventsislav Zhechev
#
# ChangeLog
# v0.2			Modified on 26 Jan 2015 by Ventsislav Zhechev
# Modified to take into account current engine deployment. The deployment matrix just needs to be copied in manually.
#
# v0.1			Modified on 11 Mar 2014 by Ventsislav Zhechev
# Initial version.
#
####################

use strict;
use utf8;

use threads;
use Thread::Queue;

use List::Util qw/shuffle/;


our ($threads, $testDrive);
$threads ||= 8;

$| = 1;

select STDERR;
$| = 1;


my %servers = (
"mtprd01" => ["fy16_EN-DA_a","fy16_EN-EN_GB_a","fy16_EN-HU_a","fy16_EN-SV_a","fy16_ES-EN_a",],
"mtprd02" => ["fy16_EN-FI_a","fy16_EN-HU_a","fy16_EN-NO_a","fy16_EN-PL_a",],
"mtprd03" => ["fy16_HU-EN_a","fy16_KO-EN_a","fy16_PL-EN_a",],
"mtprd04" => ["fy16_CS-EN_a","fy16_EN-PT_PT_a","fy16_EN-ZH_HANT_a",],
"mtprd05" => ["fy16_EN-PT_BR_a","fy16_ZH_HANS-EN_a",],
"mtprd06" => ["fy16_EN-HU_a","fy16_EN-PT_BR_a","fy16_PT_BR-EN_a",],
"mtprd07" => ["fy16_EN-PL_a","fy16_EN-RU_a",],
"mtprd08" => ["fy16_EN-PL_a","fy16_EN-RU_a",],
"mtprd09" => ["fy16_EN-PL_a","fy16_EN-RU_a",],
"mtprd10" => ["fy16_EN-PL_a","fy16_EN-RU_a",],
"mtprd11" => ["fy16_EN-PL_a","fy16_EN-RU_a",],
"mtprd12" => ["fy16_EN-PL_a","fy16_EN-RU_a",],
"ussclpdapcmsl01" => ["fy16_DE-EN_a","fy16_EN-CS_a","fy16_EN-DE_a","fy16_EN-NL_a","fy16_EN-PT_PT_a","fy16_IT-EN_a",],
"ussclpdapcmsl02" => ["fy16_EN-FR_a","fy16_EN-IT_a","fy16_EN-PL_a","fy16_EN-PT_PT_a","fy16_EN-ZH_HANT_a","fy16_ZH_HANT-EN_a",],
"ussclpdapcmsl03" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl04" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl05" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl06" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl07" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl08" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl09" => ["fy16_EN-ES_a","fy16_EN-IT_a","fy16_EN-KO_a","fy16_EN-ZH_HANS_a","fy16_EN-ZH_HANT_a",],
"ussclpdapcmsl10" => ["fy16_EN-CS_a","fy16_EN-ES_a","fy16_EN-FR_a","fy16_EN-HU_a","fy16_EN-IT_a","fy16_EN-PT_PT_a",],
"ussclpdapcmsl11" => ["fy16_EN-DE_a","fy16_EN-HU_a","fy16_FR-EN_a","fy16_JP-EN_a",],
"ussclpdapcmsl12" => ["fy16_EN-DE_a","fy16_EN-FR_a","fy16_EN-PL_a","fy16_EN-ZH_HANS_a",],
"ussclpdmtlnx001" => ["fy16_EN-DE_a","fy16_EN-ES_a","fy16_EN-FR_a","fy16_EN-ZH_HANS_a",],
"ussclpdmtlnx002" => ["fy16_EN-CS_a","fy16_EN-DE_a","fy16_EN-HU_a","fy16_EN-KO_a","fy16_RU-EN_a",],
"ussclpdmtlnx003" => ["fy16_EN-DE_a","fy16_EN-JP_a","fy16_EN-KO_a",],
"ussclpdmtlnx004" => ["fy16_EN-CS_a","fy16_EN-FR_a","fy16_EN-JP_a","fy16_EN-PT_BR_a",],
"ussclpdmtlnx005" => ["fy16_EN-CS_a","fy16_EN-FR_a","fy16_EN-JP_a","fy16_EN-PT_BR_a",],
"ussclpdmtlnx006" => ["fy16_EN-CS_a","fy16_EN-FR_a","fy16_EN-JP_a","fy16_EN-PT_BR_a",],
"ussclpdmtlnx007" => ["fy16_EN-CS_a","fy16_EN-FR_a","fy16_EN-JP_a","fy16_EN-PT_BR_a",],
"ussclpdmtlnx008" => ["fy16_EN-CS_a","fy16_EN-FR_a","fy16_EN-JP_a","fy16_EN-PT_BR_a",],
"ussclpdmtlnx009" => ["fy16_EN-DE_a","fy16_EN-JP_a","fy16_EN-RU_a",],
"ussclpdmtlnx010" => ["fy16_EN-DE_a","fy16_EN-JP_a","fy16_EN-RU_a",],
"ussclpdmtlnx011" => ["fy16_EN-DE_a","fy16_EN-JP_a","fy16_EN-RU_a",],
"ussclpdmtlnx012" => ["fy16_EN-CS_a","fy16_EN-HU_a","fy16_EN-JP_a","fy16_EN-PT_BR_a",],
);

#Reformat to make searching faster.
foreach my $server (keys %servers) {
	$servers{$server} = {map {$_ => 1} @{$servers{$server}}};
}

my $tasks = new Thread::Queue;

my $delete = sub {
	for (;;) {
		my $server;
		unless ($server = $tasks->dequeue()) {
			print STDOUT threads->tid().": Finished work!\n";
			last;
		}
		#Get the list of engines deployed on this server
		my $engines = join " ", grep {!defined $servers{$server}->{$_}} split /\n/, `ssh -qn cmsuser\@$server 'ls /local/cms/ |grep fy'`;
		if ($engines) {
			if (defined $testDrive) {
				print STDOUT threads->tid().": ", join " ", "ssh", "-qn", "cmsuser\@$server", "'rm -rvf $engines'", "\n";
			} else {
				print STDOUT threads->tid().": ".($tasks->pending()-$threads)." servers left. Deleting using command: ", join " ", "ssh", "-qn", "cmsuser\@$server", "'rm -rvf $engines'", "\n";
				system "ssh", "-qn", "cmsuser\@$server", "rm -rvf $engines";
			}
		} else {
			print STDOUT "Nothing to delete on $server!\n";
		}
	}
};


my @workers = map { scalar threads->create($delete) } 1..$threads;

$tasks->enqueue($_) foreach shuffle keys %servers;


$tasks->enqueue(undef) foreach 1..$threads;
$_->join() foreach @workers;


1;