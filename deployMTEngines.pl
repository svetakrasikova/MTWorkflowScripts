#!/usr/bin/perl -ws
#
# ©2014 Autodesk Development Sàrl
# Created on 11 Feb 2014 by Ventsislav Zhechev
#
# ChangeLog
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
use Thread::Queue;

use List::Util qw/shuffle/;


our ($threads, $testDrive);
$threads ||= 8;

$| = 1;

select STDERR;
$| = 1;


my %systems = (
"mtprd01" => ["fy15_EN-IT_c","fy15_EN-NL_c","fy15_EN-NO_c","fy15_EN-PT_BR_c","fy15_EN-SV_c",],
"mtprd02" => ["fy15_EN-HU_c","fy15_EN-KO_b","fy15_EN-VI_b",],
"mtprd03" => ["fy15_EN-EN_UK_b","fy15_EN-FI_c","fy15_EN-HU_c","fy15_EN-PL_c",],
"mtprd04" => ["fy15_EN-FR_b","fy15_EN-ZH_HANT_b",],
"mtprd05" => ["fy15_EN-FR_b","fy15_EN-ZH_HANT_b",],
"mtprd06" => ["fy15_EN-FR_b","fy15_EN-ZH_HANT_b",],
"mtprd07" => ["fy15_EN-FR_b","fy15_EN-ZH_HANT_b",],
"mtprd08" => ["fy15_EN-HU_c","fy15_EN-ZH_HANS_b",],
"mtprd09" => ["fy15_EN-HU_c","fy15_EN-ZH_HANS_b",],
"mtprd10" => ["fy14_KO-EN_a","fy14_XX-EN_a",],
"mtprd11" => ["fy14_RU-EN_a","fy14_XX-EN_a",],
"mtprd12" => ["fy14_FR-EN_a","fy14_XX-EN_a",],
"ussclpdapcmsl01" => ["fy14_ES-EN_a","fy14_PT_BR-EN_a","fy15_EN-IT_c","fy15_EN-PT_BR_c","fy14_XX-EN_a",],
"ussclpdapcmsl02" => ["fy14_CS-EN_a","fy15_EN-IT_c","fy15_EN-PL_c","fy15_EN-PT_BR_c","fy15_EN-RU_c","fy14_XX-EN_a",],
"ussclpdapcmsl03" => ["fy14_JP-EN_a","fy15_EN-DA_c","fy15_EN-ES_b","fy15_EN-IT_c","fy15_EN-KO_b","fy14_XX-EN_a",],
"ussclpdapcmsl04" => ["fy14_PL-EN_a","fy15_EN-CS_c","fy15_EN-PL_c","fy15_EN-PT_BR_c","fy15_EN-RU_c","fy14_XX-EN_a",],
"ussclpdapcmsl05" => ["fy14_HU-EN_a","fy15_EN-ES_b","fy15_EN-PL_c","fy15_EN-PT_BR_c","fy15_EN-RU_c","fy14_XX-EN_a",],
"ussclpdapcmsl06" => ["fy14_DE-EN_a","fy15_EN-CS_c","fy15_EN-DE_c","fy15_EN-ES_b","fy14_XX-EN_a",],
"ussclpdapcmsl07" => ["fy14_IT-EN_a","fy14_ZH_HANS-EN_a","fy15_EN-ZH_HANS_b","fy14_XX-EN_a",],
"ussclpdapcmsl08" => ["fy15_EN-DE_c","fy15_EN-JP_b","fy15_EN-ZH_HANS_b",],
"ussclpdapcmsl09" => ["fy14_ZH_HANT-EN_a","fy15_EN-CS_c","fy15_EN-JP_b","fy14_XX-EN_a",],
"ussclpdapcmsl10" => ["fy15_EN-DE_c","fy15_EN-JP_b","fy15_EN-KO_b",],
"ussclpdapcmsl11" => ["fy15_EN-DE_c","fy15_EN-JP_b","fy15_EN-KO_b",],
"ussclpdapcmsl12" => ["fy15_EN-CS_c","fy15_EN-ES_b","fy15_EN-JP_b","fy15_EN-RU_c",],
);

my $deployments = new Thread::Queue;

my $deploy = sub {
	for (;;) {
		my $deployment;
		unless ($deployment = $deployments->dequeue()) {
			print STDOUT threads->tid().": Finished work!\n";
			last;
		}
		if (defined $testDrive) {
			print STDOUT threads->tid().": ", join " ", "rsync", "-azyvv", "/Volumes/LaCie_Work/Autodesk/".$deployment->{source}, "cmsuser@".$deployment->{target}.":/local/cms/.", "\n";
		} else {
			print STDOUT threads->tid().": ".($deployments->pending()-$threads)." engines left. Deploying using command: ", join " ", "rsync", "-azyvv", "/Volumes/LaCie_Work/Autodesk/".$deployment->{source}, "cmsuser@".$deployment->{target}.":/local/cms/.", "\n";
			system "rsync", "-azyvv", "/Volumes/LaCie_Work/Autodesk/".$deployment->{source}, "cmsuser@".$deployment->{target}.":/local/cms/.";
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