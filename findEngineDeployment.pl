#!/usr/bin/perl -ws
#
# ©2012–2014 Autodesk Development Sàrl
# Created by Ventsislav Zhechev on 18 Dec 2012
#
# Version history
# v0.5		Last modified on 14 Mar 2014 by Ventsislav Zhechev
# Modified to only store progressively better deployments (i.e. leaving less and less memory unused).
# Execution is stopped after a maximum of 500 maximal deployments are found.
# Updated the statistics output after execution.
#
# v0.4.1	Last modified on 10 Mar 2014 by Ventsislav Zhechev
# Updated the usage string.
# Now we are sorting the list of engines by memory requirement for deployment purposes.
#
# v0.4		Last modified on 13 Feb 2014 by Ventsislav Zhechev
# Added two extra printout modes to simplify the use of the output with other systems.
#
# v0.3		Last modified on 22 Jan 2013 by Ventsislav Zhechev
# Added progress dots.
# Parametrised server deployment order.
#
# v0.2		Last modified on 24 Dec 2012 by Ventsislav Zhechev
# Now we are inspecting all possible deployments.
#
# v0.1		Last modified on 21 Dec 2012 by Ventsislav Zhechev
# Initial version.
#
########################

use strict;
use utf8;

use Encode qw/encode decode/;
use Storable qw/dclone/;
use List::Util qw/max/;

#$DB::deep = 500;

$| = 1;

our ($serverFile, $engineFile, $largeFirst);
die encode "utf-8", "Usage: $0 -serverFile=… -engineFile=… [-largeFirst]\n"
unless defined $serverFile && defined $engineFile;

my $serverOrder = defined $largeFirst ? -1 : 1;
print encode "utf-8", "Deploying on ".(defined $largeFirst ? "large" : "small")." servers first.\n";

my %servers;
my %engines;
my $XXENEngine = "fy14_XX-EN_a";

{
	local $/ = undef;
	
	open my $servers, "<$serverFile"
	or die encode "utf-8", "Cannot read server file “$serverFile”!\n";
	%servers = split ' ', <$servers>;
	close $servers;
	foreach (keys %servers) {
		delete $servers{$_} if /^\#/;
	}
	
	open my $engines, "<$engineFile"
	or die encode "utf-8", "Cannot read engine file “$engineFile”!\n";
	%engines = split /[\t\n]/, <$engines>;
	close $engines;
	foreach (keys %engines) {
		delete $engines{$_} if /^\#/;
	}
	%engines = map {$_ => [(split ' ', $engines{$_})]} keys %engines;
}

my $totalServerMemory;
my @serverList = map {$totalServerMemory += $servers{$_}; $_} sort {($servers{$a} <=> $servers{$b})*$serverOrder || $a cmp $b} keys %servers;
my @engineList = sort {($engines{$b} <=> $engines{$a}) || $a cmp $b} keys %engines;

my $maxMemoryRequirement = $engines{$engineList[0]}->[0];
map {$maxMemoryRequirement = $_->[0] if $_->[0] > $maxMemoryRequirement} values %engines;

my %deployment = map {$_ => {(map {$_ => 0} @engineList)}} @serverList;
my %deployedEngines;
my %deployedEngineIDs = map {$_ => []} @serverList;
my %testServers = %{dclone \%servers};
my %testEngines = %{dclone \%engines};

my $deployments = 0;
my @deployments;

my $leastMemoryRemaining = $totalServerMemory;
my $leastMemoryDeployments = 0;
my $totalDeployments = 0;

&deployServer();

@deployments = sort {$a->{remainingServerMemory} <=> $b->{remainingServerMemory}} @deployments;

my $remainingServerMemory = $totalServerMemory;
print encode "utf-8", "Total deployment attempts: $deployments\n";
print encode "utf-8", "Distinct deployments found: $totalDeployments\n";
print encode "utf-8", "Distinct deployments stored: ".scalar(@deployments)."\n";
print encode "utf-8", "Distinct maximal deployments: $leastMemoryDeployments\n";
foreach my $deployment (@deployments) {
	if ($deployment->{remainingServerMemory} > $remainingServerMemory) {
		last;
	} else {
		$remainingServerMemory = $deployment->{remainingServerMemory};
	}
	%deployment = %{dclone $deployment};
	foreach my $server (@serverList) {
		foreach my $engine (@engineList) {
			if ($deployment{$server}->{$engine}) {
				++$deployedEngines{$engine};
				$testServers{$server} -= $engines{$engine}->[0];
			}
		}
	}
	&printDeployment();
	print encode "utf-8", "Deployed instances per engine:\n";
	foreach my $engine (sort {$a cmp $b} @engineList) {
		print encode "utf-8", "$engine: ".(defined $deployedEngines{$engine} ? $deployedEngines{$engine} : 0)."\n";
		$testEngines{$engine}->[1] -= defined $deployedEngines{$engine} ? $deployedEngines{$engine} : 0;
	}
	print encode "utf-8", "Total unused  memory: $deployment{remainingServerMemory}\n";
	print encode "utf-8", "Undeployed instances:\n";
	foreach my $engine (@engineList) {
		next unless $testEngines{$engine}->[1];
		print encode "utf-8", "$engine: $testEngines{$engine}->[1]\n";
	}
	%deployedEngines = ();
	%testEngines = %{dclone \%engines};
	%testServers = %{dclone \%servers};
}


sub deployServer {
	my $server = shift @serverList;

	&addEngine($server, $testServers{$server});
	
	foreach my $deployment (@{$deployedEngineIDs{$server}}) {
		foreach my $engine (@$deployment) {
			$deployment{$server}->{$engine} = 1;
			$testServers{$server} -= $testEngines{$engine}->[0];
			--$testEngines{$engine}->[1];
		}
		
		if (@serverList) {
			&deployServer();
		} else {
			my $remainingServerMemory;
			foreach my $server (keys %testServers) {
				foreach my $engine (@engineList) {
					$remainingServerMemory += $engines{$engine}->[0] if $deployment{$server}->{$engine};
				}
			}
			$deployment{remainingServerMemory} = $totalServerMemory - $remainingServerMemory;
			if ($deployment{remainingServerMemory} < $leastMemoryRemaining) {
				$leastMemoryRemaining = $deployment{remainingServerMemory};
				$leastMemoryDeployments = 1;
				push @deployments, dclone \%deployment;
			} elsif ($deployment{remainingServerMemory} == $leastMemoryRemaining) {
				++$leastMemoryDeployments;
				push @deployments, dclone \%deployment;
			}
			++$totalDeployments;
		}
		
		foreach my $engine (@$deployment) {
			$deployment{$server}->{$engine} = 0;
			$testServers{$server} += $testEngines{$engine}->[0];
			++$testEngines{$engine}->[1];
		}
		
		last if $leastMemoryDeployments >= 500;
	}
	
	unshift @serverList, $server;
}

sub addEngine {
	++$deployments;
	print STDERR "[$deployments]" unless $deployments % 500000;
	print STDERR "." unless $deployments % 10000;
	my $server = shift;
	my $leastUnusedMemory = shift;
	my $lastEngineID = shift;
	$lastEngineID = -1 unless defined $lastEngineID;
	my $availableMemory = $testServers{$server};

	foreach my $engineID (($lastEngineID+1)..$#engineList) {
		my $engine = $engineList[$engineID];
		next unless $testEngines{$engine}->[1] && $testEngines{$engine}->[0] <= $availableMemory;
		
		$deployment{$server}->{$engine} = 1;
		$testServers{$server} -= $testEngines{$engine}->[0];
		--$testEngines{$engine}->[1];
		if ($testServers{$server} < $leastUnusedMemory) {
			$leastUnusedMemory = $testServers{$server};
			$deployedEngineIDs{$server} = [[(grep {$deployment{$server}->{$_}} @engineList)]];
		} elsif ($testServers{$server} == $leastUnusedMemory) {
			push @{$deployedEngineIDs{$server}}, [(grep {$deployment{$server}->{$_}} @engineList)];
		}
		
		$leastUnusedMemory = &addEngine($server, $leastUnusedMemory, $engineID);
		
		$deployment{$server}->{$engine} = 0;
		$testServers{$server} += $testEngines{$engine}->[0];
		++$testEngines{$engine}->[1];
	}
	
	return $leastUnusedMemory;
}

sub isCompleteDeployment {
	my $undeployedMemory;
	my $minMemoryRequirement = $maxMemoryRequirement;
	my $undeployedEngines;
	foreach (@engineList) {
		unless ($deployedEngines{$_}) {
			my $engineMemory = $testEngines{$_}->[0];
			++$undeployedEngines;
			$undeployedMemory += $engineMemory;
			$minMemoryRequirement = $engineMemory if $engineMemory < $minMemoryRequirement;
		}
	}
	return ($undeployedEngines || 0, $undeployedMemory || 0, $minMemoryRequirement);
}

sub printDeployment {
	my ($undeployedEngines, $undeployedMemory, $minMemoryRequirement) = &isCompleteDeployment();
	print encode "utf-8", "\n";
	if ($undeployedEngines) {
		print encode "utf-8", "Undeployed engines ($undeployedEngines): ".join(", ", sort {$a cmp $b} grep {!$deployedEngines{$_}} @engineList)."\n";
		print encode "utf-8", "Undeployed memory: ${undeployedMemory}MB; Mininum memory requirement of undeployed engines: ${minMemoryRequirement}MB\n";
	} else {
		print encode "utf-8", "NO undeployed engines!\n";
	}
	foreach my $server (@serverList) {
		print encode "utf-8", "$server ($testServers{$server}MB):";
		foreach my $engine (sort {$a cmp $b} grep {$deployment{$server}->{$_}} keys %{$deployment{$server}}) {
			print encode "utf-8", "\t$engine";
		}
		print encode "utf-8", "\n";
	}
	my %serverListByLanguage;
	foreach my $server (@serverList) {
		print encode "utf-8", "\t\"$server\" => [";
		my $hasXX = 0;
		foreach my $engine (sort {$a cmp $b} grep {$deployment{$server}->{$_}} keys %{$deployment{$server}}) {
			print encode "utf-8", "\"$engine\",";
			$hasXX ||= $engine =~ /_.*-EN_.$/;
			my ($source, $target) = map {lc $_} $engine =~ /^.*?_(\w+)-(\w+)_.*?$/;
			$serverListByLanguage{$source}->{$target} = [] unless defined $serverListByLanguage{$source}->{$target};
			push @{$serverListByLanguage{$source}->{$target}}, $server;
		}
		print encode "utf-8", "\"$XXENEngine\"," if $hasXX;
		print encode "utf-8", "],\n";
	}
	print encode "utf-8", "((\n";
	foreach my $source (sort {$a cmp $b} keys %serverListByLanguage) {
		print encode "utf-8", "$source => {\n";
		foreach my $target (sort {$a cmp $b} keys %{$serverListByLanguage{$source}}) {
			print encode "utf-8", "\t$target => [\n";
			foreach my $server (sort {$a cmp $b} @{$serverListByLanguage{$source}->{$target}}) {
				print encode "utf-8", "\t\t\"$server\",\n";
			}
			print encode "utf-8", "\t],\n";
		}
		print encode "utf-8", "},\n";
	}
	print encode "utf-8", "))\n";
}



1;