#!/usr/bin/perl -ws
#
# ©2014–2015 Autodesk Development Sàrl
# Created on 11 Mar 2014 by Ventsislav Zhechev
#
# ChangeLog
# !!! Subsequent changes tracked on GitHub only !!!
#
# v0.2.1		Modified on 29 Jan 2015 by Ventsislav Zhechev
# Updated deployment matrix to reflect Jan 2015 state.
#
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
"ussclpdapcmsl01" => ["fy16_CS-EN_a","fy16_EN-CS_b","fy16_EN-DA_b","fy16_EN-EN_GB_b","fy16_EN-FI_b","fy16_EN-NL_b","fy16_EN-NO_b","fy16_EN-PL_b","fy16_EN-PT_BR_b","fy16_EN-SV_b","fy16_HU-EN_a",],
"ussclpdapcmsl02" => ["fy16_EN-DE_b","fy16_EN-RU_b","fy16_PL-EN_a","fy16_PT_BR-EN_a","fy16_RU-EN_a",],
"ussclpdapcmsl03" => ["fy16_DE-EN_a","fy16_EN-HU_b","fy16_EN-IT_b","fy16_EN-PT_BR_b","fy16_ES-EN_a",],
"ussclpdapcmsl04" => ["fy16_EN-IT_b","fy16_EN-RU_b","fy16_EN-ZH_HANS_b","fy16_IT-EN_a",],
"ussclpdapcmsl05" => ["fy16_EN-CS_b","fy16_EN-FR_b","fy16_EN-HU_b","fy16_EN-PT_BR_b","fy16_EN-PT_PT_b",],
"ussclpdapcmsl06" => ["fy16_EN-CS_b","fy16_EN-FR_b","fy16_EN-HU_b","fy16_EN-PT_BR_b","fy16_EN-PT_PT_b",],
"ussclpdapcmsl07" => ["fy16_EN-CS_b","fy16_EN-HU_b","fy16_EN-JP_b","fy16_EN-PL_b",],
"ussclpdapcmsl08" => ["fy16_EN-CS_b","fy16_EN-HU_b","fy16_EN-JP_b","fy16_EN-PL_b",],
"ussclpdapcmsl09" => ["fy16_EN-CS_b","fy16_EN-HU_b","fy16_EN-JP_b","fy16_EN-PL_b",],
"ussclpdapcmsl10" => ["fy16_EN-CS_b","fy16_EN-HU_b","fy16_EN-JP_b","fy16_EN-PL_b",],
"ussclpdapcmsl11" => ["fy16_EN-PT_PT_b","fy16_EN-ZH_HANS_b","fy16_JP-EN_a","fy16_KO-EN_a",],
"ussclpdapcmsl12" => ["fy16_EN-IT_b","fy16_EN-PL_b","fy16_EN-PT_PT_b","fy16_EN-RU_b","fy16_FR-EN_a",],
"ussclpdmtlnx001" => ["fy16_EN-PL_b","fy16_EN-RU_b","fy16_EN-ZH_HANT_b","fy16_ZH_HANS-EN_a","fy16_ZH_HANT-EN_a",],
"ussclpdmtlnx002" => ["fy16_EN-ES_b","fy16_EN-JP_b","fy16_EN-PT_BR_b",],
"ussclpdmtlnx003" => ["fy16_EN-ES_b","fy16_EN-JP_b","fy16_EN-PT_BR_b",],
"ussclpdmtlnx004" => ["fy16_EN-ES_b","fy16_EN-JP_b","fy16_EN-PT_BR_b",],
"ussclpdmtlnx005" => ["fy16_EN-ES_b","fy16_EN-JP_b","fy16_EN-PT_BR_b",],
"ussclpdmtlnx006" => ["fy16_EN-ES_b","fy16_EN-PL_b","fy16_EN-ZH_HANS_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx007" => ["fy16_EN-DE_b","fy16_EN-IT_b","fy16_EN-KO_b",],
"ussclpdmtlnx008" => ["fy16_EN-DE_b","fy16_EN-IT_b","fy16_EN-KO_b",],
"ussclpdmtlnx009" => ["fy16_EN-DE_b","fy16_EN-IT_b","fy16_EN-KO_b",],
"ussclpdmtlnx010" => ["fy16_EN-DE_b","fy16_EN-IT_b","fy16_EN-KO_b",],
"ussclpdmtlnx011" => ["fy16_EN-DE_b","fy16_EN-IT_b","fy16_EN-KO_b",],
"ussclpdmtlnx012" => ["fy16_EN-CS_b","fy16_EN-ES_b","fy16_EN-ZH_HANS_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx013" => ["fy16_EN-DE_b","fy16_EN-FR_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx014" => ["fy16_EN-DE_b","fy16_EN-FR_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx015" => ["fy16_EN-ES_b","fy16_EN-KO_b","fy16_EN-RU_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx016" => ["fy16_EN-ES_b","fy16_EN-KO_b","fy16_EN-RU_b","fy16_EN-ZH_HANT_b",],
"mtprd01" => ["fy16_EN-ZH_HANS_b",],
"mtprd02" => ["fy16_EN-ZH_HANS_b",],
"mtprd03" => ["fy16_EN-ZH_HANS_b",],
"mtprd04" => ["fy16_EN-ZH_HANS_b",],
"mtprd05" => ["fy16_EN-FR_b",],
"mtprd06" => ["fy16_EN-FR_b",],
"mtprd07" => ["fy16_EN-FR_b",],
"mtprd08" => ["fy16_EN-FR_b",],
"mtprd09" => ["fy16_EN-KO_b",],
"mtprd10" => ["fy16_EN-ZH_HANT_b",],
"mtprd11" => ["fy16_EN-RU_b",],
"mtprd12" => ["fy16_EN-RU_b",],
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
		my $engines = join " ", map {"/local/cms/$_"} grep {!defined $servers{$server}->{$_}} split /\n/, `ssh -qn cmsuser\@$server 'ls /local/cms/ |grep fy'`;
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