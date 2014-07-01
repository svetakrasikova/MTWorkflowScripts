#!/usr/bin/perl -ws
#####################
#
# ©2013 Autodesk Development Sàrl
#
# Created on 05 Jun 2013 by Ventsislav Zhechev
#
# Changelog
# v0.3.4		Modified by Ventsislav Zhechev on 08 Jul 2013
# Updated the lists of stop-words.
#
# v0.3.3		Modified by Ventsislav Zhechev on 05 Jul 2013
# The source and target languages are now passed as required command line arguments.
# Updated the lists of stop-words.
#
# v0.3.2		Modified by Ventsislav Zhechev on 27 Jun 2013
# Updated the lists of stop-words.
#
# v0.3.1		Modified by Ventsislav Zhechev on 26 Jun 2013
# Updated the lists of stop-words.
#
# v0.3			Modified by Ventsislav Zhechev on 20 Jun 2013
# Added code to check for segment-internal stop words.
# Added code to skip certain products.
# Added code to strip edge stop words (used for the target-language side).
#
# v0.2.1		Modified by Ventsislav Zhechev on 11 Jun 2013
# Now we have stop-word lists for both EN and FR and can check both source and target for stop words at segment edges.
#
# v0.2			Modified by Ventsislav Zhechev on 10 Jun 2013
# Added a list of stop words to check against the beginning and end of segments.
#
# v0.1			Modified by Ventsislav Zhechev on 05 Jun 2013
# First version.
#
#####################

use strict;
use utf8;

use Encode qw/encode decode/;

$| = 1;
my $separator = "◊";

our ($sourceLanguage, $targetLanguage);

die encode "utf-8", "Usage: $0 -sourceLanguage=… -targetLanguage=…\n"
unless defined $sourceLanguage && defined $targetLanguage;

my %stopWords = (
en => {
	"a" => 1, "able" => 1, "about" => 1, "above" => 1, "after" => 1, "afterwards" => 1, "again" => 1, "against" => 1, "all" => 1, "almost" => 1, "alone" => 1, "along" => 1, "already" => 1, "also" => 1, "although" => 1, "always" => 1, "am" => 1, "an" => 1, "and" => 1, "any" => 1, "anyway" => 1, "anywhere" => 1, "are" => 1, "as" => 1, "at" => 1, "avez" => 1, "be" => 1, "because" => 1, "been" => 1, "before" => 1, "being" => 1, "below" => 1, "between" => 1, "both" => 1, "but" => 1, "by" => 1, "can" => 1, "cannot" => 1, "could" => 1, "did" => 1, "do" => 1, "does" => 1, "doing" => 1, "down" => 1, "during" => 1, "each" => 1, "eight" => 1, "eighty" => 1, "eleven" => 1, "else" => 1, "few" => 1, "fifteen" => 1, "fifty" => 1, "five" => 1, "for" => 1, "forty" => 1, "four" => 1, "fourteen" => 1, "from" => 1, "further" => 1, "get" => 1, "had" => 1, "has" => 1, "have" => 1, "having" => 1, "he" => 1, "her" => 1, "here" => 1, "herself" => 1, "him" => 1, "himself" => 1, "his" => 1, "how" => 1, "i" => 1, "if" => 1, "in" => 1, "instead" => 1, "into" => 1, "is" => 1, "it" => 1, "its" => 1, "itself" => 1, "may" => 1, "me" => 1, "might" => 1, "more" => 1, "most" => 1, "my" => 1, "myself" => 1, "need" => 1, "needed" => 1, "nine" => 1, "ninety" => 1, "no" => 1, "non" => 1, "nor" => 1, "not" => 1, "now" => 1, "of" => 1, "off" => 1, "on" => 1, "once" => 1, "one" => 1, "only" => 1, "onto" => 1, "or" => 1, "other" => 1, "ought" => 1, "our" => 1, "ourselves" => 1, "out" => 1, "over" => 1, "own" => 1, "same" => 1, "see" => 1, "seven" => 1, "shall" => 1, "she" => 1, "should" => 1, "six" => 1, "sixteen" => 1, "sixty" => 1, "so" => 1, "some" => 1, "such" => 1, "ten" => 1, "than" => 1, "that" => 1, "the" => 1, "their" => 1, "them" => 1, "themselves" => 1, "then" => 1, "there" => 1, "these" => 1, "they" => 1, "thirteen" => 1, "thirty" => 1, "this" => 1, "those" => 1, "three" => 1, "through" => 1, "to" => 1, "too" => 1, "twelve" => 1, "twenty" => 1, "two" => 1, "under" => 1, "unless" => 1, "until" => 1, "up" => 1, "upon" => 1, "versa" => 1, "very" => 1, "via" => 1, "want" => 1, "wanted" => 1, "was" => 1, "we" => 1, "were" => 1, "what" => 1, "when" => 1, "where" => 1, "whether" => 1, "which" => 1, "will" => 1, "while" => 1, "who" => 1, "whom" => 1, "why" => 1, "with" => 1, "within" => 1, "without" => 1, "would" => 1, "yet" => 1, "you" => 1, "your" => 1, "yours" => 1, "yourself" => 1, "yourselves" => 1, },
fr => {
	"a" => 1, "ainsi" => 1, "alors" => 1, "après" => 1, "au" => 1, "aucuns" => 1, "auquel" => 1, "aussi" => 1, "autre" => 1, "aux" => 1, "auxquels" => 1, "auxquelles" => 1, "avant" => 1, "avec" => 1, "avoir" => 1, "bon" => 1, "car" => 1, "ce" => 1, "cela" => 1, "ces" => 1, "ceux" => 1, "chaque" => 1, "ci" => 1, "comme" => 1, "comment" => 1, "dans" => 1, "de" => 1, "début" => 1, "dedans" => 1, "dehors" => 1, "déjà" => 1, "depuis" => 1, "des" => 1, "deux" => 1, "devez" => 1, "deviez"=> 1, "devra" => 1, "devrait"=> 1, "devraient" => 1,"devrait" => 1, "devrez" => 1, "devront" => 1, "doit" => 1, "doivent" => 1, "donc" => 1, "dos" => 1, "droite" => 1, "du" => 1, "également" => 1, "elle" => 1, "elles" => 1, "en" => 1, "encore" => 1, "essai" => 1, "est" => 1, "et" => 1, "eu" => 1, "faisait" => 1, "faisaient" => 1, "fait" => 1, "faites" => 1, "fera" => 1, "ferez" => 1, "feront" => 1, "fois" => 1, "font" => 1, "force" => 1, "haut" => 1, "hors" => 1, "ici" => 1, "il" => 1, "ils" => 1, "je" => 1, "juste" => 1, "la" => 1, "là" => 1, "laquelle" => 1, "le" => 1, "lequel" => 1, "les" => 1, "lesquels" => 1, "lesquelles" => 1, "leur" => 1, "lors" => 1, "lorsque" => 1, "ma" => 1, "maintenant" => 1, "mais" => 1, "mes" => 1, "mine" => 1, "moins" => 1, "mon" => 1, "mot" => 1, "même" => 1, "ni" => 1, "nommés" => 1, "notre" => 1, "nous" => 1, "nouveaux" => 1, "ou" => 1, "où" => 1, "par" => 1, "parce" => 1, "parole" => 1, "pas" => 1, "personnes" => 1, "peut" => 1, "peu" => 1, "peuvent" => 1, "pièce" => 1, "plupart" => 1, "pour" => 1, "pourra" => 1, "pourrait" => 1, "pourraient" => 1, "pourrez" => 1, "pourriez" => 1, "pourront" => 1, "pourquoi" => 1, "pouvez" => 1, "presque" => 1, "puisse" => 1, "puissent" => 1, "puissiez" => 1, "quand" => 1, "que" => 1, "quel" => 1, "quelle" => 1, "quelles" => 1, "quels" => 1, "qui" => 1, "sa" => 1, "sans" => 1, "sauf" => 1, "ses" => 1, "seulement" => 1, "si" => 1, "sien" => 1, "son" => 1, "soit" => 1, "soient" => 1, "sont" => 1, "souhait" => 1, "souhaitait" => 1, "souhaitaient" => 1, "souhaitent" => 1, "souhaitez" => 1, "souhaitiez" => 1, "sous" => 1, "soyez" => 1, "sur" => 1, "ta" => 1, "tandis" => 1, "tellement" => 1, "tels" => 1, "tes" => 1, "ton" => 1, "toujours" => 1, "tous" => 1, "tout" => 1, "trop" => 1, "très" => 1, "tu" => 1, "un" => 1, "une" => 1, "valeur" => 1, "vers" => 1, "veut" => 1, "voie" => 1, "voient" => 1, "voir" => 1, "voit" => 1, "vont" => 1, "votre" => 1, "voulez" => 1, "vouliez" => 1, "vous" => 1, "vu" => 1, "à" => 1, "ça" => 1, "étaient" => 1, "état" => 1, "été" => 1, "être" => 1, },
jp => {
	"ー" => 1, "これ" => 1, "それ" => 1, "あれ" => 1, "この" => 1, "その" => 1, "あの" => 1, "ここ" => 1, "そこ" => 1, "あそこ" => 1, "こちら" => 1, "どこ" => 1, "だれ" => 1, "なに" => 1, "なん" => 1, "何" => 1, "私" => 1, "貴方" => 1, "貴方方" => 1, "我々" => 1, "私達" => 1, "あの人" => 1, "あのかた" => 1, "彼女" => 1, "彼" => 1, "です" => 1, "あります" => 1, "おります" => 1, "います" => 1, "は" => 1, "が" => 1, "の" => 1, "に" => 1, "を" => 1, "で" => 1, "え" => 1, "から" => 1, "まで" => 1, "より" => 1, "も" => 1, "どの" => 1, "と" => 1, "し" => 1, "それで" => 1, "しかし" => 1, },
);
my %internalStopWords = (
en => {
	"able" => 1, "above" => 1, "always" => 1, "and" => 1, "are" => 1, "as" => 1, "be" => 1, "being" => 1, "by" => 1, "can" => 1, "cannot" => 1, "could" => 1, "do" => 1, "does" => 1, "from" => 1, "go" => 1, "going" => 1, "have" => 1, "had" => 1, "has" => 1, "having" => 1, "if" => 1, "instead" => 1, "into" => 1, "is" => 1, "it" => 1, "its" => 1, "may"=> 1, "might"=> 1, "must" => 1, "my" => 1, "need" => 1, "needed" => 1, "not" => 1, "of" => 1, "one" => 1, "or" => 1, "our" => 1, "shall" => 1, "should" => 1, "than" => 1, "that" => 1, "their" => 1, "they" => 1, "to" => 1, "too" => 1, "under" => 1, "was" => 1, "we" => 1, "were" => 1, "will" => 1, "with" => 1, "would"=> 1, "yet" => 1, "you" => 1, "your" => 1, },
fr => {
	"a" => 1, "allait" => 1, "allaient" => 1, "allez" => 1, "alliez" => 1, "aura"=> 1, "aurait"=> 1, "auraient"=> 1, "auriez"=> 1, "auront"=> 1, "avait" => 1, "avaient" => 1, "avez" => 1, "aviez" => 1, "avoir" => 1, "ayant" => 1, "devra" => 1, "devront" => 1, "doit" => 1, doivent => 1, "est" => 1, "et" => 1, "était" => 1, "étaient" => 1, "étant" => 1, "été" => 1, "êtes" => 1, "étiez" => 1, "être" => 1, "eu" => 1, "ira" => 1, "irait" => 1, "iraient" => 1, "irez" => 1, "iriez" => 1, "iront" => 1, "ne" => 1, "ont" => 1, "ou" => 1, "pas" => 1, "peut" => 1, "peuvent" => 1, "pourra" => 1, "pourraient" => 1, "pourrez" => 1, "pourriez"=> 1, "pourront" => 1, "pouvait" => 1, "pouvaient" => 1, "pouvez" => 1, "pouviez" => 1, "puisse" => 1, "puissent" => 1, "puissiez" => 1, "que" => 1, "sera" => 1, "serait" => 1, "seraient" => 1, "serez" => 1, "seront" => 1, "si" => 1, "soit" => 1, "soient" => 1,  "soyez" => 1, "sont" => 1, "va" => 1, "vers" => 1, "vont" => 1, },
jp => {},
);

my %productFilter = (
	"copyright" => 1, "ecs" => 1, "n/a" => 1, "news" => 1, "optimization" => 1, "packaging" => 1, "smart blank to delete" => 1, 
);

sub hasEdgeStopWords {
	my $language = shift;
	my ($first, $last) = $_[0] =~ /^([\w-]+?)(?= |$)(?:.*?(?<= )([\w-]+)?+)?$/;
	$last ||= $first;
	if (defined $stopWords{$language}->{$first}) {
		++$stopWords{$language}->{$first};
		return 1;
	} else {
		if ($last ne $first && defined $stopWords{$language}->{$last}) {
			++$stopWords{$language}->{$last};
			return 1;
		} else {
			return 0;
		}
	}
}

sub discardEdgeStopWords {
	my $language = shift;
	my @segment = split ' ', shift;
	while (@segment && defined $stopWords{$language}->{$segment[0]}) {
		++$stopWords{$language}->{$segment[0]};
		shift @segment;
	}
	while (@segment && defined $stopWords{$language}->{$segment[-1]}) {
		++$stopWords{$language}->{$segment[-1]};
		pop @segment;
	}
	return @segment ? join ' ', @segment : '';
}

sub hasInternalStopWords {
	my $language = shift;
	my $segment = shift;
	foreach my $stopWord (keys %{$internalStopWords{$language}}) {
		return 1 if $segment =~ /\Q$stopWord/;
	}
	return 0;
}

while (<>) {
#	print STDERR "_" unless ($.%10000);
	unless ($.%100000) {
		print STDERR ".";
		print STDERR "$." unless $.%1000000;
	}
	chomp;
	my $line = decode "utf-8", $_;
	next unless $line =~/^(?:\p{IsAlNum}{0,2}\p{IsAlpha}++\p{IsAlNum}{0,2}$separator[\w\/]+ (?:(?:[\w-]+?$separator[\w\/]+ )*?\p{IsAlNum}{0,2}\p{IsAlpha}++\p{IsAlNum}{0,2}$separator[\w\/]+ )?\|\|\| ){2}/;
	next if $line =~ /^\p{IsAlNum}*\d+\p{IsAlNum}*$separator[\w\/]+ \|\|\|/;
	next if $line =~ /\|\|\| \p{IsAlNum}*\d+\p{IsAlNum}*$separator[\w\/]+ \|/;
	my $product = "";
	$line =~ s/$separator(.*?)(?= )/$product ||= $1; ""/ge;
	next if defined $productFilter{$product};
	$line =~ s/(?<=\| )((?:-?\d+(?:(?:\.\d+)?(?:[Ee]-\d+)?)? ){4})(?= ?2\.718)/my $temp = $1; $temp =~ s! ! | !g; $temp/e;
	my ($source, $target) = $line =~ /^(.*?) \|\|\| (.*?)(?= \|\|\|)/;
	next if &hasEdgeStopWords($sourceLanguage, $source);# || &hasEdgeStopWords($targetLanguage, $target);
	next if &hasInternalStopWords($sourceLanguage, $source);
	next if length $source < 3;
	my $newTarget = &discardEdgeStopWords($targetLanguage, $target);
	if ($newTarget eq '') {
		next;
	} else {
		$line =~ s/^(.*? \|\|\| )(.*?)(?= \|\|\|)/$1$newTarget/;
	}
	next if $line =~ /(?:^|\|\|\| )(?:[0-9a-f]{2,4} )+(?:\Qhex\E )?\|\|\|/;
	print encode "utf-8", "$line | $product\n";
}


print STDERR "\n";
print STDERR "Used stopwords for $sourceLanguage: ".join(", ", map {encode "utf-8", $_} grep {$stopWords{$sourceLanguage}->{$_} > 1} sort {$a cmp $b} keys %{$stopWords{$sourceLanguage}})."\n";
print STDERR "Used stopwords for $targetLanguage: ".join(", ", map {encode "utf-8", $_} grep {$stopWords{$targetLanguage}->{$_} > 1} sort {$a cmp $b} keys %{$stopWords{$targetLanguage}})."\n";



1;