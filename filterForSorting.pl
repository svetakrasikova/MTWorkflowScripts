#!/usr/bin/perl -ws
#####################
#
# ©2013–2014 Autodesk Development Sàrl
#
# Created on 05 Jun 2013 by Ventsislav Zhechev
#
# Changelog
# v0.3.6		Modified by Ventsislav Zhechev on 14 Jul 2014
# Added lists of stop-words for ES and IT.
#
# v0.3.5		Modified by Ventsislav Zhechev on 04 Jul 2014
# Updated the lists of stop-words for EN and FR.
# Added lists of stop-words for DE and RU.
#
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
cs => {
	"a" => 1, "aby" => 1, "bez" => 1, "by" => 1, "byl" => 1, "byla" => 1, "bylo" => 1, "byly" => 1, "být" => 1, "což" => 1, "dle" => 1, "do" => 1, "i" => 1, "je" => 1, "jej" => 1, "ji" => 1, "k" => 1, "každý" => 1, "kde" => 1, "kdy" => 1, "ke" => 1, "kolem" => 1, "kromě" => 1, "která" => 1, "které" => 1, "má" => 1, "na" => 1, "nebyl" => 1, "než" => 1, "nikdy" => 1, "nám" => 1, "nás" => 1, "ní" => 1, "o" => 1, "od" => 1, "okolo" => 1, "po" => 1, "pro" => 1, "při" => 1, "s" => 1, "se" => 1, "si" => 1, "tak" => 1, "to" => 1, "u" => 1, "v" => 1, "ve" => 1, "vně" => 1, "vám" => 1, "vás" => 1, "vše" => 1, "z" => 1, "za" => 1, "zda" => 1, "ze" => 1, "že" => 1, },
de => {
	"ab" => 1, "alle" => 1, "als" => 1, "am" => 1, "an" => 1, "anhand" => 1, "auch" => 1, "auf" => 1, "aufeinander" => 1, "aus" => 1, "außer" => 1, "bei" => 1, "beim" => 1, "bis" => 1, "da" => 1, "damit" => 1, "dann" => 1, "darin" => 1, "das" => 1, "dass" => 1, "dem" => 1, "den" => 1, "der" => 1, "des" => 1, "die" => 1, "diese" => 1, "diesen" => 1, "dieses" => 1, "durch" => 1, "ein" => 1, "eine" => 1, "einen" => 1, "einer" => 1, "eines" => 1, "es" => 1, "für" => 1, "haben" => 1, "hat" => 1, "her" => 1, "hier" => 1, "hinzu" => 1, "ich" => 1, "ihr" => 1, "ihre" => 1, "ihrem" => 1, "ihren" => 1, "im" => 1, "in" => 1, "indem" => 1, "ist" => 1, "je" => 1, "jedoch" => 1, "kann" => 1, "kein" => 1, "keine" => 1, "keinen" => 1, "mit" => 1, "nach" => 1, "nicht" => 1, "noch" => 1, "pro" => 1, "schon" => 1, "sehr" => 1, "sein" => 1, "sich" => 1, "sie" => 1, "sind" => 1, "um" => 1, "und" => 1, "viele" => 1, "vielen" => 1, "vieler" => 1, "vom" => 1, "von" => 1, "vor" => 1, "wenn" => 1, "werden" => 1, "wird" => 1, "wurde" => 1, "zu" => 1, "zum" => 1, "zur" => 1, "zurück" => 1, "über" => 1, },
en => {
	"a" => 1, "able" => 1, "about" => 1, "above" => 1, "after" => 1, "afterwards" => 1, "again" => 1, "against" => 1, "all" => 1, "almost" => 1, "alone" => 1, "along" => 1, "already" => 1, "also" => 1, "although" => 1, "always" => 1, "am" => 1, "an" => 1, "and" => 1, "any" => 1, "anyway" => 1, "anywhere" => 1, "are" => 1, "around" => 1, "as" => 1, "at" => 1, "avez" => 1, "be" => 1, "because" => 1, "been" => 1, "before" => 1, "being" => 1, "below" => 1, "between" => 1, "both" => 1, "but" => 1, "by" => 1, "can" => 1, "cannot" => 1, "could" => 1, "did" => 1, "do" => 1, "does" => 1, "doing" => 1, "down" => 1, "during" => 1, "each" => 1, "eight" => 1, "eighty" => 1, "eleven" => 1, "else" => 1, "except" => 1, "few" => 1, "fifteen" => 1, "fifty" => 1, "five" => 1, "for" => 1, "forty" => 1, "four" => 1, "fourteen" => 1, "from" => 1, "further" => 1, "get" => 1, "had" => 1, "has" => 1, "have" => 1, "having" => 1, "he" => 1, "her" => 1, "here" => 1, "herself" => 1, "him" => 1, "himself" => 1, "his" => 1, "how" => 1, "i" => 1, "if" => 1, "in" => 1, "instead" => 1, "into" => 1, "is" => 1, "it" => 1, "its" => 1, "itself" => 1, "many" => 1, "may" => 1, "me" => 1, "might" => 1, "more" => 1, "most" => 1, "my" => 1, "myself" => 1, "need" => 1, "needed" => 1, "nine" => 1, "ninety" => 1, "no" => 1, "non" => 1, "nor" => 1, "not" => 1, "now" => 1, "of" => 1, "off" => 1, "on" => 1, "once" => 1, "one" => 1, "only" => 1, "onto" => 1, "or" => 1, "other" => 1, "ought" => 1, "our" => 1, "ourselves" => 1, "out" => 1, "over" => 1, "own" => 1, "per" => 1, "pro" => 1, "same" => 1, "see" => 1, "seven" => 1, "shall" => 1, "she" => 1, "should" => 1, "six" => 1, "sixteen" => 1, "sixty" => 1, "so" => 1, "some" => 1, "such" => 1, "ten" => 1, "than" => 1, "that" => 1, "the" => 1, "their" => 1, "them" => 1, "themselves" => 1, "then" => 1, "there" => 1, "these" => 1, "they" => 1, "thirteen" => 1, "thirty" => 1, "this" => 1, "those" => 1, "three" => 1, "through" => 1, "to" => 1, "too" => 1, "twelve" => 1, "twenty" => 1, "two" => 1, "under" => 1, "unless" => 1, "until" => 1, "up" => 1, "upon" => 1, "versa" => 1, "very" => 1, "via" => 1, "want" => 1, "wanted" => 1, "was" => 1, "we" => 1, "were" => 1, "what" => 1, "when" => 1, "where" => 1, "whether" => 1, "which" => 1, "will" => 1, "while" => 1, "who" => 1, "whom" => 1, "why" => 1, "with" => 1, "within" => 1, "without" => 1, "would" => 1, "yet" => 1, "you" => 1, "your" => 1, "yours" => 1, "yourself" => 1, "yourselves" => 1, },
es => {
	"a" => 1, "al" => 1, "como" => 1, "con" => 1, "da" => 1, "dar" => 1, "de" => 1, "del" => 1, "el" => 1, "en" => 1, "es" => 1, "esta" => 1, "está" => 1, "esté" => 1, "ha" => 1, "haga" => 1, "han" => 1, "hay" => 1, "la" => 1, "las" => 1, "le" => 1, "lo" => 1, "los" => 1, "me" => 1, "mes" => 1, "ni" => 1, "no" => 1, "par" => 1, "para" => 1, "por" => 1, "que" => 1, "qué" => 1, "se" => 1, "si" => 1, "son" => 1, "su" => 1, "sus" => 1, "te" => 1, "un" => 1, "una" => 1, "unos" => 1, "y" => 1, },
fr => {
	"a" => 1, "ainsi" => 1, "alors" => 1, "après" => 1, "au" => 1, "aucuns" => 1, "auquel" => 1, "aussi" => 1, "autre" => 1, "aux" => 1, "auxquels" => 1, "auxquelles" => 1, "avant" => 1, "avec" => 1, "avoir" => 1, "bon" => 1, "car" => 1, "ce" => 1, "cela" => 1, "ces" => 1, "ceux" => 1, "chaque" => 1, "ci" => 1, "comme" => 1, "comment" => 1, "dans" => 1, "de" => 1, "début" => 1, "dedans" => 1, "dehors" => 1, "déjà" => 1, "depuis" => 1, "des" => 1, "deux" => 1, "devez" => 1, "deviez"=> 1, "devra" => 1, "devrait"=> 1, "devraient" => 1,"devrait" => 1, "devrez" => 1, "devront" => 1, "doit" => 1, "doivent" => 1, "donc" => 1, "dos" => 1, "droite" => 1, "du" => 1, "également" => 1, "elle" => 1, "elles" => 1, "en" => 1, "encore" => 1, "essai" => 1, "est" => 1, "et" => 1, "eu" => 1, "faisait" => 1, "faisaient" => 1, "fait" => 1, "faites" => 1, "fera" => 1, "ferez" => 1, "feront" => 1, "fois" => 1, "font" => 1, "force" => 1, "haut" => 1, "hors" => 1, "ici" => 1, "il" => 1, "ils" => 1, "je" => 1, "juste" => 1, "la" => 1, "là" => 1, "laquelle" => 1, "le" => 1, "lequel" => 1, "les" => 1, "lesquels" => 1, "lesquelles" => 1, "leur" => 1, "leurs" => 1, "lors" => 1, "lorsque" => 1, "ma" => 1, "maintenant" => 1, "mais" => 1, "mes" => 1, "mine" => 1, "moins" => 1, "mon" => 1, "mot" => 1, "même" => 1, "ne" => 1, "ni" => 1, "nommés" => 1, "non" => 1, "notre" => 1, "nous" => 1, "nouveaux" => 1, "ou" => 1, "où" => 1, "par" => 1, "parce" => 1, "parole" => 1, "pas" => 1, "personnes" => 1, "peut" => 1, "peu" => 1, "peuvent" => 1, "pièce" => 1, "plupart" => 1, "pour" => 1, "pourra" => 1, "pourrait" => 1, "pourraient" => 1, "pourrez" => 1, "pourriez" => 1, "pourront" => 1, "pourquoi" => 1, "pouvez" => 1, "presque" => 1, "puisse" => 1, "puissent" => 1, "puissiez" => 1, "quand" => 1, "que" => 1, "quel" => 1, "quelle" => 1, "quelles" => 1, "quels" => 1, "qui" => 1, "sa" => 1, "sans" => 1, "sauf" => 1, "se" => 1, "sera" => 1, "ses" => 1, "seulement" => 1, "si" => 1, "sien" => 1, "son" => 1, "soit" => 1, "soient" => 1, "sont" => 1, "souhait" => 1, "souhaitait" => 1, "souhaitaient" => 1, "souhaitent" => 1, "souhaitez" => 1, "souhaitiez" => 1, "sous" => 1, "soyez" => 1, "sur" => 1, "ta" => 1, "tandis" => 1, "tellement" => 1, "tels" => 1, "tes" => 1, "ton" => 1, "toujours" => 1, "tous" => 1, "tout" => 1, "trop" => 1, "très" => 1, "tu" => 1, "un" => 1, "une" => 1, "valeur" => 1, "vers" => 1, "veut" => 1, "voie" => 1, "voient" => 1, "voir" => 1, "voit" => 1, "vont" => 1, "votre" => 1, "voulez" => 1, "vouliez" => 1, "vous" => 1, "vu" => 1, "à" => 1, "ça" => 1, "étaient" => 1, "état" => 1, "été" => 1, "être" => 1, },
hu => {
	"a" => 1, "abban" => 1, "abból" => 1, "addig" => 1, "ahhoz" => 1, "ahogy" => 1, "ahol" => 1, "ahonnan" => 1, "ahová" => 1, "aki" => 1, "akkor" => 1, "akár" => 1, "alatt" => 1, "amely" => 1, "amelybe" => 1, "amelyben" => 1, "amelyhez" => 1, "ami" => 1, "amihez" => 1, "amit" => 1, "amíg" => 1, "arra" => 1, "az" => 1, "azok" => 1, "azonban" => 1, "azután" => 1, "azért" => 1, "bal" => 1, "bár" => 1, "csak" => 1, "de" => 1, "eddig" => 1, "egy" => 1, "egyszer" => 1, "egyéb" => 1, "együtt" => 1, "egész" => 1, "ehhez" => 1, "el" => 1, "első" => 1, "erre" => 1, "ez" => 1, "ezek" => 1, "ezer" => 1, "fel" => 1, "felett" => 1, "fontos" => 1, "ha" => 1, "harmadik" => 1, "hat" => 1, "hatodik" => 1, "helyett" => 1, "hetedik" => 1, "hogy" => 1, "hogyan" => 1, "három" => 1, "hét" => 1, "ide" => 1, "igen" => 1, "illetve" => 1, "ilyen" => 1, "is" => 1, "ismét" => 1, "jobb" => 1, "jobban" => 1, "jól" => 1, "keresztül" => 1, "ki" => 1, "kilencedik" => 1, "kétszer" => 1, "között" => 1, "le" => 1, "legalább" => 1, "lehet" => 1, "lehetséges" => 1, "lesz" => 1, "lett" => 1, "majdnem" => 1, "meg" => 1, "mert" => 1, "mi" => 1, "mialatt" => 1, "miatt" => 1, "milyen" => 1, "mind" => 1, "mindkét" => 1, "mint" => 1, "miután" => 1, "most" => 1, "második" => 1, "negyedik" => 1, "nekünk" => 1, "nem" => 1, "nyolcadik" => 1, "négy" => 1, "pedig" => 1, "rá" => 1, "részére" => 1, "saját" => 1, "soha" => 1, "sok" => 1, "szinte" => 1, "számára" => 1, "szét" => 1, "tehát" => 1, "teljes" => 1, "tizedik" => 1, "tovább" => 1, "továbbá" => 1, "ugyanaz" => 1, "utolsó" => 1, "után" => 1, "utána" => 1, "vagy" => 1, "valamennyi" => 1, "valamint" => 1, "van" => 1, "vissza" => 1, "volna" => 1, "által" => 1, "általában" => 1, "át" => 1, "én" => 1, "és" => 1, "ön" => 1, "önnek" => 1, "önt" => 1, "össze" => 1, "ötödik" => 1, "új" => 1, "újabb" => 1, },
it => {
	"a" => 1, "ad" => 1, "ai" => 1, "al" => 1, "alla" => 1, "che" => 1, "ci" => 1, "come" => 1, "con" => 1, "da" => 1, "dal" => 1, "de" => 1, "degli" => 1, "dei" => 1, "del" => 1, "della" => 1, "delle" => 1, "dello" => 1, "di" => 1, "e" => 1, "ed" => 1, "gli" => 1, "ha" => 1, "i" => 1, "il" => 1, "in" => 1, "la" => 1, "le" => 1, "lo" => 1, "negli" => 1, "nel" => 1, "nella" => 1, "non" => 1, "per" => 1, "se" => 1, "si" => 1, "sia" => 1, "sono" => 1, "su" => 1, "sugli" => 1, "sui" => 1, "sul" => 1, "sulla" => 1, "sulle" => 1, "sullo" => 1, "un" => 1, "una" => 1, "uno" => 1, "è" => 1, },
jp => {
	"ー" => 1, "これ" => 1, "それ" => 1, "あれ" => 1, "この" => 1, "その" => 1, "あの" => 1, "ここ" => 1, "そこ" => 1, "あそこ" => 1, "こちら" => 1, "どこ" => 1, "だれ" => 1, "なに" => 1, "なん" => 1, "何" => 1, "私" => 1, "貴方" => 1, "貴方方" => 1, "我々" => 1, "私達" => 1, "あの人" => 1, "あのかた" => 1, "彼女" => 1, "彼" => 1, "です" => 1, "あります" => 1, "おります" => 1, "います" => 1, "は" => 1, "が" => 1, "の" => 1, "に" => 1, "を" => 1, "で" => 1, "え" => 1, "から" => 1, "まで" => 1, "より" => 1, "も" => 1, "どの" => 1, "と" => 1, "し" => 1, "それで" => 1, "しかし" => 1, },
ko => {
	"가" => 1, "가서" => 1, "각" => 1, "각종" => 1, "같은" => 1, "같이" => 1, "거의" => 1, "것" => 1, "것과" => 1, "곧" => 1, "공동으로" => 1, "과" => 1, "관계가" => 1, "관계없이" => 1, "관련이" => 1, "관하여" => 1, "관한" => 1, "구" => 1, "그" => 1, "그래도" => 1, "그러나" => 1, "그러면" => 1, "그런" => 1, "그렇지" => 1, "그리고" => 1, "기준으로" => 1, "기타" => 1, "까지" => 1, "낼" => 1, "네" => 1, "넷" => 1, "년" => 1, "다른" => 1, "다섯" => 1, "다소" => 1, "다수" => 1, "다시" => 1, "다음" => 1, "다음에" => 1, "다음으로" => 1, "단지" => 1, "달려" => 1, "대로" => 1, "대하여" => 1, "대해" => 1, "동시에" => 1, "동안" => 1, "되는" => 1, "되어" => 1, "둘" => 1, "들" => 1, "들면" => 1, "등" => 1, "따라" => 1, "따라서" => 1, "따르는" => 1, "때" => 1, "때문에" => 1, "또" => 1, "또한" => 1, "로" => 1, "로부터" => 1, "를" => 1, "만큼" => 1, "많은" => 1, "매" => 1, "매번" => 1, "몇" => 1, "모" => 1, "모두" => 1, "및" => 1, "바로" => 1, "밖에" => 1, "반대로" => 1, "반드시" => 1, "부터" => 1, "비교적" => 1, "상대적으로" => 1, "셋" => 1, "수" => 1, "시각" => 1, "시작하여" => 1, "심지어" => 1, "아니라" => 1, "아니면" => 1, "아이" => 1, "안" => 1, "않기" => 1, "않도록" => 1, "않으면" => 1, "알" => 1, "앞에서" => 1, "약간" => 1, "어느" => 1, "어떠한" => 1, "어떤" => 1, "어떻게" => 1, "언제" => 1, "에" => 1, "에게" => 1, "에서" => 1, "여러분" => 1, "여부" => 1, "여섯" => 1, "여전히" => 1, "영" => 1, "예" => 1, "예를" => 1, "와" => 1, "외에" => 1, "외에도" => 1, "우선" => 1, "월" => 1, "위하여" => 1, "위해서" => 1, "으로" => 1, "을" => 1, "의" => 1, "의해" => 1, "의해서" => 1, "이" => 1, "이러한" => 1, "이렇게" => 1, "이로" => 1, "이르기까지" => 1, "이상" => 1, "이용하여" => 1, "이유는" => 1, "인" => 1, "인하여" => 1, "일" => 1, "일반적으로" => 1, "자" => 1, "자기" => 1, "자신" => 1, "잠시" => 1, "저" => 1, "저쪽" => 1, "전부" => 1, "전자" => 1, "정도의" => 1, "제" => 1, "제외하고" => 1, "조금" => 1, "좀" => 1, "중에서" => 1, "즉" => 1, "즉시" => 1, "쪽으로" => 1, "참" => 1, "첫번째로" => 1, "칠" => 1, "통하여" => 1, "팔" => 1, "퍽" => 1, "하고" => 1, "하기" => 1, "하나" => 1, "하면" => 1, "하지" => 1, "한" => 1, "할" => 1, "함께" => 1, "함으로써" => 1, "해도" => 1, "후" => 1, "훨씬" => 1, },
pl => {
	"i" => 1, "na" => 1, "o" => 1, "w" => 1, "z" => 1, }
ru => {
	"а" => 1, "без" => 1, "будет" => 1, "был" => 1, "было" => 1, "в" => 1, "вне" => 1, "во" => 1, "все" => 1, "вы" => 1, "для" => 1, "до" => 1, "его" => 1, "ее" => 1, "если" => 1, "еще" => 1, "же" => 1, "за" => 1, "и" => 1, "из" => 1, "или" => 1, "ими" => 1, "их" => 1, "к" => 1, "как" => 1, "ко" => 1, "ли" => 1, "между" => 1, "на" => 1, "над" => 1, "нам" => 1, "не" => 1, "нее" => 1, "ней" => 1, "нет" => 1, "ни" => 1, "о" => 1, "об" => 1, "обо" => 1, "они" => 1, "от" => 1, "по" => 1, "под" => 1, "при" => 1, "с" => 1, "со" => 1, "также" => 1, "таких" => 1, "такое" => 1, "тем" => 1, "то" => 1, "только" => 1, "у" => 1, "уже" => 1, "чего" => 1, "чем" => 1, "что" => 1, "этих" => 1, "это" => 1, "этом" => 1, },
);
my %internalStopWords = (
de => {},
en => {
	"able" => 1, "above" => 1, "always" => 1, "and" => 1, "are" => 1, "around" => 1, "as" => 1, "be" => 1, "being" => 1, "by" => 1, "can" => 1, "cannot" => 1, "could" => 1, "do" => 1, "does" => 1, "from" => 1, "go" => 1, "going" => 1, "have" => 1, "had" => 1, "has" => 1, "having" => 1, "if" => 1, "instead" => 1, "into" => 1, "is" => 1, "it" => 1, "its" => 1, "may"=> 1, "might"=> 1, "must" => 1, "my" => 1, "need" => 1, "needed" => 1, "not" => 1, "of" => 1, "one" => 1, "or" => 1, "our" => 1, "shall" => 1, "should" => 1, "than" => 1, "that" => 1, "their" => 1, "they" => 1, "to" => 1, "too" => 1, "under" => 1, "was" => 1, "we" => 1, "were" => 1, "will" => 1, "with" => 1, "would"=> 1, "yet" => 1, "you" => 1, "your" => 1, },
fr => {
	"a" => 1, "allait" => 1, "allaient" => 1, "allez" => 1, "alliez" => 1, "aura"=> 1, "aurait"=> 1, "auraient"=> 1, "auriez"=> 1, "auront"=> 1, "avait" => 1, "avaient" => 1, "avez" => 1, "aviez" => 1, "avoir" => 1, "ayant" => 1, "devra" => 1, "devront" => 1, "doit" => 1, doivent => 1, "est" => 1, "et" => 1, "était" => 1, "étaient" => 1, "étant" => 1, "été" => 1, "êtes" => 1, "étiez" => 1, "être" => 1, "eu" => 1, "ira" => 1, "irait" => 1, "iraient" => 1, "irez" => 1, "iriez" => 1, "iront" => 1, "ne" => 1, "non" => 1, "notre" => 1, "ont" => 1, "ou" => 1, "pas" => 1, "peut" => 1, "peuvent" => 1, "pourra" => 1, "pourraient" => 1, "pourrez" => 1, "pourriez"=> 1, "pourront" => 1, "pouvait" => 1, "pouvaient" => 1, "pouvez" => 1, "pouviez" => 1, "puisse" => 1, "puissent" => 1, "puissiez" => 1, "que" => 1, "sera" => 1, "serait" => 1, "seraient" => 1, "serez" => 1, "seront" => 1, "si" => 1, "soit" => 1, "soient" => 1,  "soyez" => 1, "sont" => 1, "va" => 1, "vers" => 1, "vont" => 1, },
jp => {},
ru => {},
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