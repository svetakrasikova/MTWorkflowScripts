#!/usr/bin/perl -ws
#
# ©2014 Autodesk Development Sàrl
# Created on 13 Feb 2014 by Ventsislav Zhechev
#
# ChangeLog
# v0.1			Modified on 13 Feb 2014 by Ventsislav Zhechev
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
);

my $tasks = new Thread::Queue;

my $archive = sub {
	while (my $server = $tasks->dequeue()) {
		last unless defined $server;
		if (defined $testDrive) {
			print "ssh -n cmsuser\@$server 'mv /local/cms/nohup.out /local/cms/nohup.out.2014.02.13; bzip2 /local/cms/nohup.out.2014.02.13'", "\n";
		} else {
			print "Running command: ", "ssh -n cmsuser\@$server 'mv /local/cms/nohup.out /local/cms/nohup.out.2014.02.13; bzip2 /local/cms/nohup.out.2014.02.13'", "\n";
			system "ssh -n cmsuser\@$server 'mv /local/cms/nohup.out /local/cms/nohup.out.2014.02.13; bzip2 /local/cms/nohup.out.2014.02.13'";
		}
	}
};


my @workers = map { scalar threads->create($archive) } 1..$threads;

$tasks->enqueue($_) foreach shuffle @servers;


$tasks->enqueue(undef) foreach 1..$threads;
$_->join() foreach @workers;


1;