#!/usr/bin/perl -sw
#
# ©2011–2012 Autodesk Development Sàrl
# Created by Ventsislav Zhechev on 29 Sep 2011
# Last modified by Ventsislav Zhechev on 05 Oct 2012
#
########################


use strict;

use Encode qw/encode decode/;
use utf8;

use IO::Uncompress::Bunzip2 qw/$Bunzip2Error/;
use Storable qw/dclone/;

our ($input);

die "Usage: $0 -input=…\n"
unless defined $input;

my %localeMap = (
english										=> "term",

czech											=> "cs",
danish										=> "da",
german										=> "de",
"english uk"								=> "en_uk",
"english (united kingdom)"	=> "en_uk",
spanish										=> "es",
finnish										=> "fi",
french										=> "fr",
hungarian									=> "hu",
italian										=> "it",
ja												=> "jp",
japanese									=> "jp",
korean										=> "ko",
"dutch netherlands"				=> "nl",
"dutch (netherlands)"			=> "nl",
norwegian									=> "no",
"norwegian (bokmal)"				=> "no",
polish										=> "pl",
brazilian_portuguese			=> "pt_br",
"brazilian portuguese"			=> "pt_br",
"portuguese (brazil)"			=> "pt_br",
"portuguese (portugal)"		=> "pt_pt",
russian										=> "ru",
swedish										=> "sv",
turkish										=> "tr",
vietnamese								=> "vi",
simplified_chinese				=> "zh_hans",
"simplified chinese"				=> "zh_hans",
"chinese (prc)"						=> "zh_hans",
traditional_chinese				=> "zh_hant",
"traditional chinese"			=> "zh_hant",
"chinese (taiwan)"					=> "zh_hant",
);

my %products = (
"Manual_titles"=>"MANTIT_gloss",
"Studio_Cloud_all_langs"=>"CLOUDS_gloss",
"CLOUDS"=>"CLOUDS_gloss",

"ACAD_Systems_FIGS"=>"ACDSYS_gloss",
"Cloud Analysis_all_langs"=>"CLANAL_gloss",
"Alias_APAC"=>"ALIA_gloss",
"123D_Term_database_all_langs"=>"123D_gloss",
"123D"=>"123D_gloss",
"AUTOST"=>"ALIA_gloss",
"DESNST"=>"ALIA_gloss",
"SURFST"=>"ALIA_gloss",
"ATCIGM"=>"ALIA_gloss",
"AutoCAD_APAC"=>"ACD_gloss",
"AutoCAD_EE"=>"ACD_gloss",
"AutoCAD_FIGS-PTB"=>"ACD_gloss",
"AutoCAD_Nordic"=>"ACD_gloss",
"AutoCAD_Commands_EE"=>"ACD_gloss",
"AutoCAD_Commands_FIGS-PTB"=>"ACD_gloss",
"AutoCAD_Commands_JPN"=>"ACD_gloss",
"ACD"=>"ACD_gloss",
"ACA_APAC"=>"ACA_gloss",
"ACA_EE"=>"ACA_gloss",
"ACA_FIGS"=>"ACA_gloss",
"ARCHDESK"=>"ACA_gloss",
"ACAD_Electrical_APAC"=>"ACE_gloss",
"ACAD_Electrical_EE"=>"ACE_gloss",
"ACAD_Electrical_FIGS"=>"ACE_gloss",
"ACAD_E"=>"ACE_gloss",
"ACAD_Mechanical_APAC"=>"ACM_gloss",
"ACAD_Mechanical_EE"=>"ACM_gloss",
"ACAD_Mechanical_FIGS-PTB"=>"ACM_gloss",
"AMECH_PP"=>"ACM_gloss",
"ASD_FIS_P"=>"ASD_gloss",
"STRDET"=>"ASD_gloss",
"Buzzsaw_APAC"=>"BUZZ_gloss",
"Buzzsaw_FIGS"=>"BUZZ_gloss",
"BZSW"=>"BUZZ_gloss",
"Civil_APAC"=>"CIV3D_gloss",
"Civil_EE"=>"CIV3D_gloss",
"Civil_ENG"=>"CIV3D_gloss",
"Civil_FIGS"=>"CIV3D_gloss",
"CIV3D"=>"CIV3D_gloss",
"EDM_APAC"=>"EDM_gloss",
"EDM_EE"=>"EDM_gloss",
"EDM_FIGS-PTB"=>"EDM_gloss",
"INVVAU"=>"EDM_gloss",
"VLTC"=>"EDM_gloss",
"VTCAEC"=>"EDM_gloss",
"VLTCON"=>"EDM_gloss",
"VLTSAP"=>"EDM_gloss",
"PCOFFI"=>"EDM_gloss",
"VLTM"=>"EDM_gloss",
"VLTWG"=>"EDM_gloss",
"VLTEAD"=>"EDM_gloss",
"Factory-Design-Utility_all_langs"=>"FDS_gloss",
"FDSPRM"=>"FDS_gloss",
"FDSS"=>"FDS_gloss",
"FDSADV"=>"FDS_gloss",
"Infrastructure_Modeler_all_langs"=>"INFMDR_gloss",
"INFMDR"=>"INFMDR_gloss",
"Inventor_APAC"=>"INV_gloss",
"Inventor_EE"=>"INV_gloss",
"Inventor_FIGS-PTB"=>"INV_gloss",
"INVLTS"=>"INV_gloss",
"INVPRO"=>"INV_gloss",
"INVPRORS"=>"INV_gloss",
"INVPROSIM"=>"INV_gloss",
"INVBUN"=>"INV_gloss",
"INVNTOR"=>"INV_gloss",
"INVETO"=>"INV_gloss",
"INVAR"=>"INV_gloss",
"INTSER"=>"INV_gloss",
"INVLT"=>"INV_gloss",
"INVOEM"=>"INV_gloss",
"INVPROSA"=>"INV_gloss",
"INVRT"=>"INV_gloss",
"Inventor_Publisher_APAC"=>"INVPUB_gloss",
"Inventor_Publisher_EE"=>"INVPUB_gloss",
"Inventor_Publisher_FIGS-PTB"=>"INVPUB_gloss",
"INVPUB"=>"INVPUB_gloss",
"Inventor_Tooling_APAC"=>"INVTOOL_gloss",
"Inventor_Tooling_EE"=>"INVTOOL_gloss",
"Inventor_Tooling_FIGS-PTB"=>"INVTOOL_gloss",
"Inventor_Tooling_MITSI_CSY-PLK"=>"INVTOOL_gloss",
"INVMFG"=>"INVTOOL_gloss",
"IPRM_APAC"=>"IMS_gloss",
"IPRM_EE"=>"IMS_gloss",
"IPRM_FIGS-PTB"=>"IMS_gloss",
"IMS"=>"IMS_gloss",
"M&E_3dsMax"=>"3DSMAX_gloss",
"M&E_Game_Middleware"=>"3DSMAX_gloss",
"3DSMAX"=>"3DSMAX_gloss",
"MAXDES"=>"3DSMAX_gloss",
"MXECSP"=>"3DSMAX_gloss",
"MXECS"=>"3DSMAX_gloss",
"med_3dsmax_chs"=>"ZZ_3DSMAX_gloss",
"med_3dsmax_deu"=>"ZZ_3DSMAX_gloss",
"med_3dsmax_fra"=>"ZZ_3DSMAX_gloss",
"med_3dsmax_jpn"=>"ZZ_3DSMAX_gloss",
"med_3dsmax_kor"=>"ZZ_3DSMAX_gloss",
"med_fbx_3dsmax_chs"=>"ZZ_3DSMAX_gloss",
"med_fbx_3dsmax_deu"=>"ZZ_3DSMAX_gloss",
"med_fbx_3dsmax_fra"=>"ZZ_3DSMAX_gloss",
"med_fbx_3dsmax_jpn"=>"ZZ_3DSMAX_gloss",
"med_fbx_3dsmax_kor"=>"ZZ_3DSMAX_gloss",
"M&E_Maya"=>"MAYA_gloss",
"MAYA"=>"MAYA_gloss",
"MAY881"=>"MAYA_gloss",
"MYECSP"=>"MAYA_gloss",
"MYECS"=>"MAYA_gloss",
"M&E_MotionBuilder"=>"MOB_gloss",
"MOBPRO"=>"MOB_gloss",
"MOB881"=>"MOB_gloss",
"M&E_Mudbox"=>"MBOX_gloss",
"MBXPRO"=>"MBOX_gloss",
"M&E_Showcase"=>"SHOWCASE_gloss",
"SHOWCASE"=>"SHOWCASE_gloss",
"SHOWPRO"=>"SHOWCASE_gloss",
"MAP_APAC"=>"MAP_gloss",
"MAP_EE"=>"MAP_gloss",
"MAP_FIGS-PTB"=>"MAP_gloss",
"MAP"=>"MAP_gloss",
"MAP3DE"=>"MAP_gloss",
"MapGuide_APAC"=>"MAPGUI_gloss",
"MapGuide_EE"=>"MAPGUI_gloss",
"MapGuide_FIGS-PTB"=>"MAPGUI_gloss",
"med_Backburner_chs"=>"BACKBURN_gloss",
"med_Backburner_jpn"=>"BACKBURN_gloss",
"med_Backburner_kor"=>"BACKBURN_gloss",
"MEP_APAC"=>"BLDSYS_gloss",
"MEP_EE"=>"BLDSYS_gloss",
"MEP_FIGS"=>"BLDSYS_gloss",
"BLDSYS"=>"BLDSYS_gloss",
"RVTMPB"=>"BLDSYS_gloss",
"RVTMPJ"=>"BLDSYS_gloss",
"Moldflow terminology"=>"MF_gloss",
"MFDLC"=>"MF_gloss",
"MFDLP"=>"MF_gloss",
"MFDLPE"=>"MF_gloss",
"MFIWSA"=>"MF_gloss",
"MFIWS"=>"MF_gloss",
"MFIWSP"=>"MF_gloss",
"MFAA"=>"MF_gloss",
"MFCD"=>"MF_gloss",
"MFDL"=>"MF_gloss",
"MFIB"=>"MF_gloss",
"MFIA"=>"MF_gloss",
"MFS"=>"MF_gloss",
"MFAM"=>"MF_gloss",
"MFAD"=>"MF_gloss",
"MFIP"=>"MF_gloss",
"Navisworks_APAC"=>"NW_gloss",
"Navisworks_EE"=>"NW_gloss",
"Navisworks_FIGS-PTB"=>"NW_gloss",
"NWFAD"=>"NW_gloss",
"NWFPR"=>"NW_gloss",
"NAVFREE"=>"NW_gloss",
"NAVMAN"=>"NW_gloss",
"NAVREV"=>"NW_gloss",
"NAVSIM"=>"NW_gloss",
"P&ID_APAC"=>"PNID_gloss",
"P&ID_EE"=>"PNID_gloss",
"P&ID_FIGS"=>"PNID_gloss",
"PNID"=>"PNID_gloss",
"Platform_Technologies_APAC"=>"PTFM_gloss",
"Platform_Technologies_EE"=>"PTFM_gloss",
"Platform_Technologies_FIGS-PTB"=>"PTFM_gloss",
"Platform_Technologies_Nordic"=>"PTFM_gloss",
"PLM_360_all_langs"=>"PLM360_gloss",
"360NXS"=>"PLM360_gloss",
"QTO_APAC"=>"AQTO_gloss",
"QTO_EE"=>"AQTO_gloss",
"QTO_FIGS+PTB"=>"AQTO_gloss",
"AQTO"=>"AQTO_gloss",
"RasterDesign_APAC"=>"ARDES_gloss",
"RasterDesign_EE"=>"ARDES_gloss",
"RasterDesign_FIGS-PTB"=>"ARDES_gloss",
"ARDES"=>"ARDES_gloss",
"Revit_APAC"=>"REVIT_gloss",
"Revit_EE"=>"REVIT_gloss",
"Revit_Extensions_all_langs"=>"REVIT_gloss",
"Revit_FIGS_PTB"=>"REVIT_gloss",
"REVITS"=>"REVIT_gloss",
"RAVS"=>"REVIT_gloss",
"RVTLTS"=>"REVIT_gloss",
"REVSYP"=>"REVIT_gloss",
"REVSU"=>"REVIT_gloss",
"RVT"=>"REVIT_gloss",
"REVIT"=>"REVIT_gloss",
"RVTLT"=>"REVIT_gloss",
"RVTMPB"=>"REVIT_gloss",
"RVTMPJ"=>"REVIT_gloss",
"REVITST"=>"REVIT_gloss",
"Robot Structural Analysis_all_langs"=>"RSA_gloss",
"RSA"=>"RSA_gloss",
"RSAPRO"=>"RSA_gloss",
"Simulation_all_langs"=>"ALGSIM_gloss",
"ALGSIM"=>"ALGSIM_gloss",
"ASCFD"=>"ALGSIM_gloss",
"KYNSIM"=>"ALGSIM_gloss",
"SIM360"=>"ALGSIM_gloss",
"SM360P"=>"ALGSIM_gloss",
"SM360S"=>"ALGSIM_gloss",
"SM360U"=>"ALGSIM_gloss",
"SCFD"=>"ALGSIM_gloss",
"SCFDA"=>"ALGSIM_gloss",
"SCACIS"=>"ALGSIM_gloss",
"SCCV5"=>"ALGSIM_gloss",
"SCCOC"=>"ALGSIM_gloss",
"SCFDCD"=>"ALGSIM_gloss",
"SCFDCI"=>"ALGSIM_gloss",
"SCFDNX"=>"ALGSIM_gloss",
"SCFDP"=>"ALGSIM_gloss",
"SCPROE"=>"ALGSIM_gloss",
"SCFDCR"=>"ALGSIM_gloss",
"SCFDSE"=>"ALGSIM_gloss",
"SCFDSW"=>"ALGSIM_gloss",
"SCFDSC"=>"ALGSIM_gloss",
"SCDSE"=>"ALGSIM_gloss",
"SCFDM"=>"ALGSIM_gloss",
"SIMDFM"=>"ALGSIM_gloss",
"ASMES"=>"ALGSIM_gloss",
"ALGSAAS"=>"ALGSIM_gloss",
"ASPRO"=>"ALGSIM_gloss",
"SketchBook_APAC"=>"ALSK_gloss",
"SketchBook_FIGS-PTB"=>"ALSK_gloss",
"ALSK"=>"ALSK_gloss",
"SKETPRO"=>"ALSK_gloss",
"Softimage_jpn"=>"SFTIM_gloss",
"SFTIM"=>"SFTIM_gloss",
"SFTIMA"=>"SFTIM_gloss",
"SIECS"=>"SFTIM_gloss",
"Topobase_APAC"=>"TOPO_gloss",
"Topobase_EE"=>"TOPO_gloss",
"TopoBase_FIGS-PTB"=>"TOPO_gloss",
"TB2_3"=>"TOPO_gloss",
"TOPOBSCLNT"=>"TOPO_gloss",
"TOPOBSWEB"=>"TOPO_gloss",
"TBFIBR"=>"TOPO_gloss",


"Alias TC Integrator for GM"=>"ATCIGM",
"AutoCAD"=>"ACD",
"AutoCAD Architecture"=>"ARCHDESK",
"AutoCAD Civil 3D"=>"CIV3D",
"AutoCAD Design Suite Premium"=>"DSPRM",
"AutoCAD Design Suite Standard"=>"DSSTD",
"AutoCAD Design Suite Ultimate"=>"DSADV",
"AutoCAD ECSCAD"=>"ECSCAD",
"AutoCAD Electrical"=>"ACAD_E",
"AutoCAD for Mac"=>"ACDMAC",
"AutoCAD Freestyle"=>"FRSTYL",
"AutoCAD Inventor LT Suite"=>"INVLTS",
"AutoCAD Inventor Professional Suite"=>"INVPRO",
"AutoCAD Inventor Routed Systems Suite"=>"INVPRORS",
"AutoCAD Inventor Simulation Suite"=>"INVPROSIM",
"AutoCAD Inventor Suite"=>"INVBUN",
"AutoCAD Inventor Tooling Suite"=>"INVMFG",
"AutoCAD LT"=>"ACDLT",
"AutoCAD LT Civil Suite"=>"ACDLTC",
"AutoCAD LT for Mac"=>"ACDLTM",
"AutoCAD Map 3D"=>"MAP",
"AutoCAD Map 3D Enterprise"=>"MAP3DE",
"AutoCAD Mechanical"=>"AMECH_PP",
"AutoCAD MEP"=>"BLDSYS",
"AutoCAD OEM"=>"ACD OEM",
"AutoCAD P&ID"=>"PNID",
"AutoCAD Plant 3D"=>"PLNT3D",
"AutoCAD Raster Design"=>"ARDES",
"AutoCAD Revit Architecture Suite"=>"REVITS",
"AutoCAD Revit Architecture Visualization Suite"=>"RAVS",
"AutoCAD Revit LT Suite"=>"RVTLTS",
"AutoCAD Revit MEP Suite"=>"REVSYP",
"AutoCAD Revit Structure Suite"=>"REVSU",
"AutoCAD Structural Detailing"=>"STRDET",
"AutoCAD Utility Design"=>"UTLDESN",
"Autodesk  Vault Basic"=>"INVVAU",
"Autodesk Vault Basic"=>"INVVAU",
"Autodesk 123D"=>"123D",
"Autodesk 123D Sculpt"=>"123DSC",
"Autodesk 3DS Max"=>"3DSMAX",
"Autodesk 3DS Max Design"=>"MAXDES",
"Autodesk 3ds Max Entertainment Creation Suite Premium"=>"MXECSP",
"Autodesk 3ds Max Entertainment Creation Suite Standard"=>"MXECS",
"Autodesk Algor Simulation"=>"ALGSIM",
"Autodesk Algor Simulation CFD"=>"ASCFD",
"Autodesk Alias Automotive"=>"AUTOST",
"Autodesk Alias Design"=>"DESNST",
"Autodesk Alias Surface"=>"SURFST",
"Autodesk Authorized Training Center"=>"L&T",
"Autodesk Beast"=>"BEAST",
"Autodesk BIM 360 Field"=>"BM360F",
"Autodesk BIM 360 Glue"=>"BIM360",
"Autodesk Building Design Suite for Education"=>"ESAE",
"Autodesk Building Design Suite Premium"=>"BDSPRM",
"Autodesk Building Design Suite Standard"=>"BDSS",
"Autodesk Building Design Suite Ultimate"=>"BDSADV",
"Autodesk Building Fabrication Suite"=>"BDFBS",
"Autodesk Buzzsaw Professional"=>"CNSTRMGR",
"Autodesk Buzzsaw Server Edition"=>"BUZZSAWSE",
"Autodesk Buzzsaw Standard"=>"BZSW",
"Autodesk Constructware"=>"CWARE",
"Autodesk Custom Solution"=>"CSTSOL",
"Autodesk Design Academy"=>"DES_ACA",
"Autodesk Design and Creations Suites downloads for Deployment only"=>"T1MFSD",
"Autodesk Developer Network"=>"ADN",
"Autodesk DirectConnect for UG NX"=>"DC_UG",
"Autodesk Ecotect Analysis"=>"ECOA",
"Autodesk Education Master Suite"=>"EMS",
"Autodesk Education Suite for Industrial Design"=>"ESID",
"Autodesk Enterprise Flex Rendering/Inventor Optimization Access"=>"EFLXRO",
"Autodesk Entertainment Creation Master Suite"=>"ECMS",
"Autodesk Entertainment Creation Suite for Education"=>"ESEC",
"Autodesk Entertainment Creation Suite Ultimate"=>"ENCSU",
"Autodesk Entertainment Creation Suite Ultimate - Secondary Schools"=>"AAA",
"Autodesk Fabrication CADmep"=>"CADMEP",
"Autodesk Fabrication CAMduct"=>"CAMDCT",
"Autodesk Fabrication CAMduct Components"=>"CAMLTE",
"Autodesk Fabrication ESTmep"=>"ESTMEP",
"Autodesk Fabrication FABmep"=>"FABMEP",
"Autodesk Fabrication RemoteEntry"=>"RMNTRY",
"Autodesk Fabrication Tracker"=>"TRCKIT",
"Autodesk Factory Design Suite Premium"=>"FDSPRM",
"Autodesk Factory Design Suite Standard"=>"FDSS",
"Autodesk Factory Design Suite Ultimate"=>"FDSADV",
"Autodesk Fluid FX"=>"FLDFX",
"Autodesk ForceEffect"=>"FRCEFT",
"Autodesk Gameware Cognition"=>"GWCOG",
"Autodesk Gameware Population"=>"GWPOP",
"Autodesk GIS Design Server"=>"DES_SER",
"Autodesk Homestyler"=>"HSTYLR",
"Autodesk HumanIK"=>"HMNIK",
"Autodesk Infrastructure Design Suite for Education"=>"ESCSE",
"Autodesk Infrastructure Design Suite Premium"=>"IDSP",
"Autodesk Infrastructure Design Suite Standard"=>"IDSS",
"Autodesk Infrastructure Design Suite Ultimate"=>"IDSU",
"Autodesk Infrastructure Map Server"=>"IMS",
"Autodesk Infrastructure Modeler"=>"INFMDR",
"Autodesk Inventor"=>"INVNTOR",
"Autodesk Inventor Engineer-to-Order Series"=>"INVETO",
"Autodesk Inventor Engineer-to-Order Series Distribution Fee"=>"INVAR",
"Autodesk Inventor Engineer-to-Order Server"=>"INTSER",
"Autodesk Inventor LT"=>"INVLT",
"Autodesk Inventor OEM"=>"INVOEM",
"Autodesk Inventor Professional"=>"INVPROSA",
"Autodesk Inventor Publisher"=>"INVPUB",
"Autodesk Inventor Runtime"=>"INVRT",
"Autodesk Kynapse Games"=>"KYNGMS",
"Autodesk Kynapse Simulation"=>"KYNSIM",
"Autodesk LandXplorer Server"=>"LDXSVR",
"Autodesk Local Government Term License"=>"LGTM",
"Autodesk Master Builder"=>"MSTBLD",
"Autodesk Maya"=>"MAYA",
"Autodesk Maya 881"=>"MAY881",
"Autodesk Maya Entertainment Creation Suite Premium"=>"MYECSP",
"Autodesk Maya Entertainment Creation Suite Standard"=>"MYECS",
"Autodesk Moldflow Design Link for CATIA V5"=>"MFDLC",
"Autodesk Moldflow Design Link for Parasolid"=>"MFDLP",
"Autodesk Moldflow Design Link for Pro/ENGINEER"=>"MFDLPE",
"Autodesk Moldflow Insight WS Advanced"=>"MFIWSA",
"Autodesk Moldflow Insight WS Basic"=>"MFIWS",
"Autodesk Moldflow Insight WS Pro"=>"MFIWSP",
"Autodesk MotionBuilder"=>"MOBPRO",
"Autodesk Mudbox"=>"MBXPRO",
"Autodesk Navisworks Factory Advanced"=>"NWFAD",
"Autodesk Navisworks Factory Premium"=>"NWFPR",
"Autodesk Navisworks Freedom"=>"NAVFREE",
"Autodesk Navisworks Manage"=>"NAVMAN",
"Autodesk Navisworks Review"=>"NAVREV",
"Autodesk Navisworks Simulate"=>"NAVSIM",
"Autodesk Opticore Studio Professional"=>"OSPRO",
"Autodesk Plant Design Suite Premium"=>"PDSPRM",
"Autodesk Plant Design Suite Standard"=>"PLTDSS",
"Autodesk Plant Design Suite Ultimate"=>"PDSADV",
"Autodesk PLM 360"=>"360NXS",
"Autodesk Product Design Suite for Education"=>"ESME",
"Autodesk Product Design Suite Premium"=>"PDSP",
"Autodesk Product Design Suite Standard"=>"PDSS",
"Autodesk Product Design Suite Ultimate"=>"PDSU",
"Autodesk Quantity Takeoff"=>"AQTO",
"Autodesk Real-Time Ray Tracing Cluster"=>"RTRTCL",
"Autodesk Revit"=>"RVT",
"Autodesk Revit Architecture"=>"REVIT",
"Autodesk Revit LT"=>"RVTLT",
"Autodesk Revit MEP"=>"RVTMPB",
"Autodesk Revit MEP-J"=>"RVTMPJ",
"Autodesk Revit Structure"=>"REVITST",
"Autodesk Robot Structural Analysis"=>"RSA",
"Autodesk Robot Structural Analysis Professional"=>"RSAPRO",
"Autodesk Scaleform"=>"SCLFRM",
"Autodesk SEEK"=>"SEEK",
"Autodesk Showcase"=>"SHOWCASE",
"Autodesk Showcase Professional"=>"SHOWPRO",
"Autodesk Simulation 360"=>"SIM360",
"Autodesk Simulation 360 Premium"=>"SM360P",
"Autodesk Simulation 360 Standard"=>"SM360S",
"Autodesk Simulation 360 Ultimate"=>"SM360U",
"Autodesk Simulation CFD"=>"SCFD",
"Autodesk Simulation CFD Advanced"=>"SCFDA",
"Autodesk Simulation CFD Connection for ACIS"=>"SCACIS",
"Autodesk Simulation CFD Connection for Catia V5"=>"SCCV5",
"Autodesk Simulation CFD Connection for CoCreate"=>"SCCOC",
"Autodesk Simulation CFD Connection for Discrete"=>"SCFDCD",
"Autodesk Simulation CFD Connection for Inventor"=>"SCFDCI",
"Autodesk Simulation CFD Connection for NX"=>"SCFDNX",
"Autodesk Simulation CFD Connection for Parasolid"=>"SCFDP",
"Autodesk Simulation CFD Connection for Pro/ENGINEER"=>"SCPROE",
"Autodesk Simulation CFD Connection for Revit"=>"SCFDCR",
"Autodesk Simulation CFD Connection for SolidEdge"=>"SCFDSE",
"Autodesk Simulation CFD Connection for SolidWorks"=>"SCFDSW",
"Autodesk Simulation CFD Connection for SpaceClaim"=>"SCFDSC",
"Autodesk Simulation CFD Design Study Environment​"=>"SCDSE", #This one contains a zero space Left it in for compatiblity
"Autodesk Simulation CFD Design Study Environment"=>"SCDSE",
"Autodesk Simulation CFD Motion"=>"SCFDM",
"Autodesk Simulation DFM"=>"SIMDFM",
"Autodesk Simulation Mechanical"=>"ASMES",
"Autodesk Simulation Mechanical WS"=>"ALGSAAS",
"Autodesk Simulation Moldflow Adviser Ultimate"=>"MFAA",
"Autodesk Simulation Moldflow CAD Doctor"=>"MFCD",
"Autodesk Simulation Moldflow Design Link"=>"MFDL",
"Autodesk Simulation Moldflow Insight Standard"=>"MFIB",
"Autodesk Simulation Moldflow Insight Ultimate"=>"MFIA",
"Autodesk Simulation Moldflow Synergy"=>"MFS",
"Autodesk Simulation Moldflow Adviser Premium"=>"MFAM",
"Autodesk Simulation Moldflow Adviser Premium"=>"MFAM",
"Autodesk Simulation Moldflow Adviser Standard"=>"MFAD",
"Autodesk Simulation Moldflow Adviser Standard"=>"MFAD",
"Autodesk Simulation Moldflow Insight Premium"=>"MFIP",
"Autodesk Simulation Moldflow Insight Premium"=>"MFIP",
"Autodesk Simulation Multiphysics"=>"ASPRO",
"Autodesk SketchBook Designer"=>"ALSK",
"Autodesk SketchBook Pro"=>"SKETPRO",
"Autodesk Smoke For Mac OS"=>"SMKMAC",
"Autodesk Softimage"=>"SFTIM",
"Autodesk Softimage Advanced"=>"SFTIMA",
"Autodesk Softimage Entertainment Creation Suite"=>"SIECS",
"Autodesk Stitcher Unlimited"=>"STCHR",
"Autodesk Topobase 2/3"=>"TB2_3",
"Autodesk Topobase Client"=>"TOPOBSCLNT",
"Autodesk Topobase Web"=>"TOPOBSWEB",
"Autodesk tsElements Plug-in"=>"TEPSW",
"Autodesk T-Splines Plug-in for Rhino"=>"TSPRHN",
"Autodesk Vault Collaboration"=>"VLTC",
"Autodesk Vault Collaboration AEC"=>"VTCAEC",
"Autodesk Vault Connect"=>"VLTCON",
"Autodesk Vault Integration for SAP ERP"=>"VLTSAP",
"Autodesk Vault Office"=>"PCOFFI",
"Autodesk Vault Professional"=>"VLTM",
"Autodesk Vault Workgroup"=>"VLTWG",
"Autodesk Visual Bridge"=>"ADTRPVB",
"Autodesk Water Analysis"=>"WTRANL",
"AutoSketch"=>"ASK",
"CAiCE Visual Construction"=>"ADTRPVC",
"CAiCE Visual Roads"=>"ADTRPVR",
"CAiCE Visual Survey"=>"ADTRPVS",
"CAiCE Visual Survey & Roads"=>"ADTRPVSR",
"CFD Advanced"=>"CFDA",
"CFD Basic"=>"CFDB",
"Electronic Mobil Application"=>"MOBAPP",
"Enterprise Add-on for Autodesk Vault"=>"VLTEAD",
"GENERIC (COMPONENT TYPE)ACAD MKT GROUP"=>"GEN ENG",
"Generic Box"=>"GENERIC",
"Generic Brochures"=>"GENERIC",
"Generic Card"=>"GENERIC",
"Generic Document"=>"GENERIC",
"Generic Flex Box"=>"GENERIC",
"Generic Front Liner"=>"GENERIC",
"Generic Letters"=>"GENERIC",
"Generic Manual"=>"GENERIC",
"Generic Media"=>"GENERIC",
"Generic Shipper Box"=>"GENERIC",
"Generic Sleeve"=>"GENERIC",
"Generic Stickers"=>"GENERIC",
"GM CAD Convertors"=>"GMCADC",
"Green Building Studio"=>"GBS",
"Instructables Direct"=>"INSTD",
"Instructables Membership"=>"INSTM",
"Instructables Other"=>"INSTO",
"Landmanagement"=>"LDMGT",
"mental ray Standalone"=>"MRSTND",
"MIMI"=>"MIMI",
"MotionBuilder Project 881"=>"MOB881",
"Oracle Support"=>"ORACLE",
"Project Evo Technology Preview 1"=>"ACS",
"RealDWG"=>"OBJ DBX",
"ServSupp Consulting"=>"CNSL",
"STREAMLINE"=>"STRM",
"SXF Converter"=>"SXFTRN",
"T1 Enterprise Multi-flex"=>"T1MF",
"T1 Enterprise Multi-flex Prior Version"=>"T1MFPV",
"Topobase Fiber"=>"TBFIBR",
"Virtual Geomatics"=>"VRTGEO",
"VISION"=>"VISION",
);

my %stopWords = map {$_ => 1} qw/able about above absent across afore after against all along alongside already also always amid amidst among amongst and another any apropos are around aside atop back barring been before behind being below beneath beside besides best between beyond both but can cannot cant circa concerning could despite does done down during each easy either else even ever every except excluding few first five following for four from full further get given good got had half has have her here high his how including inside instead into its just last less lest lets like live make man many may might minus modulo more most much must near need new next nine non none not notwithstanding now off once one only onto opposite other our out outside over pace past per plus pro put qua regarding round same sans save see set she should since since six some such sure ten than that the their them then there these they this those three through throughout thus till times to together too toward towards true two under underneath unlike until unto upon use versus very via vice want was were what when where whether which while who whom whose why will with within without worth would yes yet you your zero/;

#open my $in, "<$input"
my $in = new IO::Uncompress::Bunzip2("$input")
or die encode "utf-8", "Cannot read input file “$input”: $Bunzip2Error\n";

$/ = encode "utf-8", "◊÷\n";

my %glossary;
my $currentID = 0;
my %terms;
my $lastProduct = "";


my %xtraGlossary;
my %perLanguage;

while (<$in>) {
	my ($ID, $language, $product, $term) = split //, decode "utf-8", $_;
	
	if ($currentID != $ID) {
		if ($currentID && defined $terms{English}) {
			my $englishTerm = $terms{English};
			delete $terms{English};
			die encode "utf-8", "Unknown product: “$lastProduct”\n" unless defined $products{$lastProduct};
			if (defined $glossary{$products{$lastProduct}}->{$englishTerm}) {
				foreach (keys %terms) {
					if (defined $glossary{$products{$lastProduct}}->{$englishTerm}->{$localeMap{lc $_}}) {
						delete $glossary{$products{$lastProduct}}->{$englishTerm}->{$localeMap{lc $_}};
						delete $xtraGlossary{$englishTerm}->{$localeMap{lc $_}};
						
						delete $perLanguage{$localeMap{lc $_}}->{$englishTerm}->{$products{$lastProduct}};
						delete $perLanguage{$localeMap{lc $_}}->{$englishTerm} if (keys %{$perLanguage{$localeMap{lc $_}}->{$englishTerm}}) == 0;
					}
				}
			}
			foreach (keys %terms) {
				next if (keys %{$terms{$_}}) > 1;
				($glossary{$products{$lastProduct}}->{$englishTerm}->{$localeMap{lc $_}}) = keys %{$terms{$_}};
				
				foreach my $term (keys %{$terms{$_}}) {
					$xtraGlossary{$englishTerm}->{$localeMap{lc $_}}->{$term} = [] unless defined $xtraGlossary{$englishTerm}->{$localeMap{lc $_}}->{$term};
					push @{$xtraGlossary{$englishTerm}->{$localeMap{lc $_}}->{$term}}, $products{$lastProduct};
					
					$perLanguage{$localeMap{lc $_}}->{$englishTerm}->{$products{$lastProduct}} = $term;
				}
			}
		}
		$currentID = $ID;
		%terms = ();
	}
	$lastProduct = $product;
	next if defined $products{$product} && ($products{$product} eq "ZZ_3DSMAX_gloss" || $products{$product} eq "SFTIM_gloss");
	$term =~ s/^\s+|\s+$//g;
	my $x = $localeMap{lc $language} =~ /^zh/ ? 0 : 3;
	next if
		$term eq uc $term ||
		$term =~ /^\P{IsAlNum}?.{0,$x}$/ ||
		$term =~ /^\P{IsAlNum}{2,}/ ||
		$term =~ /^\P{IsAlNum}.*\P{IsAlNum}$/ ||
		$term =~ /\.\p{IsAlNum}/ ||
		$term =~ /^\P{IsAlpha}+\s/ ||
		$term =~ /^\P{IsAlpha}+$/ ||
		$term =~ /[\(\)\\\|\[\]\{\}\<\>\*\%\$\:\;\=\#]/;
	$term =~ s/\s+/ /g;
	$term =~ s/\"/\\\"/g;
	if ($language eq "English") {
		next if $term =~ /[\p{InCJKUnifiedIdeographs}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}\p{Script=Cyrillic}\p{Script=Tai_Viet}\/]/
		|| defined $terms{$language}
		|| (() = $term =~ / /g)+1 > 5
		;
		$term = lc $term;
		next if defined $stopWords{$term};
		$terms{$language} = $term;
	} else {
		$terms{$language}->{lc $term} = 1;
	}
}
my $englishTerm = $terms{English};
delete $terms{English};
die encode "utf-8", "Unknown product: “$lastProduct”\n" unless defined $products{$lastProduct};
if (defined $glossary{$products{$lastProduct}}->{$englishTerm}) {
	foreach (keys %terms) {
		if (defined $glossary{$products{$lastProduct}}->{$englishTerm}->{$localeMap{lc $_}}) {
			delete $glossary{$products{$lastProduct}}->{$englishTerm}->{$localeMap{lc $_}};
			delete $xtraGlossary{$englishTerm}->{$localeMap{lc $_}};

			delete $perLanguage{$localeMap{lc $_}}->{$englishTerm}->{$products{$lastProduct}};
			delete $perLanguage{$localeMap{lc $_}}->{$englishTerm} if (keys %{$perLanguage{$localeMap{lc $_}}->{$englishTerm}}) == 0;
		}
	}
}
foreach (keys %terms) {
	next if (keys %{$terms{$_}}) > 1;
	($glossary{$products{$lastProduct}}->{$englishTerm}->{$localeMap{lc $_}}) = keys %{$terms{$_}};
	
	foreach my $term (keys %{$terms{$_}}) {
		$xtraGlossary{$englishTerm}->{$localeMap{lc $_}}->{$term} = [] unless defined $xtraGlossary{$englishTerm}->{$localeMap{lc $_}}->{$term};
		push @{$xtraGlossary{$englishTerm}->{$localeMap{lc $_}}->{$term}}, $products{$lastProduct};
		
		$perLanguage{$localeMap{lc $_}}->{$englishTerm}->{$products{$lastProduct}} = $term;
	}
}

close $in;

%glossary = ();
#print encode "utf-8", "Total number of English terms found: ".scalar(keys %xtraGlossary)."\n";
my $ambiguousTerms = 0;
foreach my $term (sort {$a cmp $b} keys %xtraGlossary) {
	my $foundTerms = 0;
	my $toPrint = encode "utf-8", "$term ==>\n";
	foreach my $language (sort {$a cmp $b} keys %{$xtraGlossary{$term}}) {
		next unless (keys %{$xtraGlossary{$term}->{$language}}) > 1;
		$foundTerms = 1;
		$toPrint .= encode "utf-8", "\t$language ==>\n";
		foreach my $trans (sort {$a cmp $b} keys %{$xtraGlossary{$term}->{$language}}) {
			$toPrint .= encode "utf-8", "\t\t$trans (".join(", ", sort {lc $a cmp lc $b} @{$xtraGlossary{$term}->{$language}->{$trans}}).")\n";
			foreach my $product (sort {lc $a cmp lc $b} @{$xtraGlossary{$term}->{$language}->{$trans}}) {
				$glossary{$product}->{$term}->{$language} = $trans;
			}
		}
	}
	if ($foundTerms) {
#		print $toPrint;
		++$ambiguousTerms;
	}
}
#print encode "utf-8", "Total number of «ambiguous» English terms found: $ambiguousTerms\n";

#print encode "utf-8", scalar(keys %glossary).": ".join(", ", sort {lc $a cmp lc $b} keys %glossary)."\n";
print "\%glossary = (\n";
foreach my $product (sort {lc $a cmp lc $b} keys %glossary) {
	my %languages;
	print encode "utf-8", "\"$product\" =>\n{\nterms => [\n";
	foreach my $term (sort {$a cmp $b} keys %{$glossary{$product}}) {
		print encode "utf-8", "{\nterm => \"$term\",\n";
		foreach my $lang (sort {$a cmp $b} keys %{$glossary{$product}->{$term}}) {
			print encode "utf-8", "$lang => \"".$glossary{$product}->{$term}->{$lang}."\",\n";
#			print encode "utf-8", "$lang => '".join(", ", keys %{$glossary{$product}->{$term}->{$lang}})."',\n";
			$languages{$lang} = 1;
		}
		print "},\n";
	}
	print "],\nlanguages => {".join("=>1,", sort {$a cmp $b} keys %languages)."=>1}\n},\n";
}
print ")\n";


#use IO::Socket::INET;
#
#print encode "utf-8", "Language\tEnglish Term\tProduct\tTarget Term\n";
#foreach my $language (sort {$a cmp $b} keys %perLanguage) {
#	local $/ = "\n";
##	for (;;) {
#		#Connect to the MT Info Service
#		my $infoSocket;
#		while (!$infoSocket) {
#			$infoSocket = new IO::Socket::INET (PeerHost => "neucmslinux.autodesk.com", PeerPort => 2001);
#			sleep(60) unless $infoSocket;
#		}
#		$infoSocket->autoflush(1);
#		
#	print $infoSocket encode("utf-8", "{translate => ".(scalar keys %{$perLanguage{$language}}).", targetLanguage => ".($language eq "pt_pt" ? "pt_br" : $language)."}\n");
#		print $infoSocket encode("utf-8", "$_\n") foreach sort {$a cmp $b} keys %{$perLanguage{$language}};
#		$infoSocket->shutdown(1); #Won’t be writing anything else, so close socket for writing. This also sends EOF.
#		
#		my $data = <$infoSocket>; #Read return control sequence from MT Info Service.
#		unless ($data =~ /^\{\s*(?:\w+\s*=>\s*"?(?:[\w\-?"]+|\[(?:[\w\-"]+,?\s*)+\])"?,?\s*)*\}$/) {
#			$infoSocket->shutdown(0);
#			$infoSocket->close();
#			print STDERR encode("utf-8", "Bad response from MT Info Service: “$data”\n");
#			close STDOUT;
#			die;
#		}
#		
#		foreach my $term (sort {$a cmp $b} keys %{$perLanguage{$language}}) {
#			my $translation = decode "utf-8", scalar <$infoSocket>;
#			chomp $translation;
#			$perLanguage{$language}->{$term}->{MT} = lc $translation;
#			
#			foreach my $product (sort {$a eq "MT" ? -1 : ($b eq "MT" ? 1 : (lc $a cmp lc $b))} keys %{$perLanguage{$language}->{$term}}) {
#				print encode "utf-8", "$language\t$term\t$product\t".$perLanguage{$language}->{$term}->{$product}."\n";
#			}
#		}
#		
#		$infoSocket->shutdown(0);
#		$infoSocket->close();
##	}
#}

#use Data::Dumper;
#print encode "utf-8", Dumper($perLanguage{cs});



1;