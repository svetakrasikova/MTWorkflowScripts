#!/usr/bin/perl -ws
####################
#
# ©2012–2013 Autodesk Development Sàrl
# Created on 22 Nov 2012 by Ventsislav Zhechev
#
# ChangeLog
# v1.1		Modified on 25 Oct 2013 by Ventsislav Zhechev
# Now we read software data stored in bzip2-compressed files.
# Updated to use the latest folder structure of the software export.
#
# v1.0		Modified on 22 Nov 2012 by Ventsislav Zhechev
# Initial Version
#
####################

use strict;
use utf8;

use Encode qw/encode decode/;
use IO::Compress::Bzip2 qw/$Bzip2Error/;
use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;

our ($sourcePath, $outputPath);

die encode "utf-8", "Usage: $0 -sourcePath=… -outputPath=…\n"
unless defined $sourcePath &&  defined $outputPath;

opendir my $sources, $sourcePath
or die encode "utf-8", "Cannot read folder “$sourcePath”!\n";

my %data;
$/ = "\r\n";

my $counter = 0;

while (my $language = readdir($sources)) {
	next if $language =~ /^\./ || !-d "$sourcePath/$language";
	opendir my $source, "$sourcePath/$language"
	or die encode "utf-8", "Cannot read folder “$sourcePath/$language”!\n";

	while (my $product = readdir($source)) {
		next if $product =~ /^\./ || !-d "$sourcePath/$language/$product";
		opendir my $source, "$sourcePath/$language/$product"
		or die encode "utf-8", "Cannot read folder “$sourcePath/$language/$product”!\n";
		while (my $fileName = readdir($source)) {
			next if $fileName =~ /^\./ || -d "$sourcePath/$language/$product/$fileName";
			
			my $file = new IO::Uncompress::Bunzip2 "$sourcePath/$language/$product/$fileName"
			or die encode "utf-8", "Cannot read file “$sourcePath/$language/$product/$fileName”: $Bunzip2Error!\n";
			
#			my ($language) = $fileName =~ /^(...)/;
#			$language = lc $language;
			$data{$language} = [] unless defined $data{$language};
			
			while (my $line = decode "utf-8", scalar <$file>) {
				print STDERR "." unless ++$counter % 10000;
				print STDERR "($counter)" unless $counter % 100000;
				chomp $line;
				$line =~ s/\t//g;
				$line =~ s/\\r\\n/ /g;
				$line =~ s/\\[rnt]/ /g unless $line =~ /\\\w{2,}\\/ && $line =~ /[:\.]/;
				push @{$data{$language}}, "$line$product◊÷\n";
				#			push @{$data{$language}}, "$line\t$product\tSoftware\t2013\n";
			}
			
			close $file;
		}
		closedir $source;
	}

	closedir $source;

}

closedir $sources;

print STDERR "…… Read in a total of $counter segments.\n";

foreach my $language (keys %data) {
	my $file = new IO::Compress::Bzip2("$outputPath/$language.all.bz2")
	or die encode "utf-8", "Cannot write file “$outputPath/$language.all.bz2”: $Bzip2Error!\n";
	print $file encode "utf-8", "$_" foreach @{$data{$language}};
	close $file;
}




1;