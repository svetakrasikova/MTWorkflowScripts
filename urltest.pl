#!/usr/bin/perl -ws
####################
#
# ©2012–2013 Autodesk Development Sàrl
# Created on 14 Nov 2012 by Ventsislav Zhechev
#
# ChangeLog
# v0.2	Modified on 08 Jan 2013
# Added a parameter for the URL file.
# Added a check for the presence of the required command-line parameter.
#
# v0.1
# Initial version
#
####################


use strict;
use utf8;

#use re 'debug';

use Encode qw/encode decode/;

our ($targetLanguage, $URLFile);

die encode "utf-8", "Usage: $0 -URLFile=… -targetLanguage=…\nThen enter one source URL per line and finish with ^D\n"
unless defined $URLFile && defined $targetLanguage;

my @data;

my %urls;
eval `cat $URLFile`;

#$/ = encode "utf-8", "◊÷\n";

while (my $l = decode "utf-8", scalar <STDIN>) {
	chomp $l;
	($l) = split //, $l;
#	(undef, $l) = split //, $l;
	push @data, "$l\n";
}


&matchURLs($targetLanguage, \@data);
#print "{translate => 5149, targetLanguage => ru}\n";
#print encode "utf-8", "$_" foreach (@data);
foreach (@data) {
	print encode "utf-8", "$_" if //;
}

sub matchURLs {
	my ($targetLanguage, $data) = @_;
	local $" = "";

	for (my $id = 0; $id < @$data; ++$id) {
		next unless $data->[$id] =~ m!\.\p{IsAlnum}+/! || $data->[$id] =~ m!:/! || $data->[$id] =~ m!@(?=\p{IsAlnum}+\.)! || $data->[$id] =~ /(?:^|\W)\p{IsAlnum}+\.[\p{IsAlnum}\.]+\.\p{IsAlpha}+(?=\W|$)/;

		my @urls;
		$data->[$id] =~ s/(^|[\s◊}]+)([\p{IsAlnum}(\[<\\\/])((?:[^ \\\/{]++[\\\/]++)+[^ \\\/{]*)(?!\{)([*\$\p{IsAlnum}>)\/\\>\]])(?=[\p{Punctuation}\s{◊]+|$)/
			my ($fs, $b, $d, $e) = ($1, $2, $3, $4);
			if ($b eq "(") {
				$b = "◊(◊ ";
			} else {
				$d="$b$d";
				$b="";
			}
			if ($e eq ")") {
				$e = " ◊)◊";
			} else {
				$d="$d$e";
				$e="";
			}
			push @urls, $d if $d =~ m![:\.]!;
			$d = "$b$d$e";
			$d =~ s!([._\/\\:*+?=<>\[\](){}-])!◊$1◊!g if $d =~ m![\\\/]!;
			
			"$fs$d"
		/ge;
		
		$data->[$id] =~ s/(^|\W)(\p{IsAlnum}+\.[\p{IsAlnum}\.]+\.\p{IsAlpha}{2,3})(?=\W|$)/push @urls, $2; "$1◊$2◊"/ge;
		$data->[$id] =~ s/(^|\W)(\p{IsAlnum}+[\p{IsAlnum}\.]+\@[\p{IsAlnum}\.]+\.\p{IsAlpha}+)(?=\W|$)/push @urls, $2; "$1◊$2◊"/ge;
			
		@urls = %{{map {$_ => $urls{$_}->{$targetLanguage}} grep {defined $urls{$_}->{$targetLanguage}} @urls}};
		$data->[$id] =~ s/◊//g;
		$data->[$id] =~ s/\n$/@urls\n/ if @urls;
	}
}






1;