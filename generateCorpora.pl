#!/usr/bin/perl -ws
#
# ©2013–2014 Autodesk Development Sàrl
# Created on 14 Jan 2013 by Ventsislav Zhechev
#
# ChangeLog
# v0.3		Modified on 12 Sep 2014 by Ventsislav Zhechev
# Disabled the aggregate output of ENU segments.
#
# v0.2.10	Modified on 12 Sep 2014 by Ventsislav Zhechev
# Updated the list of product mappings.
#
# v0.2.9	Modified on 01 Jul 2014 by Ventsislav Zhechev
# Updated the list of product mappings.
#
# v0.2.8	Modified on 25 Apr 2014 by Ventsislav Zhechev
# Updated to exclude segments where the target contains the ‘###’ transaltor marker.
#
# v0.2.7	Modified on 25 Apr 2014 by Ventsislav Zhechev
# Updated to use augmented PT* data for PT-PT.
#
# v0.2.6	Modified on 06 Apr 2014 by Ventsislav Zhechev
# Updated the list of product mappings.
# Optimised the processing of ENU segments by submitting them in batches of 500 for printing.
#
# v0.2.5	Modified on 03 Jan 2014 by Ventsislav Zhechev
# Updated the list of product mappings.
#
# v0.2.4	Modified on 28 Oct 2013 by Ventsislav Zhechev
# Updated the list of languages and content locations.
# Updated the list of product mappings.
#
# v0.2.3	Modified on 05 Jun 2013 by Ventsislav Zhechev
# Added a product mapping for FRA
#
# v0.2.2	Modified on 24 May 2013 by Ventsislav Zhechev
# Fixed a bug to properly handle segments without product information.
#
# v0.2.1	Modified on 23 May 2013 by Ventsislav Zhechev
# Fixed a bug related to IO::Compress::Bzip2 not being thread-safe.
# Significantly reduced the number of regex checks.
#
# v0.2		Modified on 22 May 2013 by Ventsislav Zhechev
# As individual languages are independent, they are now processed in parallel.
# The product name/code is now added to the end of the segments. This can be utilised during training as necessary.
# ENU output is processed in a separate thread to remove the bottleneck on bzip2 compression of a single stream.
#
# v0.1.2	Modified on 25 Jan 2013 by Ventsislav Zhechev
# Added a fix to treat line tabulation (\N{U+000B}) as white space. This is done by looking for both horizontal (\h) and vertical (\v) white space, rather than \s (which does not include line tabulation).
#
# v0.1.1	Modified on 22 Jan 2013 by Ventsislav Zhechev
# Added a check to remove lines that contain the NULL character (\N{U+0000}).
#
# v0.1		Modified on 15 Jan 2013 by Ventsislav Zhechev
# Initial version.
#
########################

use strict;
use utf8;

use threads;
use Thread::Queue;

use Encode qw/encode decode/;
use List::Util qw/shuffle/;

use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;
use IO::Compress::Bzip2 qw/$Bzip2Error/;

our ($threads);
$threads ||= 1;

$| = 1;

my %languages = (
	"ARA"=>"ar",
	"CSY"=>"cs",
	"DNK"=>"da",
	"DEU"=>"de",
	"ELL"=>"el",
	"ENA"=>"en_au",
	"ENG"=>"en_gb",
	"ESP"=>"es",
	"LAS"=>"es_mx",
	"FIN"=>"fi",
	"FRB"=>"fr_be",
	"FRC"=>"fr_ca",
	"FRA"=>"fr",
	"HEB"=>"he",
	"HIN"=>"hi",
	"HUN"=>"hu",
	"IND"=>"in",
	"ITA"=>"it",
	"JPN"=>"jp",
	"KOR"=>"ko",
	"NLD"=>"nl",
	"NOR"=>"no",
	"PLK"=>"pl",
	"PTB"=>"pt_br",
	"PTG"=>"pt_pt",
	"ROM"=>"ro",
	"RUS"=>"ru",
	"SLK"=>"sk",
	"SWE"=>"sv",
	"THA"=>"th",
	"TUR"=>"tr",
	"VIT"=>"vi",
	"CHS"=>"zh_hans",
	"CHT"=>"zh_hant",
);

my %dataSets = (
	"ARA"=>"tempTMs/TM_ARA_ALL.bz2::sw_corpus/corpus.sw.ara.bz2",
	"CSY"=>"tempTMs/TM_CSY_ALL.bz2::sw_corpus/corpus.sw.csy.bz2",
	"DNK"=>"tempTMs/TM_DNK_ALL.bz2",
	"DEU"=>"tempTMs/TM_DEU_ALL.bz2::sw_corpus/corpus.sw.deu.bz2",
	"ELL"=>"tempTMs/TM_ELL_ALL.bz2::sw_corpus/corpus.sw.ell.bz2",
	"ENA"=>"tempTMs/TM_ENA_ALL.bz2",
	"ENG"=>"tempTMs/TM_ENG_ALL.bz2::sw_corpus/corpus.sw.eng.bz2",
	"ESP"=>"tempTMs/TM_ESP_ALL.bz2::sw_corpus/corpus.sw.esp.bz2",
	"LAS"=>"tempTMs/TM_LAS_ALL.bz2",
	"FIN"=>"tempTMs/TM_FIN_ALL.bz2::sw_corpus/corpus.sw.fin.bz2",
	"FRB"=>"tempTMs/TM_FRB_ALL.bz2",
	"FRC"=>"tempTMs/TM_FRC_ALL.bz2",
	"FRA"=>"tempTMs/TM_FRA_ALL.bz2::sw_corpus/corpus.sw.fra.bz2",
	"HEB"=>"tempTMs/TM_HEB_ALL.bz2",
	"HIN"=>"tempTMs/TM_HIN_ALL.bz2",
	"HUN"=>"tempTMs/TM_HUN_ALL.bz2::sw_corpus/corpus.sw.hun.bz2",
	"IND"=>"tempTMs/TM_IND_ALL.bz2",
	"ITA"=>"tempTMs/TM_ITA_ALL.bz2::sw_corpus/corpus.sw.ita.bz2",
	"JPN"=>"tempTMs/TM_JPN_ALL.bz2::sw_corpus/corpus.sw.jpn.bz2",
	"KOR"=>"tempTMs/TM_KOR_ALL.bz2::sw_corpus/corpus.sw.kor.bz2",
	"NLD"=>"tempTMs/TM_NLD_ALL.bz2::sw_corpus/corpus.sw.nld.bz2",
	"NOR"=>"tempTMs/TM_NOR_ALL.bz2",
	"PLK"=>"tempTMs/TM_PLK_ALL.bz2::sw_corpus/corpus.sw.plk.bz2",
	"PTB"=>"tempTMs/TM_PTB_ALL.bz2::sw_corpus/corpus.sw.ptb.bz2",
	"PTG"=>"tempTMs/TM_PT*_ALL.bz2::sw_corpus/corpus.sw.pt*.bz2",
	"ROM"=>"tempTMs/TM_ROM_ALL.bz2::sw_corpus/corpus.sw.rom.bz2",
	"RUS"=>"tempTMs/TM_RUS_ALL.bz2::sw_corpus/corpus.sw.rus.bz2",
	"SLK"=>"tempTMs/TM_SLK_ALL.bz2",
	"SWE"=>"tempTMs/TM_SWE_ALL.bz2",
	"THA"=>"tempTMs/TM_THA_ALL.bz2",
	"TUR"=>"tempTMs/TM_TUR_ALL.bz2",
	"VIT"=>"tempTMs/TM_VIT_ALL.bz2",
	"CHS"=>"tempTMs/TM_CHS_ALL.bz2::sw_corpus/corpus.sw.chs.bz2",
	"CHT"=>"tempTMs/TM_CHT_ALL.bz2::sw_corpus/corpus.sw.cht.bz2",
);



my %products = (
"123D_main_doc" => "123D",
"123D"=>"123D",
"360NXS"=>"PLM360",
"3dsMax_doc" => "3DSMAX",
"3DSMAX"=>"3DSMAX",
"ACA_doc" => "ACA",
"acad_doc" => "ACD",
"ACAD_E_MOB"=>"ACE",
"ACAD_E"=>"ACE",
"ACD"=>"ACD",
"ACD360MOB"=>"ACD",
"ACD360WEB"=>"ACD",
"ACDMAC"=>"ACD",
"ACDSYS_doc" => "ACDSYS",
"ACDWS"=>"ACD",
"ACE_doc" => "ACE",
"ACM_doc" => "ACM",
"ACMPAN" => "ACMPAN",
"ADR"=>"ADR",
"ADS_doc" => "ADS",
"ADS"=>"ADS",
"ADSK360" => "PTFM",
"ADSTCP" => "REVIT",
"ADSTPR" => "REVIT",
"Advance_Steel_Advance_Concreate_doc" => "REVIT",
"AIRMAX" => "AIRMAX",
"AKN_doc" => "AKN",
"Algor_main_doc" => "ALGSIM",
"Alias_design_doc" => "ALIAS",
"Alias_doc" => "ALIAS",
"Alias_legacy_doc" => "ALIAS",
"ALSK"=>"ALSK",
"ALSKACD"=>"ALSK",
"AME_doc" => "N/A",
"AMECH_PP"=>"ACM",
"APPSTORE" => "APPSTORE",
"AQTO"=>"AQTO",
"ARCHDESK"=>"ACA",
"ARDES"=>"ARDES",
"ASPRO"=>"ALGSIM",
"Autocad_doc" => "ACD",
"Autocad_ws_doc" => "ACD",
"AutoCADArchitectureMEP_doc" => "BLDSYS",
"AutoCADCivil3D_doc" => "CIV3D",
"AutoCADElectrical_doc" => "ACE",
"AutoCADMap3D_doc" => "MAP",
"AutoCADMechanical_doc" => "ACM",
"AutoCADPlant3D_doc" => "PLNT3D",
"AutoCADRasterDesign_doc" => "ARDES",
"AutoCADStructuralDetailing_doc" => "ASD",
"Autodesk_Simulation_doc" => "MF",
"Backburner_doc" => "BACKBURN",
"BDS_Suite_doc" => "BDS",
"BDS"=>"BDS",
"bim360_crowd_doc" => "BIM360",
"BLDSYS"=>"BLDSYS",
"buzzsaw_doc" => "BUZZ",
"BZSW"=>"BUZZ",
"CERCIP" => "CERCIP",
"CFDSimulation_doc" => "ALGSIM",
"CFG360" => "CFG360",
"CIV3D"=>"CIV3D",
"Civil_main_doc" => "CIV3D",
"Cloud_doc" => "ACD",
"CLOUDS"=>"CLOUDS",
"Composite_doc" => "PTFM",
"conref_resourcesXML_doc" => "N/A",
"Configurator_doc" => "CFG360",
"Copyright_doc" => "PTFM",
"DirectConnect_doc" => "PTFM",
"EDM_doc" => "EDM",
"Educational_Suite_doc" => "DES_ACA",
"emea_channel_news_doc" => "MARKETING",
"EntertainmentCreationSuites_doc" => "ECS",
"entities_doc" => "N/A",
"ES_InstallGuide_doc" => "PTFM",
"ES_WelcomeLetter_doc" => "PTFM",
"Factory_Design_Suite_doc" => "FDS",
"FDS"=>"FDS",
"Fusion_doc" => "INV",
"Games_doc" => "GAMES",
"homestyler_doc" => "HSTYLR",
"HSTYLR"=>"HSTYLR",
"IDS"=>"IDS",
"IMS"=>"MAP",
"INFMDR"=>"INFMDR",
"InfrastructureDesignSuites_doc" => "IDS",
"InfrastructureModeler_doc" => "INFMDR",
"Instructables_doc" => "INSTD",
"INV"=>"INV",
"Inventor_doc" => "INV",
"Inventor_HSM_doc" => "INV",
"Inventor_main_doc" => "INV",
"Inventor_Publisher_doc" => "INVPUB",
"Inventor_Publisher_main_doc" => "INVPUB",
"INVETO"=>"INV",
"INVFUS"=>"INV",
"INVPUB"=>"INVPUB",
"krakow_doc" => "RSA",
"learning_training_doc" => "SCL",
"LIRAFX"=>"PTFM",
"M360" => "M360",
"MAP"=>"MAP",
"Map3D_doc" => "MAP",
"Mapguide_doc" => "MAPGUI",
"Marketing_doc" => "MARKETING",
"MARQUEEAPPS" => "MARQUEE",
"Maya_doc" => "MAYA",
"MAYA"=>"MAYA",
"MBXPRO"=>"MBOX",
"med_3dsmax_doc" => "3DSMAX",
"med_ECS_IG_doc" => "ECS",
"med_games_main_doc" => "GAMES",
"med_MatchMover_doc" => "MM",
"med_maya_doc" => "MAYA",
"med_MotionBuilder_doc" => "MOB",
"med_mudbox_doc" => "MBOX",
"med_showcase_doc" => "SHOWCASE",
"mentalray_doc" => "MRSTND",
"MF"=>"MF",
"Mockup_doc" => "M360",
"Moldflow_doc" => "MF",
"Moldflow_processed_doc" => "MF",
"MotionBuilder_doc" => "MOBPRO",
"Mudbox_doc" => "MBOX",
"MYADSK" => "MYADSK",
"NAV"=>"NW",
"NavisWorks_doc" => "NW",
"NavisWorks_fy12_doc" => "NW",
"Optimization_main_doc" => "PTFM",
"Packaging_doc" => "MARKETING",
"PDS"=>"PDS",
"Plant_Design_Suite_doc" => "PLTDS",
"plant_doc" => "PLNT3D",
"PLM360_doc" => "PLM360",
"PLNT3D"=>"PLNT3D",
"PLTDS"=>"PLTDS",
"PNID" => "PLNT3D",
"Product_Design_Suite_doc" => "PDS",
"QTO_FY12_doc" => "AQTO",
"QuantityTakeoff_doc" => "AQTO",
"raster_doc" => "ARDES",
"readme_doc" => "N/A",
"RECAP" => "RECAP",
"RENDERING" => "RENDERING",
"Revit_doc" => "REVIT",
"RevitExtensions_doc" => "REVIT",
"RobotStructuralAnalysis_doc" => "RSA",
"RSA_doc" => "RSA",
"RSAPRO" => "RSA",
"RSAPRO360" => "RSA",
"RVT"=>"REVIT",
"SCFD"=>"ALGSIM",
"SCL_doc" => "SCL",
"SFTIM"=>"SFTIM",
"Shared_doc" => "PTFM",
"Showcase_doc" => "SHOWCASE",
"SHOWCASE"=>"SHOWCASE",
"SIM360_CFD" => "ALGSIM",
"SIM360_I" => "ALGSIM",
"SIM360_JM" => "ALGSIM",
"SIM360" => "ALGSIM",
"SIMDFM"=>"ALGSIM",
"Simulation360_doc" => "ALGSIM",
"Simulation_Composite_doc" => "ALGSIM",
"SimulationJobManager_doc" => "ALGSIM",
"Sketchbook_doc" => "ALSK",
"SketchbookDesigner_doc" => "ALSK",
"SketchBookPro_doc" => "ALSK",
"SKETPRO"=>"ALSK",
"SmartAlign_doc" => "SMAL",
"Socialcam_doc" => "SOCAM",
"Softimage_doc" => "SFTIM",
"STRDET" => "ASD",
"Suites_doc" => "SUITES",
"swss_ws_doc" => "CLOUDS",
"Topobase_doc" => "TOPO",
"TORCH" => "TORCH",
"trisoft_corp_conrefs_doc" => "N/A",
"Vault_doc" => "EDM",
"Vault_Solidworks_addin_doc" => "EDM",
"Viewers_doc" => "ADR",
"VLT"=>"EDM",
"WAM_doc" => "WAM",
"wiki_doc" => "WIKI",
);


#system "mkdir -p corpora/ENU";
#system "touch corpora/ENU/corpus.xx.bz2";

my $languageQueue = new Thread::Queue;
#my $englishQueue = new Thread::Queue;

#my @englishSegments;
#my $maxENSegments = 500;

my $processLanguage = sub {
	#	print encode "utf-8", "∞∞∞ Enter thread ".threads->tid()."\n";
	for (;;) {
		my $language = $languageQueue->dequeue();
		last unless $language;
		print encode "utf-8", "Processing language $language…\n";
		my $segments = 0;
		system "mkdir -p corpora/$language";
		my $sourceOutput = new IO::Compress::Bzip2 "corpora/$language/corpus.en.bz2" or die encode "utf-8", "Cannot write corpus file “corpora/$language/corpus.en.bz2”: $Bzip2Error\n";
		my $targetOutput = new IO::Compress::Bzip2 "corpora/$language/corpus.$languages{$language}.bz2" or die encode "utf-8", "Cannot write corpus file “corpora/$language/corpus.$languages{$language}.bz2”: $Bzip2Error\n";
		
		#	print STDERR encode "utf-8", "Datasets available for $language: $dataSets{$language}".join("÷", split /::/ $dataSets{$language})."\n";
		foreach my $fileName (split /::/, $dataSets{$language}) {
			print encode "utf-8", "\tProcessing file “$fileName”…";
			my $input = new IO::Uncompress::Bunzip2 $fileName or die encode "utf-8", "Cannot read input file “$fileName”: $Bunzip2Error\n";
			local $/ = encode "utf-8", "◊÷\n";
			my $sources = 0;
			while (my $line = decode "utf-8", $input->getline()) {
				print "." unless $. % 100000;
				next if $line =~ /\N{U+0000}/ || $line =~ /♦♦♦/ || $line =~ /(^|)[\h\v]*/;
				chomp $line;
				my ($source, $target, $product) = split //, $line;
				$source =~ s/^\s+|\s+$//g;
				$source =~ s/[\h\v]+/ /g;
				$target =~ s/^\s+|\s+$//g;
				$target =~ s/[\h\v]+/ /g;
				next if $target =~ m"(?<!#)#{3}(?!#)" && $target ne "###" && $source !~ m"#{3}";
				++$segments;
				++$sources;
				if ($products{$product}) {
					$product = $products{$product} # || $product;
				} else {
					die "Product $product not found in database!\tCurrent file: $fileName\n";
				}
				$product = "N/A" if $product =~ m"^◊÷";
				print $sourceOutput encode "utf-8", "$source◊$product\n";
				print $targetOutput encode "utf-8", "$target◊$product\n";
#				if (@englishSegments >= $maxENSegments) {
#					$englishQueue->enqueue(\@englishSegments);
#					@englishSegments = ();
#				}
#				push @englishSegments, encode "utf-8", "$source◊$product\n";
			}
			
			close $input;
			print encode "utf-8", "done! ($sources)\n";
		}
		
		close $sourceOutput;
		close $targetOutput;
		print encode "utf-8", "\tProcessed $segments segments for language $language.\n";
	}
#	if (@englishSegments) {
#		$englishQueue->enqueue(\@englishSegments);
#		@englishSegments = ();
#	}
	#	print encode "utf-8", "∞∞∞ Exit thread ".threads->tid()."\n";
};


my @threads = map {threads->create($processLanguage)} 1..$threads;
#my $englishThread = threads->create(sub {
#	my $enuOutput = new IO::Compress::Bzip2 "corpora/ENU/corpus.en.bz2" or die encode "utf-8", "Cannot write corpus file “corpora/ENU/corpus.en.bz2”: $Bzip2Error\n";
#	local $" = "";
#	for(;;) {
#		my $segments = $englishQueue->dequeue();
#		last unless defined $segments;
#		$enuSegments += @$segments;
#		print $enuOutput "@$segments";
#	}
#	close $enuOutput;
#	print encode "utf-8", "Output $enuSegments EN-US segments for language model building.\n";
#});

$languageQueue->enqueue($_) foreach shuffle keys %languages;

#print encode "utf-8", "∞∞∞ Tell processing threads to finish\n";
$languageQueue->enqueue(undef) foreach 1..$threads;
#print encode "utf-8", "∞∞∞ Wait for processing threads to finish\n";
$_->join() foreach @threads;
#print encode "utf-8", "∞∞∞ Tell English thread to finish\n";
#$englishQueue->enqueue(undef);
##print encode "utf-8", "∞∞∞ Wait for English thread to finish\n";
#$englishThread->join();


1;