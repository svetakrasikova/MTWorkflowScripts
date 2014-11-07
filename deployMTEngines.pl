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