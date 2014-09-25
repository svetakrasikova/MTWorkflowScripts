#!/usr/bin/env perl -ws
use strict;

use utf8;
use Encode qw(encode decode);
use IO::Compress::Bzip2 qw($Bzip2Error);
use IO::Uncompress::Bunzip2 qw($Bunzip2Error);

use threads;
use Thread::Queue;

use feature qw(say); # say 'something' == print 'something' . "\n";
use Data::Dumper;    # remove in production

use DBI;

use File::Basename;
use File::Spec::Functions;

use List::MoreUtils qw(uniq);

# Author: Samuel Läubli <samuel.laubli@autodesk.com>
# Created: Sep 17, 2014
# ---
# Description:
# Fetches all segments stored in the Athena TMs and aggregates them by language.

$ENV{'NLS_LANG'} = 'AMERICAN_SWITZERLAND.UTF8'; # needed to fetch perl-ready bytecode data from the DB

# DB Connection Parameters (Athena PRD)

# STAGING
#my $DB_PORT = 1521;
#my $DB_HOST="oracmsstg1.autodesk.com";
#my $DB_SERVICE_NAME = "CMSSTG1.autodesk.com";

# PRODUCTION
my $DB_PORT = 1521;
my $DB_HOST = "oracmsprd1.autodesk.com";
my $DB_SERVICE_NAME = "CMSPRD1.autodesk.com";


### MAIN ROUTINE ###
### ------------ ###

# parse command line arguments
our( $selection, $targetdir, $threads, $host, $service_name, $port, $user, $password );

# default values
$threads ||= 8;
$host ||= $DB_HOST;
$service_name ||= $DB_SERVICE_NAME;
$port ||= $DB_PORT;
die("Error: You must provide -user and -password to connect to the Athena database. Aborting")
	unless defined $user && defined $password;

if( defined $selection ) {
	die("Error: No target directory defined.\nUsage: $0 -selection=/path/to/file -outputdir=/path/to/output/directory\n")
		unless defined $targetdir;
	aggregateSegments($selection, $targetdir, $threads);
} else {
	listTMs();
}


### SUB ROUTINES ###
### ------------ ###

sub connectToDB {
	# Connect to an Oracle database
	# ---
	# parameters
	my( $host, $service_name, $port, $user, $password ) = @_;
	# connect
	my $db_handle = DBI->connect(
		"dbi:Oracle:host=$host;SERVICE_NAME=$service_name;port=$port", 
	    $user,
	    $password,
	    { RaiseError => 1, AutoCommit => 0 }
	);
	$db_handle->{RowCacheSize} = 50000; #increase the number of rows that are transmitted at once; increases speed
	return $db_handle; #database handle
}

sub executeQuery {
	# Executes an Oracle DB query
	# ---
	# parameters
	my( $db_handle, $query ) = @_;
	die "executeQuery() takes exactly two arguments: (1) the DB handle, (2) the query to be executed."
		unless defined $db_handle && defined $query;
	# execute query
	my $result = $db_handle->prepare($query);
	$result->execute();
	return $result #table handle (result set)
}

sub listTMs {
	# print available TMs, including their IDs and comments, to STDOUT
	# ---
	my $query = "SELECT DISTINCT
	('ZTM'||cast(tmlanguages.TMDATABASEID as varchar2(10))||'_TRANSLATIONS') as TMName,
	tmlanguages.TMDATABASEID as TMID,
	(cast(tmlanguages.LANGUAGEPAIRID as varchar2(15))) as TMLang,
	srclang.PRIMARYLANGCODE as srcPrim, srclang.SUBLANGCODE as srcSec,
	trglang.PRIMARYLANGCODE as trgPrim, trglang.SUBLANGCODE as trgSec,
	tmdatabases.NAME as TMDetails, tmdatabases.DESCRIPTION as description
FROM
	TMDATABASES
	INNER JOIN
	(TMLANGUAGES
		INNER JOIN
		LANGUAGES srclang
		ON
		srclang.LANGUAGEID = tmlanguages.SRCLANGID
		INNER JOIN
		LANGUAGES trglang
		ON
		trglang.LANGUAGEID = tmlanguages.TGTLANGID)
	ON
	tmdatabases.TMDATABASEID = tmlanguages.TMDATABASEID
WHERE
	srclang.PRIMARYLANGCODE = 'en'
	AND 
	(
	NOT regexp_like(tmdatabases.NAME, '^ ?_') AND
	NOT regexp_like(tmdatabases.NAME, 'tmp', 'i') AND
	NOT regexp_like(tmdatabases.NAME, 'test', 'i') AND
		(
			(
				NOT regexp_like(tmdatabases.DESCRIPTION, 'dummy', 'i') AND
				NOT regexp_like(tmdatabases.DESCRIPTION, 'not use', 'i')
			) OR
				tmdatabases.DESCRIPTION IS null
		)
	)
ORDER BY
	trgPrim ASC, trgSec ASC,
	TMDetails ASC";
	# connect to database and execute query
	my $db_handle = connectToDB($host, $service_name, $port, $user, $password);
	my $resultset = executeQuery($db_handle, $query);
	# print header
	say "# List of available TMs in Athena. Format:";
	say "# source language -> target language: details (description) ### TM_ID LANG_ID";
	say "# ---";
	say "# USAGE:";
	say "# (1) save this output to file: run $0 > /path/to/file";
	say "# (2) prefix TMs to be excluded by placing a # character (hashtag) at the beginning of the respective line(s) in this file.";
	say "# (3) run $0 -selection=/path/to/file -outputdir=/path/to/output/directory to fetch all segments from the non-excluded TMs and store them under /path/to/output/directory (one .bzipped file per language).";
	# iterate over rows
	my @row;
	while( @row = $resultset->fetchrow_array ) {
		my( $name, $tm_id, $lang_pair_id, $src_prim, $src_sec, $trg_prim, $trg_sec, $details, $description ) = @row;
		$trg_sec ||= '  ';
		# format details (product) column
		$details =~ s/^\s+|\s+$//g; # trim whitespace on both ends
		$details = '`' . $details . "`";
		my $column_width = 30;
		if( length($details) < $column_width ) {
			$details = $details . ' ' x ($column_width - length($details));
		} 
		# format description column
		if( $description ) {
			$description =~ s/\R//g; #remove linebreaks
			$description =~ s/^\s+|\s+$//g; #trim whitespace on both ends
			$description .= ' ';
		} else {
			$description = '';
		}
		# print row
		print "$src_prim -> $trg_prim\_$trg_sec: $details $description### $tm_id $lang_pair_id\n";
	}
	say "# This output must be saved to a file for further processing. Run $0 > /path/to/file and see the top of that file for further instructions.";
	# disconnect from database
	$db_handle->disconnect();
}

sub readSelection {
	# read selections file, line by line
	# ---
	# params
	my( $selection_filepath ) = @_;
	# open file obtained in when running this program without the -selection argument
	open(my $fh, '<', $selection_filepath)
		or die "Error: Cannot open '$selection_filepath'. Aborting";
	my $languages = {};
	my $line_number = 0;
	while (<$fh>) {
		$line_number++;
		# select rows (TMs) that are not excluded (i.e., not commented out by means of a hashtag at the beginning of the line)
		if( $_!~/^#.*/ ) {
			# extract TM and language pair IDs
			my( $tgt_lang_prim, $tgt_lang_sec, $prod_name, $tm_id, $lang_pair_id ) = ($_ =~ m/en -> (..)_(..): `(.+)`.*### (\d+) (\d+)$/g);
			die "Error: Cannot parse line $line_number in file '$selection_filepath'. Aborting"
				unless defined $tgt_lang_prim && defined $tgt_lang_sec && defined $prod_name && defined $tm_id && defined $lang_pair_id;
			my $tm_name = 'ZTM' . $tm_id . '_TRANSLATIONS';
			my $lang_string = $tgt_lang_prim;
			if( not $tgt_lang_sec eq '  ' ) {
				$lang_string .= "_$tgt_lang_sec"
			}
			# store information in %languages
			my $product = { lang_pair_id => $lang_pair_id, tm_name => $tm_name, prod_name => $prod_name };			
			unless( exists($languages->{$lang_string}) ) {
				$languages->{$lang_string} = [];
			}
			push($languages->{$lang_string}, $product);
		}
	}
	return $languages;
}

sub fetchSegments {
	# fetches all segments from a TM, given (1) the TM name and (2) the language pair ID
	# writes the segments to file (using the provided file handle)
	# ---
	# params
	my( $tm_name, $lang_pair_id, $product_name, $db_handle, $file_handle ) = @_;
	die("Error: Not enough parameters specified for fetchSegments(). Aborting")
		unless defined $tm_name && defined $lang_pair_id && defined $db_handle && defined $file_handle;
	my $query = "SELECT SOURCEVC, TARGETVC FROM $tm_name WHERE LANGUAGEPAIRID = $lang_pair_id";
	my $resultset = executeQuery($db_handle, $query);
	while( my @row = $resultset->fetchrow_array ) {
		my $segment_src = $row[0];
			$segment_src = '' unless defined $segment_src; #use empty string for NULL field
			$segment_src =~ s/^\s+|\s+$//g; #trim whitespace on both ends
		my $segment_tgt = $row[1]; 
			$segment_tgt = '' unless defined $segment_tgt; #use empty string for NULL field
			$segment_tgt =~ s/^\s+|\s+$//g; #trim whitespace on both ends
		print $file_handle encode "utf-8", "$segment_src\x{F8FF}$segment_tgt\x{F8FF}$product_name\x{F8FF}◊÷\n";
	}
}

sub aggregateSegments {
	# extract segments from TMs and store them to one bzipped file per language
	# ---
	# params
	my( $selection_filepath, $target_dir, $threads ) = @_;
	# parse selections file
	my $tms_by_languages = readSelection($selection_filepath);
	# create thread queue	
	my $language_queue = new Thread::Queue;
	# define subroutine to be executed in parallel (thread-wise)
	my $processLanguage = sub {
		# extract all segments from a given languages from all relevant TMs
		# ---
		while (1) {
			my $params;
			# end condition
			unless ($params = $language_queue->dequeue()) {
				print "Thread " . threads->tid() . ": Finished work!\n";
				last; # end condition (exit from loop)
			}
			# loop
			my( $target_dir, $lang_string, $tms ) = @$params;
			my $target_filepath_current_language = catfile($target_dir, 'segments.' . $lang_string . '.bz2');
			my $db_handle = connectToDB($host, $service_name, $port, $user, $password);
			my $file_handle = new IO::Compress::Bzip2 "$target_filepath_current_language"
				or die "Error: Cannot write to '$target_filepath_current_language'. Aborting";
			# for each TM (product)...
			foreach my $tm (@{$tms}) {
				fetchSegments( $tm->{tm_name}, $tm->{lang_pair_id}, $tm->{prod_name}, $db_handle, $file_handle );
			}
			# disconnect from database
			$db_handle->disconnect();
		}
	};
	# create workers (one per thread)
	my @workers = map { scalar threads->create($processLanguage) } 1..$threads; #@workers contains thread references
	# for each language...
	while ( my( $lang_string, $tms ) = each $tms_by_languages ) {
		#next unless $lang_string eq "ar_SA" || $lang_string eq "ro_RO"; #DEBUG: Test on two rather small languages only
		$language_queue->enqueue( [$target_dir, $lang_string, $tms] ); # pass all agruments as a single array to the queue
	}
	$language_queue->enqueue(undef) foreach 1..$threads; #tell there's no more work after we've added everything
	$_->join() foreach @workers;
}