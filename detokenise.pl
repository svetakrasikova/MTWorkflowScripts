#!/usr/bin/perl -w
#####################
#
# A utility to detokenise lines of text
#
# © 2010 Венцислав Жечев
# © 2011–2012 Autodesk Development Sàrl
#
# created  10 May 2010
# modified 04 Apr 2012
#
# Changelog
# v1.0.1
# Added detokenisation rules for Japanese, where no spaces should occur around parentheses and brackets.
# Added detokenisation rules for Japanese, where spaces should remain between tokens that consist entirely of Katakana characters.
# 
# v1.0
# Modified to be included in other Perl code in order to reduce the number of active Perl interpreters during regular operation.
#
# v0.6
# Corrected the handling of French end-of-sentence punctuation.
#
# v0.5
# Added Autodesk specific handling of ‘::’ and Asian languages.
#
# v0.4
# Fixed a bug in the detokenisation of parentheses, brackets and braces.
#
# v0.3
#
#####################

use strict;
use utf8;
#binmode(STDIN,  "utf8");
#binmode(STDOUT, "utf8");
#
#$| = 1;

sub initDetokeniser {
	
my $language = "en";
if ($_[0]) {
	$language = $_[0];
	$language =~ s/-.*$//;
	$language = lc $language;
#	$language = defined($prefixes{$language}) ? $language : "en";
}
print STDERR "Lanugage of operation: $language\n";

	return {language => $language};
}

#while(<STDIN>) {
#	my $line = $_;
#	chomp $line;
sub detokenise {
	my ($id, $line) = @_;
	
	#Try to handle quoted text.
	if ((() = $line =~ /(?: |^)\"(?: |$)/g) % 2 == 0) {
		my $count = 0;
		$line =~ s/(?: |^)\"(?: |$)/++$count % 2 != 0 ? ' ◊"◊' : '◊"◊ '/ge;
	}
	if (!($line =~ /\"/) && (() = $line =~ /(?: |^)\'(?: |$)/g) % 2 == 0) {
		my $count = 0;
		$line =~ s/(?: |^)\'(?: |$)/++$count % 2 != 0 ? " ◊'◊" : "◊'◊ "/ge;
	}
	
	# restoring colon character : in index entries with no trailing space
	$line =~ s/ :: /◊:◊/g;

	#Some puncutation is always attached.
	$line =~ s/ ([\.\,]+)([ ◊]|$)/◊$1◊$2/g;
	#‘:’, ‘;’, ‘!’, ‘?’ are attached with a non-breaking space in fr and directly otherwise.
	$line =~ s/ ([\:\;\!\?]+)([ ◊]|$)/$id->{language} eq "fr" ? "◊ $1◊$2" : "◊$1◊$2"/ge;
	
	#Closing double quotes usually attach to the previous string.
	$line =~ s/ ”([ ◊]|$)/◊”◊$1/g;
	#Except when they are used by mistake, which we can only detect at the beginning of the line.
	$line =~ s/^” /◊”◊/g;
	#Opening quotes always attach to the following string.
	$line =~ s/([ ◊]|^)([‘“]) /$1◊$2◊/g;
	
	if ($id->{language} eq "en" || $id->{language} eq "de") {
		#Reestablish contractions.
		$line =~ s/(?<=\p{IsAlnum}) ([\'’])(?=\w)/◊$1◊/g;
	} elsif ($id->{language} eq "fr" || $id->{language} eq "it") {
		#Reestablish contractions.
		$line =~ s/(?<=\w)([\'’]) (?=\p{IsAlnum})/◊$1◊/g;
	}
	
	#Attache closing quote to previous string.
	$line =~ s/ ’([ ◊]|$)/◊’◊$1/g;
	
	#Process parentheses and brackets.
	$line =~ s/([ ◊]|^)([\(\{\[])[ ◊]*/$1◊$2◊/g;
	$line =~ s/([\)\}\]])[ ◊]+([\(\{\[])/◊$1◊$2◊/g;
	$line =~ s/[ ◊]*([\)\}\]])([ ◊]|$)/◊$1◊$2/g;
	
	#Process meta tags.
	$line =~ s/(?: |^)\<(?: |$)/◊<◊/g;
	$line =~ s! /\>([ ◊]|$)!◊/>◊$1!g;
	$line =~ s/(?<=\p{IsAlnum})\= \"/◊=\"◊/g;
	$line =~ s/(=\"◊) (.*?) (\")/$1$2◊$3◊/g;
	

	$line =~ s/◊//g;

	# Korean : detokenization of particles
	if ($id->{language} eq "ko") {
		# single character particle
		$line=~ s/([a-zA-Z0-9]) ([을를가과나는도로에와은의이인]) /$1$2 /g;
		# multi-character particles
		$line=~ s/([a-zA-Z0-9]) (들은|으로|에게|에게는|에는|에도|에만|에서|에서나|에서나|에서는|에서도|에서만|에서보다|에서부터|에서와|에서와는|에서의|에서처럼|와는|와를|와에|와의|으로는|으로도|으로만|으로부터|으로서|의를|인데|인지|인지를|인지에|인지와|인지의) /$1$2 /g;
		# specific to numbers
		$line=~ s/([0-9]) ([개초차도일년월상분면층자]) /$1$2 /g;
		$line=~ s/([0-9]) (개의|비트|이면|단계를|가지|단계에서|부터|이고|까지|개를|인치|피트|번째|까지의|도로|단위|개가|이며|시간|자까지) /$1$2 /g;
		# 축 means "axis" - should collapse to preceeding axis name, typically like X Y Z or XY... but should not collapse in other cases
		$line=~ s/ ([a-zA-Z]{1,2}) (축) /$1$2 /g;
		# detokenize dual particles inputs
		$line=~ s/(을) (\(를\)) /$1$2 /g; # 을(를)
		$line=~ s/(이) (\(가\)) /$1$2 /g; # 이(가)
		$line=~ s/(은) (\(는\)) /$1$2 /g; # 은(는)
		$line=~ s/(과) (\(와\)) /$1$2 /g; # 과(와)
		$line=~ s/(로) (\(으로\)) /$1$2 /g; # 로(으로)
		$line=~ s/( \(으\)) (로) /$1$2 /g; # (으)로
	}
	
	# Japanese: detok
	if ($id->{language} =~ /^jp/) {
		#		print STDERR "Removing spaces from Japanese text: “$line”…";
		my $japanese = '[\p{Script:Hiragana}\p{Script:Katakana}\p{Block:Katakana_Phonetic_Extensions}\p{Block:CJK_Unified_Ideographs}\p{Block:CJK_Unified_Ideographs_Extension_A}\x{30FB}\x{30FC}]';
		my $katakana = '[\p{Script:Katakana}\p{Block:Katakana_Phonetic_Extensions}\x{30FB}\x{30FC}]';
		# Spaces should not be removed when between two fully Katakana tokens.
		$line =~ s/((?:^|[\s◊]+)$katakana{2,})\s+(?=$katakana{2,}(?:\s+|$))/$1◊/g;
		$line =~ s/(?<=$japanese)\s+(?=$japanese)//g;
		$line =~ s/◊/ /g;
		#		print STDERR "“$line”\n";
		$line =~ s/ +。/。/g;
		$line =~ s/ +、 +/、/g;
		$line =~ s/(?<=$japanese)\s*([([])/$1/g;
		$line =~ s/([)\]])\s*(?=$japanese)/$1/g;
	}
	
	# Chinese: detok
	if ($id->{language} =~ /^zh/) {
		$line=~ s/(?<=[\x{4E00}-\x{9FFF}])\s+(?=[\x{4E00}-\x{9FFF}])//g;
		$line=~ s/\s+([、，（）「」])\s+/$1/g;
		$line=~ s/\s([。？])/$1/g;
	}
	
	#Clean up.
#	$line =~ s/◊//g;
	$line =~ s/^\s+|\s+$//g;
	$line =~ s/\s{2,}/ /g;
#	print "$line\n";
	
	return $line;
}

1;