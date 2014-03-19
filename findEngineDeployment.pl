#!/usr/bin/perl -ws
#
# ©2012–2014 Autodesk Development Sàrl
# Created by Ventsislav Zhechev on 18 Dec 2012
#
# Version history
# v0.5.2	Last modified on 19 Mar 2014 by Ventsislav Zhechev
# Updated the status output.
#
# v0.5.1	Last modified on 17 Mar 2014 by Ventsislav Zhechev
# Added an accounting of the number of deployed instances to allow shutting down operation as soon as a full deployment is found.
# Rearranged the deployment details output order.
#
# v0.5		Last modified on 14 Mar 2014 by Ventsislav Zhechev
# Modified to only store progressively better deployments (i.e. leaving less and less memory unused).
# Execution is stopped after a maximum of 500 maximal deployments are found.
# Updated the statistics output after execution.
# Significantly optimised the engine placement algorithm by cutting off bad branches early.
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
#Sort the servers based on user preference and calculate the total server memory
my @serverList = grep {$totalServerMemory += $servers{$_}} sort {($servers{$a} <=> $servers{$b})*$serverOrder || $a cmp $b} keys %servers;
my $totalInstances;
#This engine order is necessary to help optimise the deployment process
my @engineList = grep {$totalInstances += $engines{$_}->[1]} sort {($engines{$a}->[0] <=> $engines{$b}->[0]) || $a cmp $b} keys %engines;
#print STDERR "We have $totalInstances total instances to deploy.\n";

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

my $remainingServerMemory = $totalServerMemory;
print encode "utf-8", "Total deployment attempts: $deployments\n";
print encode "utf-8", "Distinct deployments found: $totalDeployments\n";
print encode "utf-8", "Distinct deployments stored: ".scalar(@deployments)."\n";
print encode "utf-8", "Distinct maximal deployments: $leastMemoryDeployments\n";
foreach my $deployment (sort {$a->{remainingServerMemory} <=> $b->{remainingServerMemory}} @deployments) {
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
	print encode "utf-8", "Total unused  memory: $deployment{remainingServerMemory}\n";
	print encode "utf-8", "Deployed instances per engine:\n";
	foreach my $engine (sort {$a cmp $b} @engineList) {
		print encode "utf-8", "$engine: ".(defined $deployedEngines{$engine} ? $deployedEngines{$engine} : 0)."\n";
		$testEngines{$engine}->[1] -= defined $deployedEngines{$engine} ? $deployedEngines{$engine} : 0;
	}
	print encode "utf-8", "Undeployed instances:\n" if @engineList ~~ sub { $testEngines{$_[0]}->[1] };
	foreach my $engine (grep {$testEngines{$_}->[1]} @engineList) {
		print encode "utf-8", "$engine: $testEngines{$engine}->[1]\n";
	}
	&printDeployment();
	%deployedEngines = ();
	%testEngines = %{dclone \%engines};
	%testServers = %{dclone \%servers};
}


sub deployServer {
	#Try to deploy engines on a server
	my $server = shift @serverList;

	#Fill the server with engines
	&addEngine($server, $testServers{$server});
	
	my $isFullDeployment = 0;
	#Consider in order all best engine distributions for the server
	foreach my $deployment (@{$deployedEngineIDs{$server}}) {
		#As we haven’t stored the actual deployment lattice, we have to make sure we don’t produce illegal deployments
		next if @$deployment ~~ sub { $testEngines{$_[0]}->[1] <= 0 };
		#Setup the environment to indicate that we are investigating a particular deployment
		foreach my $engine (@$deployment) {
			$deployment{$server}->{$engine} = 1;
			$testServers{$server} -= $testEngines{$engine}->[0];
			--$testEngines{$engine}->[1];
			--$totalInstances;
		}
		$deployment{remainingServerMemory} += $testServers{$server};
		
		#Check if there are servers left
		if (@serverList) {
			#Continue deployment on the next server if it could produce a better result
			&deployServer() unless $deployment{remainingServerMemory} > $leastMemoryRemaining;
		} else {
			#We've handled all servers. Now we need to check if the resulting deployment needs to be stored
			if ($deployment{remainingServerMemory} < $leastMemoryRemaining) {
				$leastMemoryRemaining = $deployment{remainingServerMemory};
				$leastMemoryDeployments = 1;
				push @deployments, dclone \%deployment;
				$isFullDeployment = $totalInstances == 0;
				print STDERR "Upgrading to ${leastMemoryRemaining}MB remaining and $totalInstances instances left to deploy.\n";
			} elsif ($deployment{remainingServerMemory} == $leastMemoryRemaining) {
				++$leastMemoryDeployments;
				push @deployments, dclone \%deployment;
				print STDERR "$leastMemoryDeployments deployments with ${leastMemoryRemaining}MB remaining and $totalInstances instances left to deploy.\n" if $leastMemoryDeployments > 400;
			}
			++$totalDeployments;
		}
		
		#Backtrack
		$deployment{remainingServerMemory} -= $testServers{$server};
		foreach my $engine (@$deployment) {
			$deployment{$server}->{$engine} = 0;
			$testServers{$server} += $testEngines{$engine}->[0];
			++$testEngines{$engine}->[1];
			++$totalInstances;
		}
		
		#Put an upper limit on the number of best deployments
		#Stop processing after finding a full deployment
		last if $leastMemoryDeployments >= 500 || $isFullDeployment;
	}
	
	#Backtrack
	unshift @serverList, $server;
}

sub addEngine {
	#Progress dots
	++$deployments;
	print STDERR "[$deployments]" unless $deployments % 500000;
	print STDERR "." unless $deployments % 10000;
	
	my $server = shift;
	my $leastUnusedMemory = shift;
	my $lastEngineID = shift;
	$lastEngineID = -1 unless defined $lastEngineID;
	my $availableMemory = $testServers{$server};

	#Go through the available engines
	foreach my $engineID (($lastEngineID+1)..$#engineList) {
		my $engine = $engineList[$engineID];
		#Engines are sorted by increasing memory, so no further engine could fit and we can cut the branch
		last if $testEngines{$engine}->[0] > $testServers{$server};
		next unless $testEngines{$engine}->[1];
		
		#Indicate that we are using the engine for deployment
		$deployment{$server}->{$engine} = 1;
		$testServers{$server} -= $testEngines{$engine}->[0];
		--$testEngines{$engine}->[1];
		--$totalInstances;
		
		#Store the current deployment if necessary
		if ($testServers{$server} < $leastUnusedMemory) {
			$leastUnusedMemory = $testServers{$server};
			$deployedEngineIDs{$server} = [[(grep {$deployment{$server}->{$_}} @engineList)]];
		} elsif ($testServers{$server} == $leastUnusedMemory) {
			push @{$deployedEngineIDs{$server}}, [(grep {$deployment{$server}->{$_}} @engineList)];
		}
		
		#Try to add another engine—check if there are other engines and if any could fit in the remaining space
		$leastUnusedMemory = &addEngine($server, $leastUnusedMemory, $engineID) if $engineID < $#engineList && $totalInstances > 0 && $testServers{$server} >= $testEngines{$engineList[$engineID + 1]}->[0];
		
		#Backtrack
		$deployment{$server}->{$engine} = 0;
		$testServers{$server} += $testEngines{$engine}->[0];
		++$testEngines{$engine}->[1];
		++$totalInstances;
	}
	
	return $leastUnusedMemory;
}

sub isCompleteDeployment {
	my $undeployedMemory;
	my $minMemoryRequirement = $maxMemoryRequirement;
	my $undeployedEngines;
	foreach (grep {!$deployedEngines{$_}} @engineList) {
		my $engineMemory = $testEngines{$_}->[0];
		++$undeployedEngines;
		$undeployedMemory += $engineMemory;
		$minMemoryRequirement = $engineMemory if $engineMemory < $minMemoryRequirement;
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