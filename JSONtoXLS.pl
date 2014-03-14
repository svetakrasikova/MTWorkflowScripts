#!/usr/bin/perl -ws
#####################
#
# ©2013 Autodesk Development Sàrl
#
# Created on 19 Jun 2013 by Ventsislav Zhechev
# 
# Used specifically to convert terminology-extraction JSON output to Excel format to be used by translators.
#
# Changelog
# v0.1.1		Modified by Ventsislav Zhechev on 11 Jul 2013
# Added a check for the presence of the required command-line parameters.
#
# v0.1			Modified by Ventsislav Zhechev on 19 Jun 2013
# First version.
#
#####################

use strict;
use utf8;

use Encode qw/encode decode/;
use JSONY;
use Spreadsheet::Wright;

our ($inputFile, $outputFile);
die encode "utf-8", "Usage: $0 -inputFile=… -outputFile=…\n"
unless defined $inputFile && defined $outputFile;

my $jsonData;
{ local $/ = undef;
	open my $input, $inputFile
	or die "Cannot read file “$inputFile”!\n";
	$jsonData = JSONY->new->load(decode "utf-8", scalar <$input>);
	close $input;
}

my $output = Spreadsheet::Wright->new(
	file => $outputFile,
	format => 'xls',
	sheet => 'Revit',
);

$output->addrow({header => 1, content => ['Term', 'Translation', 'Scope', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context', 'Context']});


foreach my $term (sort {lc $a cmp lc $b} keys %$jsonData) {
	my @row = @{$jsonData->{$term}->{context}};
	unshift @row, ($term, undef, $jsonData->{$term}->{newto});
	$output->addrow(@row);
}


$output->close();


1;