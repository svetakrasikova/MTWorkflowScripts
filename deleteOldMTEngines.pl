#!/usr/bin/perl -ws
#
# ©2014 Autodesk Development Sàrl
# Created on 11 Mar 2014 by Ventsislav Zhechev
#
# ChangeLog
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


my @servers = (
"mtprd01",
"mtprd02",
"mtprd03",
"mtprd04",
"mtprd05",
"mtprd06",
"mtprd07",
"mtprd08",
"mtprd09",
"mtprd10",
"mtprd11",
"mtprd12",
"ussclpdapcmsl01",
"ussclpdapcmsl02",
"ussclpdapcmsl03",
"ussclpdapcmsl04",
"ussclpdapcmsl05",
"ussclpdapcmsl06",
"ussclpdapcmsl07",
"ussclpdapcmsl08",
"ussclpdapcmsl09",
"ussclpdapcmsl10",
"ussclpdapcmsl11",
"ussclpdapcmsl12",
"ussclpdmtlnx001",
"ussclpdmtlnx002",
"ussclpdmtlnx003",
"ussclpdmtlnx004",
"ussclpdmtlnx005",
"ussclpdmtlnx006",
"ussclpdmtlnx007",
"ussclpdmtlnx008",
"ussclpdmtlnx009",
"ussclpdmtlnx010",
"ussclpdmtlnx011",
"ussclpdmtlnx012",
);

my $engines = join " /local/cms/", split / /, "fy15_EN-CS_d fy15_EN-DA_d fy15_EN-DE_d fy15_EN-ES_c fy15_EN-FI_d fy15_EN-FR_c fy15_EN-HU_d fy15_EN-IT_d fy15_EN-JP_c fy15_EN-KO_c fy15_EN-NL_d fy15_EN-NO_d fy15_EN-PL_d fy15_EN-PT_BR_d fy15_EN-PT_PT_d fy15_EN-RU_d fy15_EN-SV_d fy15_EN-VI_c fy15_EN-ZH_HANS_c fy15_EN-ZH_HANT_c";

my $tasks = new Thread::Queue;

my $delete = sub {
	for (;;) {
		my $server;
		unless ($server = $tasks->dequeue()) {
			print STDOUT threads->tid().": Finished work!\n";
			last;
		}
		if (defined $testDrive) {
			print STDOUT threads->tid().": ", join " ", "ssh", "-n", "cmsuser\@$server", "'rm -rvf $engines'", "\n";
		} else {
			print STDOUT threads->tid().": ".($tasks->pending()-$threads)." servers left. Deleting using command: ", join " ", "ssh", "-n", "cmsuser\@$server", "'rm -rvf $engines'", "\n";
			system "ssh", "-n", "cmsuser\@$server", "rm -rvf $engines", "\n";
		}
	}
};


my @workers = map { scalar threads->create($delete) } 1..$threads;

$tasks->enqueue($_) foreach shuffle @servers;


$tasks->enqueue(undef) foreach 1..$threads;
$_->join() foreach @workers;


1;