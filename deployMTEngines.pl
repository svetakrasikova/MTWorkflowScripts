#!/usr/bin/perl -ws
#
# ©2014 Autodesk Development Sàrl
# Created on 11 Feb 2014 by Ventsislav Zhechev
#
# ChangeLog
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
"ussclpdapcmsl01" => ["fy15_EN-DA_d","fy15_EN-EN_GB_a","fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-NO_d","fy15_EN-PL_d","fy15_EN-VI_c","fy15_RU-EN_a","fy15_XX-EN_b",],
"ussclpdapcmsl02" => ["fy15_DE-EN_a","fy15_EN-ES_c","fy15_EN-JP_c","fy15_EN-SV_d","fy15_XX-EN_b",],
"ussclpdapcmsl03" => ["fy15_EN-IT_d","fy15_EN-NL_d","fy15_EN-RU_d","fy15_EN-ZH_HANS_c","fy15_KO-EN_a","fy15_XX-EN_b",],
"ussclpdapcmsl04" => ["fy15_EN-CS_d","fy15_EN-FI_d","fy15_IT-EN_a","fy15_JP-EN_a","fy15_XX-EN_b",],
"ussclpdapcmsl05" => ["fy15_EN-ES_c","fy15_EN-PT_BR_d","fy15_ES-EN_a","fy15_PL-EN_a","fy15_XX-EN_b",],
"ussclpdapcmsl06" => ["fy15_EN-CS_d","fy15_EN-DE_d","fy15_EN-ZH_HANT_c","fy15_ZH_HANT-EN_a","fy15_XX-EN_b",],
"ussclpdapcmsl07" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdapcmsl08" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdapcmsl09" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdapcmsl10" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdapcmsl11" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdapcmsl12" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdmtlnx001" => ["fy15_EN-DE_d","fy15_EN-IT_d","fy15_EN-KO_c","fy15_EN-PL_d","fy15_EN-ZH_HANT_c",],
"ussclpdmtlnx002" => ["fy15_EN-ES_c","fy15_EN-PT_BR_d","fy15_FR-EN_a","fy15_PT_BR-EN_a","fy15_XX-EN_b",],
"ussclpdmtlnx003" => ["fy15_EN-CS_d","fy15_EN-FR_c","fy15_EN-KO_c","fy15_ZH_HANS-EN_a","fy15_XX-EN_b",],
"ussclpdmtlnx004" => ["fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-RU_d",],
"ussclpdmtlnx005" => ["fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-RU_d",],
"ussclpdmtlnx006" => ["fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-RU_d",],
"ussclpdmtlnx007" => ["fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-RU_d",],
"ussclpdmtlnx008" => ["fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-RU_d",],
"ussclpdmtlnx009" => ["fy15_EN-FR_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-RU_d",],
"ussclpdmtlnx010" => ["fy15_EN-JP_c","fy15_EN-PT_BR_d","fy15_EN-RU_d","fy15_EN-ZH_HANS_c",],
"ussclpdmtlnx011" => ["fy15_EN-CS_d","fy15_EN-ES_c","fy15_EN-HU_d","fy15_EN-JP_c","fy15_EN-PT_BR_d",],
"ussclpdmtlnx012" => ["fy15_EN-DE_d","fy15_EN-JP_c","fy15_EN-ZH_HANS_c",],
"mtprd01" => ["fy15_HU-EN_a","fy15_XX-EN_b",],
"mtprd02" => ["fy15_CS-EN_a","fy15_XX-EN_b",],
"mtprd03" => ["fy15_EN-PT_BR_d","fy15_EN-ZH_HANS_c",],
"mtprd04" => ["fy15_EN-PT_BR_d","fy15_EN-ZH_HANS_c",],
"mtprd05" => ["fy15_EN-PT_BR_d","fy15_EN-ZH_HANS_c",],
"mtprd06" => ["fy15_EN-PT_BR_d","fy15_EN-ZH_HANS_c",],
"mtprd07" => ["fy15_EN-PT_BR_d","fy15_EN-ZH_HANS_c",],
"mtprd08" => ["fy15_EN-PT_BR_d","fy15_EN-ZH_HANS_c",],
"mtprd09" => ["fy15_EN-CS_d","fy15_EN-ES_c",],
"mtprd10" => ["fy15_EN-CS_d","fy15_EN-ES_c",],
"mtprd11" => ["fy15_EN-CS_d","fy15_EN-ES_c",],
"mtprd12" => ["fy15_EN-CS_d","fy15_EN-ES_c",],
);

my $busyList :shared = shared_clone { map {$_ => 0} qw/mtprd01 mtprd02 mtprd03 mtprd04 mtprd05 mtprd06 mtprd07 mtprd08 mtprd09 mtprd10 mtprd11 mtprd12 ussclpdapcmsl01 ussclpdapcmsl02 ussclpdapcmsl03 ussclpdapcmsl04 ussclpdapcmsl05 ussclpdapcmsl06 ussclpdapcmsl07 ussclpdapcmsl08 ussclpdapcmsl09 ussclpdapcmsl10 ussclpdapcmsl11 ussclpdapcmsl12 ussclpdmtlns001 ussclpdmtlns002 ussclpdmtlns003 ussclpdmtlns004 ussclpdmtlns005 ussclpdmtlns006 ussclpdmtlns007 ussclpdmtlns008 ussclpdmtlns009 ussclpdmtlns010 ussclpdmtlns011 ussclpdmtlns012/ };

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