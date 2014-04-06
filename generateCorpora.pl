#!/usr/bin/perl -ws
#
# ©2013–2014 Autodesk Development Sàrl
# Created on 14 Jan 2013 by Ventsislav Zhechev
#
# ChangeLog
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
	"ENG"=>"en_uk",
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
	"PTG"=>"tempTMs/TM_PTG_ALL.bz2::sw_corpus/corpus.sw.ptg.bz2",
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
	"CFG360" => "CFG360",
  "123D_main_doc" => "123D",
  "123D"=>"123D",
  "3dsMax_doc" => "3DSMAX",
  "3DSMAX"=>"3DSMAX",
  "ACA_doc" => "ACA",
  "ARCHDESK"=>"ACA",
  "acad_doc" => "ACD",
  "ACDSYS_doc" => "ACDSYS",
  "ACE_doc" => "ACE",
  "ACAD_E"=>"ACE",
	"ACAD_E_MOB"=>"ACE",
  "ACM_doc" => "ACM",
  "AMECH_PP"=>"ACM",
  "ADS_doc" => "ADS",
  "ADS"=>"ADS",
  "AKN_doc" => "AKN",
  "Algor_main_doc" => "ALGSIM",
  "Alias_design_doc" => "ALIA",
  "Alias_doc" => "ALIA",
  "Alias_legacy_doc" => "ALIA",
  "AME_doc" => "N/A",
  "Autocad_doc" => "ACD",
  "Autocad_ws_doc" => "ACD",
  "ACD"=>"ACD",
  "ACD360WEB"=>"ACD",
  "ACD360MOB"=>"ACD",
  "ACDWS"=>"ACD",
  "ACDMAC"=>"ACD",
  "AutoCADArchitectureMEP_doc" => "BLDSYS",
  "BLDSYS"=>"BLDSYS",
  "AutoCADCivil3D_doc" => "CIV3D",
  "CIV3D"=>"CIV3D",
  "AutoCADElectrical_doc" => "ACE",
  "AutoCADMap3D_doc" => "MAP",
  "MAP"=>"MAP",
  "IMS"=>"MAP",
  "AutoCADMechanical_doc" => "ACM",
  "AutoCADPlant3D_doc" => "PLNT3D",
  "PLNT3D"=>"PLNT3D",
  "AutoCADRasterDesign_doc" => "ARDES",
  "ARDES"=>"ARDES",
  "AutoCADStructuralDetailing_doc" => "ASD",
	"STRDET" => "ASD",
  "Autodesk_Simulation_doc" => "MF",
  "Backburner_doc" => "BACKBURN",
  "BDS_Suite_doc" => "BDS",
  "BDS"=>"BDS",
  "bim360_crowd_doc" => "BIM360",
  "buzzsaw_doc" => "BUZZ",
  "BZSW"=>"BUZZ",
  "CFDSimulation_doc" => "ALGSIM",
  "SCFD"=>"ALGSIM",
  "ASPRO"=>"ALGSIM",
  "SIMDFM"=>"ALGSIM",
  "Civil_main_doc" => "CIV3D",
  "Cloud_doc" => "ACD",
  "Composite_doc" => "PTFM",
  "LIRAFX"=>"PTFM",
  "conref_resourcesXML_doc" => "N/A",
  "Copyright_doc" => "PTFM",
  "DirectConnect_doc" => "PTFM",
  "EDM_doc" => "EDM",
  "VLT"=>"EDM",
  "Educational_Suite_doc" => "DES_ACA",
  "emea_channel_news_doc" => "MARKETING",
  "EntertainmentCreationSuites_doc" => "ECS",
  "entities_doc" => "N/A",
  "ES_InstallGuide_doc" => "PTFM",
  "ES_WelcomeLetter_doc" => "PTFM",
  "Factory_Design_Suite_doc" => "FDS",
  "FDS"=>"FDS",
  "Fusion_doc" => "INV",
  "INV"=>"INV",
  "INVFUS"=>"INV",
  "INVETO"=>"INV",
	"INVPUB"=>"INVPUB",
  "Games_doc" => "GAMES",
  "homestyler_doc" => "HSTYLR",
  "HSTYLR"=>"HSTYLR",
  "InfrastructureDesignSuites_doc" => "IDS",
  "IDS"=>"IDS",
  "InfrastructureModeler_doc" => "INFMDR",
  "INFMDR"=>"INFMDR",
  "Instructables_doc" => "INSTR",
  "Inventor_doc" => "INV",
  "Inventor_main_doc" => "INV",
  "Inventor_Publisher_doc" => "INVPUB",
  "Inventor_Publisher_main_doc" => "INVPUB",
  "krakow_doc" => "RSA",
  "learning_training_doc" => "SCL",
  "Map3D_doc" => "MAP",
  "Mapguide_doc" => "MAPGUI",
  "Marketing_doc" => "MARKETING",
  "Maya_doc" => "MAYA",
  "MAYA"=>"MAYA",
  "med_3dsmax_doc" => "3DSMAX",
  "med_ECS_IG_doc" => "ECS",
  "med_games_main_doc" => "GAMES",
  "med_MatchMover_doc" => "MM",
  "med_maya_doc" => "MAYA",
  "med_MotionBuilder_doc" => "MOB",
  "med_mudbox_doc" => "MBOX",
  "MBXPRO"=>"MBOX",
  "med_showcase_doc" => "SHOWCASE",
  "SHOWCASE"=>"SHOWCASE",
  "mentalray_doc" => "MRSTND",
  "Mockup_doc" => "M360",
  "Moldflow_doc" => "MF",
  "Moldflow_processed_doc" => "MF",
  "MF"=>"MF",
  "MotionBuilder_doc" => "MOB",
  "Mudbox_doc" => "MBOX",
  "NavisWorks_doc" => "NW",
  "NavisWorks_fy12_doc" => "NW",
  "NAV"=>"NW",
  "Optimization_main_doc" => "PTFM",
  "Packaging_doc" => "MARKETING",
  "Plant_Design_Suite_doc" => "PLTDS",
  "PLTDS"=>"PLTDS",
  "plant_doc" => "PLNT3D",
  "PLM360_doc" => "PLM360",
  "360NXS"=>"PLM360",
  "Product_Design_Suite_doc" => "PDS",
  "PDS"=>"PDS",
  "QTO_FY12_doc" => "AQTO",
  "QuantityTakeoff_doc" => "AQTO",
  "AQTO"=>"AQTO",
  "raster_doc" => "ARDES",
  "readme_doc" => "N/A",
  "Revit_doc" => "REVIT",
  "RevitExtensions_doc" => "REVIT",
  "RVT"=>"REVIT",
  "RobotStructuralAnalysis_doc" => "RSA",
  "RSA_doc" => "RSA",
	"RSAPRO" => "RSA",
	"RSAPRO360" => "RSA",
  "SCL_doc" => "SCL",
  "Shared_doc" => "PTFM",
  "Showcase_doc" => "SHOWCASE",
  "Simulation360_doc" => "ALGSIM",
	"SIM360" => "ALGSIM",
  "SimulationJobManager_doc" => "ALGSIM",
	"SIM360_JM" => "ALGSIM",
  "Sketchbook_doc" => "ALSK",
  "SketchbookDesigner_doc" => "ALSK",
  "SketchBookPro_doc" => "ALSK",
  "ALSKACD"=>"ALSK",
  "SKETPRO"=>"ALSK",
  "ALSK"=>"ALSK",
  "Socialcam_doc" => "SOCAM",
  "Softimage_doc" => "SFTIM",
  "SFTIM"=>"SFTIM",
  "Suites_doc" => "SUITES",
  "swss_ws_doc" => "CLOUDS",
  "CLOUDS"=>"CLOUDS",
  "Topobase_doc" => "TOPO",
  "trisoft_corp_conrefs_doc" => "N/A",
  "Vault_doc" => "EDM",
  "Viewers_doc" => "ADR",
  "ADR"=>"ADR",
  "WAM_doc" => "WAM",
  "wiki_doc" => "WIKI",
	"ADSK360" => "ADSK360",
	"AIRMAX" => "AIRMAX",
	"APPSTORE" => "APPSTORE",
	"CERCIP" => "CERCIP",
	"MARQUEEAPPS" => "MARQUEE",
	"TORCH" => "TORCH",
	"PNID" => "PLNT3D",
	"SmartAlign_doc" => "SMAL",
	"Advance_Steel_Advance_Concreate_doc" => "GRAITEC",
	"ADSTPR" => "GRAITEC",
	"ADSTCP" => "GRAITEC",
	"MYADSK" => "MYADSK",
	"M360" => "M360",
);


system "mkdir -p corpora/ENU";
system "touch corpora/ENU/corpus.xx.bz2";
my $enuSegments :shared = 0;

my $languageQueue = new Thread::Queue;
my $englishQueue = new Thread::Queue;

my @englishSegments;
my $maxENSegments = 500;

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
				++$segments;
				++$sources;
#				{lock $enuSegments;
#					++$enuSegments;
#				}
				$source =~ s/^\s+|\s+$//g;
				$source =~ s/[\h\v]+/ /g;
				$target =~ s/^\s+|\s+$//g;
				$target =~ s/[\h\v]+/ /g;
				if ($products{$product}) {
					$product = $products{$product} # || $product;
				} else {
					print STDERR "Product $product not found in database!\nCurrent file: $fileName\n";
					die;
				}
				$product = "N/A" if $product =~ m"^◊÷";
				print $sourceOutput encode "utf-8", "$source◊$product\n";
				print $targetOutput encode "utf-8", "$target◊$product\n";
#				sleep 1 while $englishQueue->pending() > 1500000;
#				$englishQueue->enqueue(encode "utf-8", "$source◊$product\n");
				if (@englishSegments >= $maxENSegments) {
					$englishQueue->enqueue(\@englishSegments);
					@englishSegments = ();
				}
				push @englishSegments, encode "utf-8", "$source◊$product\n";
			}
			
			close $input;
			print encode "utf-8", "done! ($sources)\n";
		}
		
		close $sourceOutput;
		close $targetOutput;
		print encode "utf-8", "\tProcessed $segments segments for language $language.\n";
	}
	if (@englishSegments) {
		$englishQueue->enqueue(\@englishSegments);
		@englishSegments = ();
	}
	#	print encode "utf-8", "∞∞∞ Exit thread ".threads->tid()."\n";
};


my @threads = map {threads->create($processLanguage)} 1..$threads;
my $englishThread = threads->create(sub {
	my $enuOutput = new IO::Compress::Bzip2 "corpora/ENU/corpus.en.bz2" or die encode "utf-8", "Cannot write corpus file “corpora/ENU/corpus.en.bz2”: $Bzip2Error\n";
	local $" = "";
	for(;;) {
		my $segments = $englishQueue->dequeue();
		last unless defined $segments;
		$enuSegments += @$segments;
		print $enuOutput "@$segments";
	}
	close $enuOutput;
	print encode "utf-8", "Output $enuSegments EN-US segments for language model building.\n";
});

$languageQueue->enqueue($_) foreach shuffle keys %languages;

#print encode "utf-8", "∞∞∞ Tell processing threads to finish\n";
$languageQueue->enqueue(undef) foreach 1..$threads;
#print encode "utf-8", "∞∞∞ Wait for processing threads to finish\n";
$_->join() foreach @threads;
#print encode "utf-8", "∞∞∞ Tell English thread to finish\n";
$englishQueue->enqueue(undef);
#print encode "utf-8", "∞∞∞ Wait for English thread to finish\n";
$englishThread->join();


1;