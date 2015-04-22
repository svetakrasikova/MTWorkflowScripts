#!/usr/local/bin/perl -ws

package AOTPLanguageCodes;

use strict;
use utf8;

# Target language codes taken from https://git.autodesk.com/LocalizationServices/central-repository/blob/master/src/main/scala/com/autodesk/ls/cr/consts/LanguageConsts.scala
my %targetLanguageCode = (
	"cs"						=> "ces-CZ",
	"czech"						=> "ces-CZ",
	"da"						=> "dan-DK",
	"danish"					=> "dan-DK",
	"de"						=> "deu-DE",
	"german"					=> "deu-DE",
	"en"						=> "eng-US",
	"en_us"						=> "eng-US",
	"en-us"						=> "eng-US",	
	"english"					=> "eng-US",
	"en_gb"						=> "eng-GB",
	"en-gb"						=> "eng-GB",
	"english_uk"				=> "eng-GB",
	"english uk"				=> "eng-GB",
	"english (united kingdom)"	=> "eng-GB",
	"es"						=> "spa-ES",
	"spanish"					=> "spa-ES",
	"fi"						=> "fin-FI",
	"finnish"					=> "fin-FI",
	"fr"						=> "fra-FR",
	"french"					=> "fra-FR",
	"hu"						=> "hun-HU",
	"hungarian"					=> "hun-HU",
	"it"						=> "ita-IT",
	"italian"					=> "ita-IT",
	"jp"						=> "jpn-JP",
	"japanese"					=> "jpn-JP",
	"ko"						=> "kor-KR",
	"korean"					=> "kor-KR",
	"nl"						=> "nld-NL",
	"dutch_netherlands"			=> "nld-NL",
	"dutch netherlands"			=> "nld-NL",
	"dutch (netherlands)"		=> "nld-NL",
	"no"						=> "nor-NO",
	"norwegian"					=> "nor-NO",
	"norwegian (bokmal)"		=> "nor-NO",
	"pl"						=> "pol-PL",
	"polish"					=> "pol-PL",
	"pt_br"						=> "por-BR",
	"pt-br"						=> "por-BR",
	"brazilian_portuguese"		=> "por-BR",
	"brazilian portuguese"		=> "por-BR",
	"portuguese (brazil)"		=> "por-BR",
	"portuguese"				=> "por-BR",
	"portuguese (portugal)"		=> "por-BR",
	"ru"						=> "rus-RU",
	"russian"					=> "rus-RU",
	"sv"						=> "swe-SE",
	"swedish"					=> "swe-SE",
	"tr"						=> "tur-TR",
	"turkish"					=> "tur-TR",
	"vi"						=> "vie-VN",
	"vietnamese"				=> "vie-VN",
	"zh_hans"					=> "zho-CN",
	"zh-hans"					=> "zho-CN",
	"simplified_chinese"		=> "zho-CN",
	"simplified chinese"		=> "zho-CN",
	"chinese (prc)"				=> "zho-CN",
	"zh_hant"					=> "zho-TW",
	"zh-hant"					=> "zho-TW",
	"traditional_chinese"		=> "zho-TW",
	"traditional chinese"		=> "zho-TW",
	"chinese (taiwan)"			=> "zho-TW",
);

# Maps language codes accepted by the MT Info Service
# to default AOTP language codes.
#
# Invalid language codes are returned unchanged.
sub get {
	my $sourceLanguageCode = $_[0]; # first parameter passed to getAOTPLanguageCode: a language code accepted by the MT Info Service
	if (exists($targetLanguageCode{$sourceLanguageCode})) {
		return $targetLanguageCode{$sourceLanguageCode};
	} else {
		return $sourceLanguageCode;
	}
}