#!/usr/bin/perl -ws
#####################
#
# ©2013–2014 Autodesk Development Sàrl
#
# Created on 02 Jul 2013 by Ventsislav Zhechev
#
# Changelog
# v0.4.2		Modified by Ventsislav Zhechev on 02 Jul 2014
# Changed the format of the .list output file so that it could be easily read in by Excel.
# Changed the extension of the .list output file to .list.csv
#
# v0.4.1		Modified by Ventsislav Zhechev on 08 Jul 2013
# Fixed bugs in the sorted list output.
#
# v0.4			Modified by Ventsislav Zhechev on 07 Jul 2013
# Rewritten from scratch, after the original source code was lost due to disk failure at about v.3.2.
#
# v0.1			Modified by Ventsislav Zhechev on 02 Jul 2013
# First version.
#
#####################

use strict;
use utf8;

use threads;
use threads::shared;
use Thread::Queue;

use Encode qw/encode decode/;
use Storable qw/dclone/;
use Data::Serializer::Raw;

use Benchmark qw/:hireswallclock/;

$| = 1;
select STDERR;
$| = 1;


our ($sourceCorpus, $targetCorpus, $ambiguousStrings, $threads);

die encode "utf-8", "Usage: $0 -sourceCorpus=… -targetCorpus=… -ambiguousStrings=… [-threads=…]\n"
unless defined $sourceCorpus && defined $targetCorpus && defined $ambiguousStrings;

$threads ||= 8;
print STDERR encode "utf-8", "Using $threads threads…\n";

my $serialiser = Data::Serializer::Raw->new(serializer => "JSON")
or die "Could not create serialiser: $!\n";
my $data = $serialiser->retrieve($ambiguousStrings);

{
	print STDERR encode "utf-8", "Sorting ambiguous term data for faster lookup…";
	my $newData;
	foreach my $sourceTerm (keys %$data) {
		foreach my $rankData (@{$data->{$sourceTerm}}) {
			foreach my $targetTerm (keys %$rankData) {
				foreach my $product (keys %{$rankData->{$targetTerm}}) {
					$newData->{$product}->{$sourceTerm}->{$targetTerm} = $rankData->{$targetTerm}->{$product};
				}
			}
		}
	}
	$data = dclone $newData;
	print STDERR "done!\n";
}

$ambiguousStrings =~ s/\.json$/.lookup.json/;
unlink $ambiguousStrings;
$serialiser->store($data, $ambiguousStrings);


my $countData = &share({});
my $segmentQueue = Thread::Queue->new;

my $totalProcessingTime :shared = 0;

my $processSegment = sub {
	my ($productData, $sourceData, $sourceTermData, $targetTermData);
	for (;;) {
		my $startTime = new Benchmark;
		my $job = $segmentQueue->dequeue();
		last unless defined $job;
		my ($sourceSegment, $targetSegment, $product, $segmentID) = @$job;
		unless ($segmentID % 25000) {
			lock $totalProcessingTime;
			print STDERR encode "utf-8", "«$segmentID»˛".sprintf("%.4g", $totalProcessingTime/($segmentID-1.))."¸";
		}
		
		$productData = $data->{$product};
		foreach my $sourceTerm (keys %$productData) {
			next if length $sourceTerm > length $sourceSegment || (() = $sourceTerm =~ /( )/g) > (() = $sourceSegment =~ /( )/g);
			if ($sourceSegment =~ /\b\Q$sourceTerm\E\b/i) {
				$sourceData = $productData->{$sourceTerm};
				foreach my $targetTerm (keys %$sourceData) {
					next if length $targetTerm > length $targetSegment || (() = $targetTerm =~ /( )/g) > (() = $targetSegment =~ /( )/g);
					if ($targetSegment =~ /\b\Q$targetTerm\E\b/i) {
						lock $countData;
						$sourceTermData = $countData->{$sourceTerm};
						$sourceTermData = $countData->{$sourceTerm} = &share({}) unless defined $sourceTermData;
						++$sourceTermData->{totalCount};
						
						$targetTermData = $sourceTermData->{$targetTerm};
						$targetTermData = $sourceTermData->{$targetTerm} = &share({}) unless defined $targetTermData;
						
						unless (defined $targetTermData->{$product}) {
							$targetTermData->{$product} = &share({});
							$targetTermData->{$product}->{probability} = $sourceData->{$targetTerm};
						}
						
						++$targetTermData->{$product}->{count};
						print STDOUT encode "utf-8", "“$sourceSegment”↔“$targetSegment”→“$sourceTerm”↔“$targetTerm”◊$product◊$segmentID\n";
					}
				}
			}
		}
		
		{ lock $totalProcessingTime;
			no warnings;
			$totalProcessingTime += timestr(timediff(new Benchmark, $startTime), "noc");
		}
	}
};

my $startTime = new Benchmark;
my @threads = map {threads->create($processSegment)} 1..$threads;

open my $src, "<$sourceCorpus";
open my $trg, "<$targetCorpus";
while (my $sourceSegment = decode "utf-8", scalar <$src>) {
	unless ($.%10000) {
		print STDERR ".";
		print STDERR encode "utf-8", "‹$.›" unless $.%250000;
	}
#	last unless $.%20000;
	my $targetSegment = <$trg>;
	chomp $sourceSegment;
	$sourceSegment =~ s/(.+?)◊\w+(?= |$)/$1/g;
	next if length $sourceSegment < 3;
	chomp $targetSegment;
	$targetSegment = decode "utf-8", $targetSegment;
	$targetSegment =~ s/(.+?)◊(\w+)(?= |$)/$1/g;
	my $product = $2;
	next unless defined $product;
	$segmentQueue->enqueue([$sourceSegment, $targetSegment, $product, $.]);
#	&$processSegment();
}

$segmentQueue->enqueue(undef) foreach 1..$threads;
$_->join() foreach @threads;

print STDERR encode "utf-8", "\nAverage processing time per segment: ".sprintf("%.4g", $totalProcessingTime/$.*1.)."\n";
print STDERR encode "utf-8", "Total processing time: ".timestr(timediff(new Benchmark, $startTime), "noc")."\n";

$ambiguousStrings =~ s/\.lookup\.json$/.count.json/;
unlink $ambiguousStrings;
$serialiser->store($countData, $ambiguousStrings);


print STDERR encode "utf-8", "Outputting sorted list of terms…";
$ambiguousStrings =~ s/\.count\.json$/.list.csv/;
open my $output, ">$ambiguousStrings";
print $output encode "UTF-16LE", chr(0xFEFF);
foreach my $sourceTerm (sort  {$countData->{$b}->{totalCount} <=> $countData->{$a}->{totalCount} || $a cmp $b} keys %$countData) {
	my $sourceTermData = $countData->{$sourceTerm};
	my $totalCount = $sourceTermData->{totalCount};
	foreach my $targetTermData (
	sort {$b->{count} <=> $a->{count} || $a->{term} cmp $b->{term}}
	map {
		my $count = 0;
		foreach my $datum (keys %{$sourceTermData->{$_}}) {
			$count += $sourceTermData->{$_}->{$datum}->{count};
		}
		{term => $_, count => $count}
	}
	grep {$_ ne "totalCount"}
	keys %$sourceTermData
	) {
		print $output encode "UTF-16LE", "$sourceTerm\t$targetTermData->{term}\t$totalCount\t$targetTermData->{count}";
		foreach my $product (
		sort {
			$sourceTermData->{$targetTermData->{term}}->{$b}->{count} <=> $sourceTermData->{$targetTermData->{term}}->{$a}->{count} ||
			$sourceTermData->{$targetTermData->{term}}->{$b}->{probability} <=> $sourceTermData->{$targetTermData->{term}}->{$a}->{probability} ||
			$a cmp $b
		}
		keys %{$sourceTermData->{$targetTermData->{term}}}) {
			print $output encode "UTF-16LE", "\t$product $sourceTermData->{$targetTermData->{term}}->{$product}->{count} ".sprintf("%.2g", $sourceTermData->{$targetTermData->{term}}->{$product}->{probability});
		}
		print $output encode "UTF-16LE", "\n";
	}
}
print STDERR "done!\n";




1;