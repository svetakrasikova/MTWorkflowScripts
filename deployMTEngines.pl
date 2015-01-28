#!/usr/bin/perl -ws
#
# ©2014 Autodesk Development Sàrl
# Created on 11 Feb 2014 by Ventsislav Zhechev
#
# ChangeLog
# v0.2.4		Modified on 04 Nov 2014 by Ventsislav Zhechev
# Updated engine deployment.
#
# v0.2.3		Modified on 19 Sep 2014 by Ventsislav Zhechev
# Updated engine list for FY16.
# The list of servers is now taken from the %systems hash, instead of being hard-coded.
#
# v0.2.2		Modified on 29 Apr 2014 by Ventsislav Zhechev
# Updated PT-PT engine.
#
# v0.2.1		Modified on 28 Apr 2014 by Ventsislav Zhechev
# Updated engine list.
#
# v0.2			Modified on 14 Apr 2014 by Ventsislav Zhechev
# Updated engine list.
# Modified the deployment algorithm to make sure each target server is only connected from one thread at a time.
#
# v0.1.2		Modified on 19 Mar 2014 by Ventsislav Zhechev
# Updated engine list.
#
# v0.1.1		Modified on 11 Mar 2014 by Ventsislav Zhechev
# Updated engine list.
# Improved the status output during operation & test drive.
#
# v0.1			Modified on 11 Feb 2014 by Ventsislav Zhechev
# Initial version.
#
####################

use strict;
use utf8;

use threads;
use threads::shared;
use Thread::Queue;

use List::Util qw/shuffle/;


our ($threads, $testDrive);
$threads ||= 8;

$| = 1;

select STDERR;
$| = 1;


my %systems = (
"mtprd01" => ["fy16_EN-DA_b","fy16_EN-HU_b","fy16_EN-NL_b","fy16_EN-NO_b","fy16_EN-SV_b","fy16_PT_BR-EN_a",],
"mtprd02" => ["fy16_EN-EN_GB_b","fy16_EN-PL_b","fy16_KO-EN_a",],
"mtprd03" => ["fy16_EN-FI_b","fy16_EN-ZH_HANT_b","fy16_ES-EN_a",],
"mtprd04" => ["fy16_EN-PT_BR_b","fy16_EN-PT_PT_b","fy16_HU-EN_a",],
"mtprd05" => ["fy16_EN-KO_b","fy16_PL-EN_a",],
"mtprd06" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"mtprd07" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"mtprd08" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"mtprd09" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"mtprd10" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"mtprd11" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"mtprd12" => ["fy16_EN-IT_b","fy16_EN-PL_b",],
"ussclpdapcmsl01" => ["fy16_CS-EN_a","fy16_EN-HU_b","fy16_EN-RU_b","fy16_IT-EN_a","fy16_RU-EN_a","fy16_ZH_HANS-EN_a",],
"ussclpdapcmsl02" => ["fy16_EN-HU_b","fy16_EN-PT_PT_b","fy16_EN-ZH_HANT_b","fy16_FR-EN_a","fy16_JP-EN_a",],
"ussclpdapcmsl03" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ES_b","fy16_EN-HU_b","fy16_EN-PT_PT_b",],
"ussclpdapcmsl04" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ES_b","fy16_EN-HU_b","fy16_EN-PT_PT_b",],
"ussclpdapcmsl05" => ["fy16_EN-ES_b","fy16_EN-FR_b","fy16_EN-PL_b","fy16_EN-PT_BR_b","fy16_EN-ZH_HANT_b",],
"ussclpdapcmsl06" => ["fy16_EN-IT_b","fy16_EN-PT_BR_b","fy16_EN-RU_b","fy16_EN-ZH_HANS_b","fy16_ZH_HANT-EN_a",],
"ussclpdapcmsl07" => ["fy16_EN-HU_b","fy16_EN-IT_b","fy16_EN-JP_b","fy16_EN-PT_BR_b",],
"ussclpdapcmsl08" => ["fy16_DE-EN_a","fy16_EN-DE_b","fy16_EN-HU_b","fy16_EN-ZH_HANS_b",],
"ussclpdapcmsl09" => ["fy16_EN-ES_b","fy16_EN-HU_b","fy16_EN-KO_b","fy16_EN-RU_b","fy16_EN-ZH_HANT_b",],
"ussclpdapcmsl10" => ["fy16_EN-ES_b","fy16_EN-HU_b","fy16_EN-KO_b","fy16_EN-RU_b","fy16_EN-ZH_HANT_b",],
"ussclpdapcmsl11" => ["fy16_EN-FR_b","fy16_EN-JP_b","fy16_EN-RU_b",],
"ussclpdapcmsl12" => ["fy16_EN-FR_b","fy16_EN-JP_b","fy16_EN-RU_b",],
"ussclpdmtlnx001" => ["fy16_EN-FR_b","fy16_EN-JP_b","fy16_EN-RU_b",],
"ussclpdmtlnx002" => ["fy16_EN-FR_b","fy16_EN-JP_b","fy16_EN-RU_b",],
"ussclpdmtlnx003" => ["fy16_EN-FR_b","fy16_EN-JP_b","fy16_EN-RU_b",],
"ussclpdmtlnx004" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ZH_HANS_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx005" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ZH_HANS_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx006" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ZH_HANS_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx007" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ZH_HANS_b","fy16_EN-ZH_HANT_b",],
"ussclpdmtlnx008" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ES_b","fy16_EN-KO_b",],
"ussclpdmtlnx009" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ES_b","fy16_EN-KO_b",],
"ussclpdmtlnx010" => ["fy16_EN-CS_b","fy16_EN-DE_b","fy16_EN-ES_b","fy16_EN-KO_b",],
"ussclpdmtlnx011" => ["fy16_EN-ES_b","fy16_EN-FR_b","fy16_EN-JP_b",],
"ussclpdmtlnx012" => ["fy16_EN-FR_b","fy16_EN-KO_b","fy16_EN-PT_BR_b","fy16_EN-ZH_HANS_b",],
"ussclpdmtlnx013" => ["fy16_EN-FR_b","fy16_EN-KO_b","fy16_EN-PT_BR_b","fy16_EN-ZH_HANS_b",],
"ussclpdmtlnx014" => ["fy16_EN-JP_b","fy16_EN-PT_BR_b","fy16_EN-ZH_HANS_b",],
"ussclpdmtlnx015" => ["fy16_EN-JP_b","fy16_EN-PT_BR_b","fy16_EN-ZH_HANS_b",],
"ussclpdmtlnx016" => ["fy16_EN-JP_b","fy16_EN-KO_b","fy16_EN-PT_BR_b",],
);

my $busyList :shared = shared_clone { map {$_ => 0} keys %systems };

my $deployments = new Thread::Queue;

my $deploy = sub {
	for (;;) {
		my $deployment;
		unless ($deployment = $deployments->dequeue()) {
			print STDOUT threads->tid().": Finished work!\n";
			last;
		}
		my $busy = 0;
		{ lock $busyList;
			if ($busyList->{$deployment->{target}}) {
				$busy = 1;
			} else {
				$busyList->{$deployment->{target}} = 1;
			}
		}
		if ($busy) {
			print STDOUT threads->tid().": ", "Server $deployment->{target} busy. Requeuing engine $deployment->{source}.\n";
			$deployments->insert(-$threads, $deployment);
			sleep 10;
			next;
		}
		if (defined $testDrive) {
			print STDOUT threads->tid().": ", join " ", "rsync", "-azyvv", "/Volumes/LaCie_Work/Autodesk/".$deployment->{source}, "cmsuser@".$deployment->{target}.":/local/cms/.", "\n";
			sleep .1;
		} else {
			print STDOUT threads->tid().": ".($deployments->pending()-$threads)." engines left. Deploying using command: ", join " ", "rsync", "-azyvv", "/Volumes/LaCie_Work/Autodesk/".$deployment->{source}, "cmsuser@".$deployment->{target}.":/local/cms/.", "\n";
			system "rsync", "-azyvv", "/Volumes/LaCie_Work/Autodesk/".$deployment->{source}, "cmsuser@".$deployment->{target}.":/local/cms/.";
		}
		{ lock $busyList;
			$busyList->{$deployment->{target}} = 0;
		}
	}
};


my @workers = map { scalar threads->create($deploy) } 1..$threads;

my @queue;
foreach my $target (shuffle keys %systems) {
	foreach my $source (@{$systems{$target}}) {
		push @queue, {source => $source, target => $target};
	}
}
$deployments->enqueue($_) foreach shuffle @queue;


$deployments->enqueue(undef) foreach 1..$threads;
$_->join() foreach @workers;


1;