#!/usr/local/bin/perl -ws
#
# reorder_jpn.pl
#
# ©2011–2014 Autodesk Development Sàrl
# Based on scripts by Hidenori Yoshizumi
#
#
# Reorder English data to better match Japanese word order
#
# ChangeLog
# v3.2.3		Modified by Ventsislav Zhechev on 28 Feb 2014
# Fixed some regression bugs.
#
# v3.2.2		Modified by Ventsislav Zhechev on 08 May 2013
# Added a waiting mechanism to make sure that we don’t overuse memory when quickly processing a large batch of data.
#
# v3.2.1		Modified by Ventsislav Zhechev on 25 Jan 2013
# Fixed some checks for empty strings. The string ‘0’ is false but not empty, so we need to check for equality with "" instead. Sometimes, it’s even better to use the regex /^\s*$/.
#
# v3.2			Modified by Ventsislav Zhechev on 10 May 2012
# Simplified the program flow during post-processing one and reordering.
#
# v3.1.2
# Added some debug functionality to help figure out the occurrence of too short segments in the output.
#
# v3.1.1
# Fixed a bug where empty lines would not be handled properly leaving a parse tree as the output string.
#
# v3.1
# Simplified placeholder masking to reflect current usage of placeholders.
# Switched to using a Thread::Queue for passing on non-parsable data instead of a shared hash.
#
# v3.0.1
# Fixed a bug where the parser could not be started properly when a log file name was provided as part of a subcommand.
#
# v3.0
# Now using open3 to launch the parser if we want to save its log output to a file, thus avoiding the use of a shell.
#
# v2.9.1
# Updated end condition to avoid a dead loop on exit. Now the parser input is being closed in a timely manner to indicate the end of data and allow it to exit properly.
#
# v2.9
# Initial production version
#
################################

use strict;
use IPC::Open2;
use IPC::Open3;

use threads;
use threads::shared;
use Thread::Queue;

$| = 1;


##############JPN###############
my $level; # check level to avoid infinit loop

# list grammatically problematic element with lower case

# Element to move towards the begining				
my @langElement = (
"(sbar ",
"(s ",
"(vp (to to) (vp ",
"(vp (to to) (advp ",
"(vp (to to) (vb ",
"(wdt ",
"(pp (in ",
"(pp (to ",
);

# Element to move towards the end					
my @langElement2 = (
"(vb ",
"(vbd ",
"(vbg ",   
#					"(vbn ",	# exception
"(vbp ",
"(vbz ",
"(vp ",
"(in ",
"(md ",	# can, could, will, would ...
"(to to",  # to
"(rb not",
"(rb 't",
);

# Element to skip (then handle as exception)
my @langElementSkip = (
"(vp (vbn",     # past participle ex. given
"(vp (vbg",     # present participle ex. making
"(vp (vbd",     # 
);

##############JPN###############

our ($input, $output, $parser_cmd, $debug);
die "Usage: $0 -parser_cmd=\"…\" [-input=…] [-output=…] [-debug]\n" unless defined $parser_cmd;

$input ||= '-';
$output ||= '-';
my $berkeley = $parser_cmd =~ /berkeley/;
my $charniak = $parser_cmd =~ /reranking/ unless $berkeley;
my $stanford = $parser_cmd =~ /stanford/ unless $berkeley || $charniak;
$parser_cmd =~ s/ 2>([^\"]*)$//;
my $parser_log = $1;


if ($input ne '-') {
	close STDIN;
	open (STDIN, "<$input")
	or die "Cannot read file $input\n";
}
if ($output ne '-') {
	close STDOUT;
	open (STDOUT, ">$output")
	or die "Cannot write to file $output\n";
}

print STDERR " Perl version used: $]\n" if defined $debug;

if ($parser_log) {
	open \*PARSE_ERR, ">$parser_log"
	or die "Could not create parser log file at “$parser_log”!\n";
}
local(*PARSE_IN, *PARSE_OUT);
my $parserProcess = ($parser_log ? open3(\*PARSE_IN, \*PARSE_OUT, ">&PARSE_ERR", $parser_cmd) : open2(\*PARSE_OUT, \*PARSE_IN, $parser_cmd))
or die "Could not start parser with command “$parser_cmd”!\n";
select PARSE_IN;
$| = 1;
select PARSE_OUT;
$| = 1;


local $SIG{PIPE} = sub { die "Parser pipe seems to be broken. Aborting…\n" };
#open CRAP1, ">before.numbers";
#open CRAP2, ">after.numbers";


my $thruLineCounter =
my $affectedLineCounter =
my $sentID =
my $thruID =
my $pseudoThruID =
0;
#my $finishedReading :shared = -1;

#my @thruLines =
my %thrus :shared =
#my %cmds :shared =
();

my $commandQueue = new Thread::Queue;

#my $threadIsRunning = 0;
#my $reorderThread;
my $reorderThread = threads->create(\&processParseOutput);

close PARSE_OUT;

sleep 1;

while (my $inputLine = <STDIN>) {
	chomp $inputLine;
	unless ($. % 10000) {
		print STDERR "·";
		print STDERR "[reorder in: $.]" unless $. % 500000;
	}

	#DEBUG
#	next unless $inputLine =~ /3ds Max to Maya/;
	#DEBUG
	
	++$sentID;
	
#	unless ($inputLine =~ /\{/) {
#		print STDOUT "$inputLine\n";
#		next;
#	}
	
	#Mask placeholders
	$inputLine =~ s/\{(\d+)\}/$1/g;
	
	#PREPROCESS ONE
	# handle sentence-internal ‘.’
	if ($inputLine =~ /\s\.\s/) {
		++$affectedLineCounter;
			
		my @buf = split /\s\.\s/, $inputLine;
		for (my $index = 0; $index < $#buf; ++$index) {
			{ lock(%thrus);
				$thrus{++$thruID} = $sentID;
			}
			&sendToParser("$buf[$index] .");
		}
		{ lock(%thrus);
			$thrus{++$thruID} = $sentID;
		}
		&sendToParser($buf[$#buf]);
			
		# handle sentence-internal ‘::’
	} elsif ($inputLine =~ /\s::\s/) {
		++$affectedLineCounter;
		
		my @buf = split /\s::\s/, $inputLine;
		for (my $index = 0; $index < $#buf; ++$index) {
			{ lock(%thrus);
				$thrus{++$thruID} = $sentID;
			}
			&sendToParser("$buf[$index] :"); #‘::’ needs to be masked to prevent the parser from splitting it
		}
		{ lock(%thrus);
			$thrus{++$thruID} = $sentID;
		}
		&sendToParser($buf[$#buf]);
		# standard non-splitting case
	} else {
		{ lock(%thrus);
			$thrus{++$thruID} = $sentID;
		}
		sleep 30 while $commandQueue->pending() > 100000;
		&sendToParser($inputLine);
	}
	
}

close PARSE_IN;

#print STDERR "FININSHED READING DATA!!! @\@$thruLineCounter\n";
#{ lock($finishedReading);
#	$finishedReading = $thruLineCounter;
#}

$reorderThread->join();

waitpid($parserProcess, 0);
close PARSE_ERR if $parser_log;

print STDERR "Number of lines split due to in-line ‘.’ or ‘::’ are: $affectedLineCounter\n";

# This subroutine takes care of the second pre-processing step and sends the segments to the parser. Too long/complex sentences are being pushed through unchanged by sending an empty string for parsing. The reason is that too long/complex sentences have little chance of being correctly parsed/reordered.
sub sendToParser {
#	while (my $thruLine = shift @thruLines) {
	my $thruLine = shift;
	++$thruLineCounter;
		
	#PREPROCESS TWO
	#
	# cmd line
	#
#	{ lock(%cmds);
		my $tokens = () = split ' ', $thruLine, -1;
#		$commandQueue->enqueue($tokens);
#		if ((() = split ' ', $thruLine, -1) > 50 || $thruLine =~ /,/g > 10) {
		if ($tokens > 50 || $thruLine =~ /,/g > 10) {
			print STDERR "Line $thruLineCounter has more than 50 words or more than 10 commas! Not parsing…\n";
#			$cmds{$thruLineCounter} = $thruLine;
			$commandQueue->enqueue($thruLine);
			$thruLine = '';
		} elsif ($] >= 5.010) { #Do we have a recent version of Perl?
			#The regex needs to be saved in a string, or earlier versions of Perl won’t compile properly, even though they’ll never get to run this code
			my $re = '(?|
			# case 1: [ opt1 / opt2 / opt3 ]
			(\[\s?\w+(?:\s?\/\s?\w+\s?)+\].*)$|
			# case 2: [ word1 word2 ]
			(\[\s?[a-zA-Z\s\(\)]+\s?\]\s?:?)$|
			# case 3: [ opt1 opt2 opt3 ] < opt1 > :
			((?:\[\s?.+\s?\]\s?)?<\s?.+\s?>\s?:\s*)$|
			# case 4:
			(:\s*%\d!s!)$|
			# case 5: ":" and "..." at the end
			(:|\.\.\.)\s*$|
			# case 6: &submenu;
			(^.*&submenu;.*$)
			)';
			if ($thruLine =~ s/$re//x) {
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
			} else {
				$commandQueue->enqueue(undef);
			}
			
			#
			# Some special cases
			#
			# other < x > case
			$thruLine =~ s/<\s(%\w+)\s>/<$1>/g;
			# other [ x ] case
			$thruLine =~ s/\[\s([\w0-9]+)\s\]/\[$1\]/g;
			
			$thruLine = "" if $thruLine =~ /^\s*$/; #Mask lines that need to be skipped so that the parser doesn’t choke on them
		} else { #Deprecated branch to support versions of Perl before 5.10.0
			# case 1: [ opt1 / opt2 / opt3 ]
			if ($thruLine =~ s/(\[\s?\w+(\s?\/\s?\w+\s?)+\].*)$//) {
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
				# case 2: [ word1 word2 ]
			} elsif ($thruLine =~ s/(\[\s?[a-zA-Z\s\(\)]+\s?\]\s?:?)$//) {
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
				# case 3: [ opt1 opt2 opt3 ] < opt1 > :
			} elsif ($thruLine =~ s/((\[\s?.+\s?\]\s?)?<\s?.+\s?>\s?:\s*)$//) {
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
				# case 4:
			} elsif ($thruLine =~ s/(:\s*%\d!s!)$//) {
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
				# case 5: ":" and "..." at the end
			} elsif ($thruLine =~ s/(:|\.\.\.)\s*$//) {
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
				# case 6: &submenu;
			} elsif ($thruLine =~ s/(^.*&submenu;.*$)//) { #Mask lines that need to be skipped so that the parser doesn’t choke on them
#				$cmds{$thruLineCounter} = $1;
				$commandQueue->enqueue($1);
			} else {
				$commandQueue->enqueue(undef);
			}

			#
			# Some special cases
			#
			# other < x > case
			$thruLine =~ s/<\s(%\w+)\s>/<$1>/g;
			# other [ x ] case
			$thruLine =~ s/\[\s([\w0-9]+)\s\]/\[$1\]/g;
		}
#	}
		
	#PARSE
	#Call external parser
	if ($berkeley || $stanford) {
		$thruLine =~ s/(\(|\))/"-".($1 eq '(' ? "L" : "R")."RB-"/ge;
#			$thruLine =~ s/(\[|\])/"-".($1 eq '[' ? "L" : "R")."SB-"/ge;
#			$thruLine =~ s/(\{|\})/"-".($1 eq '{' ? "L" : "R")."CB-"/ge;
	} elsif ($charniak) {
		$thruLine = "<s> $thruLine </s>";
	}
#		print STDERR "\@$thruLineCounter: “$thruLine”\n";
#	print CRAP1 "$thruLineCounter\t$thrus{$thruLineCounter}\n";
	print PARSE_IN "$thruLine\n";
#		$reorderThread = threads->create(\&processParseOutput) unless $threadIsRunning;
}

##############################################################
# This subroutine processes (i.e. reorders and post-processes) the parser output and—if necessary—puts split sentences together before outputting the result. It operates in a tight loop in a secondary thread greadily consuming any output coming from the parser until all segments from the input side have been read from the parser.
sub processParseOutput {
#	print STDERR "………In reordering thread…\n";
	close PARSE_IN;
	my $printLine =
	my $pseudoThruID =
	0;
	my $outLine = "";
#	my $currID;
	
	while (my $thruLine = <PARSE_OUT>) {
		++$pseudoThruID;

		chomp $thruLine;
		
		if ($berkeley) {
			$thruLine =~ s/^\( (.*) \)$/$1/;
			#			$thruLine =~ s/-(L|R)(S|C)B-/my ($l, $s) = ($1 eq 'L', $2 eq 'S'); if ($l && $s) {'['} elsif ($s) {']'} elsif ($l) {'{'} else {'}'}/ge;
		}
		

#		my $tokens = $commandQueue->dequeue();
		my $currCommand = $commandQueue->dequeue();
#		my $newTokens;
#		$newTokens = () = split ' ', $currCommand, -1 if $currCommand;
		
		#POSTPROCESS ONE
		if ($thruLine eq "" && defined $currCommand) {
			print STDERR "Bad line $thrus{$pseudoThruID}: “$thruLine” with cmd “$currCommand”\n" if $debug;
			$thruLine = $currCommand;
		} elsif ($thruLine ne "") {
#			my $preReorderTokens = () = $thruLine =~ /( [^\(\)]+\))/g;
#			my $preReorderLine = $thruLine;
			#REORDER
			$thruLine = &reorder($thruLine, $pseudoThruID) if $thruLine =~ /^\(.*\)$/; #Do not reorder non-parsed lines

			# clean space
			$thruLine =~ s/(^\s+)|(\s+$)//g;
			$thruLine =~ s/\s+/ /g;
			
#			my $postReorderTokens = () = split ' ', $thruLine, -1;
#			warn "!!! BREAKDOWN !!! Token number mismatch before and after REORDERING on line $thrus{$pseudoThruID}: $preReorderTokens vs. $postReorderTokens\n“$preReorderLine”\n“$thruLine”\n" unless $preReorderTokens == $postReorderTokens;
			
			#POSTPROCESS ONE
			#Do we need this? We should probably mask any XML/HTML tags to avoid scrambling. (cf. PH-masking)
			# other < x > case
#			$thruLine =~ s/<(%\w+)>/< $1 >/g;
			
			# other [ x ] case
#			$thruLine =~ s/\[([\w]+)\]/\[ $1 \]/g;

#			$newTokens += $postReorderTokens;
			
			$thruLine .= " $currCommand" if $currCommand;

#			warn "!!! BREAKDOWN !!! Token number mismatch on line $thrus{$pseudoThruID}: $tokens vs. $newTokens\n“$thruLine”\n\n" unless $newTokens == $tokens;
		}
		
		
		
		#POSTPROCESS TWO
		#Reconstitute split lines
		{ lock(%thrus);
			if (!defined($thrus{$pseudoThruID-1}) || $thrus{$pseudoThruID} != $thrus{$pseudoThruID-1}) { #This is not a continuation of a previous line
				$outLine = $thruLine;
				unless (defined $thrus{$pseudoThruID+1} && $thrus{$pseudoThruID} == $thrus{$pseudoThruID+1}) {
					delete $thrus{$pseudoThruID}; #Only undef if there is no continuation to this line
					$printLine = 1;
				}
			} else { #This is a continuation of a previous line
				$outLine .= " $thruLine";
				if (!defined($thrus{$pseudoThruID+1}) || $thrus{$pseudoThruID} != $thrus{$pseudoThruID+1}) { #Cleanup if there is no continuation to this line
					for (my $id = $pseudoThruID; defined $thrus{$id}; ) {
						delete $thrus{$id} if defined $thrus{--$id} && $thrus{$pseudoThruID} == $thrus{$id};
					}
					delete $thrus{$pseudoThruID};
					$printLine = 1;
				}
			}
		}
		
		if ($printLine) {
			unless ($printLine % 10000) {
				print STDERR "•";
				print STDERR "[reorder out: $printLine]" unless $printLine % 500000;
			}
			#Unmask placeholders
			$outLine =~ s/(\d+)/{$1}/g;
			$outLine =~ s/:/::/g;
	
			print STDOUT "$outLine\n";
			$printLine = 0;
			$outLine = "";
		}
	}

	close PARSE_OUT;
	close STDOUT;
	return;
}




################################
##### PSEUDO JAPANESE CODE #####
################################

sub reorder {
	my $line = shift;
	my $counter = shift;

	my @result;
	
	$level = 0;
#	print STDERR "Line:\t$counter\t$line\n";
	unless ($stanford) {
		print "$.: “$line”\n" if $debug;
		@result = pseudo_jpn($line, $counter);
		print "$.: “$result[1]”\n" if $debug;
	} else {
#		print STDERR "$.: “$line”\n";
		$line =~s /(\(vp(?:\=h)?) \(to(?:\=h) (\w+)\) (\(vp(?:\=h)? \(vb(?:\=h)? )/$1 $3$2 /gi;
		@result = &headBasedReorder($line);
	}
	
	# special NLP characters
	$result[1] =~ s/^\s*//;
	$result[1] =~ s/\-LRB\-/\(/g;
	$result[1] =~ s/\-RRB\-/\)/g;
	$result[1] =~ s/\-LCB\-/\{/g;
	$result[1] =~ s/\-RCB\-/\}/g;
	
	$result[1] =~ s/\s+/ /g;
	
	$result[1];
}



sub headBasedReorder {
	my $tree = shift;
	
	(my $topLabel, my $isHead, $tree) = $tree =~ /^\s*\(([\w\.\,\!\?\:\$\-\'\#\`]+(\=H)?) +(.*)\)\s*$/;
	return ($isHead, $tree) unless $tree =~ /\(/;
	
	$isHead &&= !($topLabel =~ /^(in|to|sbar|s|wnph)(\=h)$/i);
	
	my @children;
	push @children, $_ while $_ = &nextChild(\$tree);
	
	$isHead &&= !(($topLabel =~ /^vp/i && $children[0] =~ /^to/i) || ($topLabel =~ /^pp/i && $children[0] =~ /^in/i));
#	if ($topLabel =~ /^vp/i && $children[0] =~ /^to/i && $children[1] =~ /^vp/i) {
#		$children[0] =~ /^to(\=h) //i;
#		$children[1] =~ /^(vp(?:\=h)? \(vb(?:\=h)? )/$1$children[0] /i;
#		unshift @children;
#	}
	
	my $hasConjunction = 0;
	map { $hasConjunction ||= $_ =~ /\([^\(\)]+\s+(and|or|\,|-RRB-|-LRB-|\<|\>|\;|\[|\])\)/ } @children;
	return ($isHead, join " ", map {(&headBasedReorder($_))[1]} @children) if $hasConjunction;
	
	my (@strChildren, $headChild, $punctuation);
	foreach (reverse @children) {
		my ($head, $child) = &headBasedReorder($_);
		if ($head) {
			$headChild = $child;
		} elsif (!$punctuation && $child =~ /^[\.\!\?…]+|:$/) {
			$punctuation = $child;
		} else {
			unshift @strChildren, $child;
		}
	}
	$headChild ||= "";
	
	return ($isHead, (@strChildren ? join " ", @strChildren, "" : "").$headChild.(defined $punctuation ? " $punctuation" : ""));
}

sub nextChild {
	my $tree = shift; #This is a ref! We need that to keep stripping off children from the tree.
	return $$tree = "" unless $$tree =~ /\(/;
	
	my $parens = 0;
	$$tree =~ s/^\s+//;
	
	my $pos;
	for ($pos = 0; $pos < length $$tree; ++$pos) {
		$parens += (map {$_ eq '(' ? 1 : ($_ eq ')' ? -1 : 0)} (substr($$tree, $pos, 1)))[0];
		last unless $parens;
	}
	my $child = substr($$tree, 0, $pos+1);
	$$tree = $pos+1 < length $$tree ? substr($$tree, $pos+1) : "";
	return $child;
}


# -------------------------------------------------------------------------------------------------
# pseudo_jpn
#
# recursive: reorder phrase only in the same level using NLP tag
#
#
# CODE VERSION 1
#sub pseudo_jpn {
#	my ($phrase, $counter) = @_;
#	
#	# Check level if less than 
#	if ($level++ > 1000) {
#		print STDERR "\n\n WARNING: unknown tag: $phrase" if $debug;
##		exit;
#		return;
#	}
#	
#	print STDERR "enter --> $phrase \n" if $debug;
#	
#	# Extract content of this level by removing "([tag]" and ")"
#	$phrase =~ m/^(\([\w\-\$\.:,'\#`]*)\s(.*)(\))$/;    #'
#	
#	my $top = $1;
#	my $content = $2;
#	my $tail = $3;
#	my @result = (); # $[0]: $IsToMove, $[1]: processed phrase
#	my $pPrase = ""; # pseudo jpn phrase
#	my $IsToMove = 0;
#	
#	my @newPhrase;
#	
#	if ($top eq "(TOP") {
#		# Top most level
#		$newPhrase[0] = $content;
#		#	} elsif ($top eq "(INC") {
#		
#	} else {
#		
#		print STDERR $phrase . "\n" if $debug;
#		
#		# Check elements to move towards end.
#		# (To to) case is exception
#		unless ($phrase =~ /^\(vp \(to to\) \(v/i) {
#			foreach my $elm (@langElement2) {
#				print STDERR "………checking $elm against phrase\n" if $debug;
#				if ($phrase =~ /^\Q$elm\E/i) {
#					$IsToMove = -1;
#					print STDERR "--> $phrase\n" if $debug;
#					last;
#					#					exit;
#				}
#			}
#		}
#		# Check elements to move towards begining
#		foreach my $elm (@langElement) {
#			print STDERR "………checking $elm against phrase\n" if $debug;
#			if ($phrase =~ /^\Q$elm\E/i) {
#				$IsToMove = 1;
#				print STDERR "\t@ $phrase" . "\n" if $debug;
#				last;
#				#				exit;
#			}
#		}
#		
#		#
#		# Exceptions
#		#
#		if ($phrase =~ /^\(pp \(in in\)/i) {
#			$IsToMove = 0;
#		}
#		if ($phrase =~ /^\(in if\)/i) {
#			$IsToMove = 0;
#		}
#		
#		# Consider verb elements
#		($content, $IsToMove) = move_verb_element($phrase, $content, $IsToMove);
#		
#		# Find the next nested level
#		@newPhrase = find_next_level($content);
#		
#		#
#		# no more lower level : End condition of this recursive call
#		#
#		if (scalar @newPhrase == 0) {
#			print STDERR "no more lower level: $phrase \n" if $debug;
#			# 
#			$content =~ s/^\s*//;
#			return ($IsToMove, $content);
#		}
#		
#		#
#		# if there is only one, use the same result as child
#		#
#		return pseudo_jpn($newPhrase[0], $counter) if @newPhrase == 1;
#		
#	}
#	
#	#
#	# Reconstruct the phrase by changing order
#	#
#	
#	my $separatePos;
#	
#	$separatePos = is_comman_exist (@newPhrase);
#	
#	if ($separatePos > 0) {
#		print STDERR "== separate case ==\n" if $debug; # DEBUG
#		my @part1 = @newPhrase[0 .. $separatePos-1];
#		my @part2 = @newPhrase[$separatePos+1 .. $#newPhrase];
##		my $connection = $newPhrase[$separatePos];
##		
##		$connection =~ /\s([,&\w\[\]\/]+)\)$/i;
##		$connection = $1;
#
#		my ($connection) = $newPhrase[$separatePos] =~ /\(cc\s([^\s]+)\)$/i;
#
#		
#		my @result1 = pseudo_jpn("(top " . join(" ", @part1) . ")", $counter);
#		my @result2 = pseudo_jpn("(top " . join(" ", @part2) . ")", $counter);
#		
#		$pPrase = $result1[1] . " " . $connection . " " . $result2[1];
# 		print STDERR "temp result: $phrase\n" if $debug;
#		
#	} else {
#		# Normal case
#		print STDERR "== normal case ==\n" if $debug; # DEBUG	
#		my @easyClause;
#		my @hardClause;
#		my @verb;
#		my $period = "";
#		my $previousMove = 0;
#		
#		foreach my $tmp (@newPhrase) {
#			my @tmpResult = pseudo_jpn($tmp, $counter);
#			
#			if ($tmpResult[0] == 1) {
#				push (@hardClause, $tmpResult[1]);
#			} elsif ($tmpResult[0] == -1) {
#				print STDERR "\t<-- $tmpResult[1]" . "\n" if $debug; # DEBUG
#				push (@verb, $tmpResult[1]);
#			}else {
#				if ($tmpResult[1] =~ /^(\.|\?)$/) {
#					$period = " $1";
#				} elsif ($tmpResult[1] =~ /^,$/) {
#					# "," will follow the previous word???
#					if ($previousMove == 0) {
#						push (@easyClause, $tmpResult[1]);
#					} elsif ($previousMove == 1) {
#						push (@hardClause, $tmpResult[1]);
#					} elsif ($previousMove == -1) {
#						push (@verb, $tmpResult[1]);
#					}
#				} else {
#					push (@easyClause, $tmpResult[1]);
#				}
#			}
#			$previousMove = $tmpResult[0];
#		}
#		
#		# Check: there should be only one element
#		if (scalar @hardClause > 1) {
#			print STDERR "$counter - WARNING: more than one grammatically difficult element\n" if $debug;
#			print STDERR join(" : ", @hardClause) . "\n" if $debug;
#		}
#		if (scalar @verb > 1) {
#			print STDERR "$counter - WARNING: more than one verb elements\n @verb\n" if $debug;
#		}
#		
#		$pPrase = join(" ",  @hardClause) . " " . join(" ", @easyClause) . " " . join(" ", @verb) . $period;
#	}
#	
#	# clean spaces
#	$pPrase =~ s/^\s*//;
#	
#	print STDERR "\t <-- $pPrase\n" if $debug;
#	return ($IsToMove, $pPrase);
#}
#
##
## find_next_level
##
##   Used by pseudo_jpn to find the next level of nested phrase
##
#sub find_next_level () {
#	my ($phrase) = @_;
#	
#	print STDERR ">>> $phrase\n" if $debug; # DEBUG
#	
#	my @buf = split(//, $phrase);
#	my $openCounter = 0; # count "("
#	
#	my $tmpString = "";
#	my @result = ();
#	
#	# Check if there is no "(" at the begining...
#	# this means this is the leaf
#	unless (@buf && $buf[0] eq "(") {
#		return @result;
#	}
#	
#	print STDERR "\n--- BEGIN ---\n" if $debug;
#	
#	foreach my $char (@buf) {
#		print STDERR "$char " if $debug;
#		if ($char eq "(") {
#			$openCounter += 1;
#			print STDERR "$openCounter" if $debug;
#		} elsif ($char eq ")") {
#			$openCounter -= 1;
#			print STDERR "$openCounter" if $debug;
#		}
#		
#		if ($openCounter == 0) {
#			# counter=0 means there are equal number of ( and )
#			$tmpString .= "$char";	
#			
#			# space between substrings gives empty string
#			if ($tmpString eq " ") {
#				# Just clean until some character appears...
#				$tmpString = "";
#			} else {
#				print STDERR "\n" . $tmpString . "\n" if $debug;
#				push (@result, $tmpString);
#				$tmpString = "";
#			}
#		} else {
#			$tmpString .= "$char";	
#		}
#	}
#	
#	print STDERR "\n--- END ---\n" if $debug;
#	
#	return @result;
#}
#
##
## move_verb_element
##
## move verb elements such as "to", "can", "have", "has", etc
## so that these words remains next to the verb
##
#sub move_verb_element () {
#	print STDERR "÷÷÷ Trying to move_verb_element…\n" if $debug;
#	my ($phrase, $content, $IsToMove) = @_;
#	
#	# (To to) case 1: move "to" with the verb
#	if ($phrase =~ /^\(vp \(to to\) \((v|advp)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		# with ADVP
#		if ($phrase =~ /\(to to\) \(advp /i) {
#			$phrase =~ s/^\(vp \(to to\) \(advp \(rb (\w+)\)\) (.+\(vb)\s([^\(]+)\)/\(VP \(TO \) $2 to $1 $3\)/i;
#		} elsif ($phrase =~ /^\(vp \(to to\) \(vp \(vb be\)/i) {
#			# with to be VBN
#			
#			# with ADJP
#			if ($phrase =~ /^\(vp \(to to\) \(vp \(vb be\) \(adjp/i) {
#				$phrase =~ s/^\(vp \(to to\) \(vp \(vb be\)/\(VP \(To \) \(VP \(VB to be\)/i;
#			} else {
#				$phrase =~ s/^\(vp \(to to\) \(vp \(vb be\)/\(VP \(To \) \(VP \(VB \)/i;
#				$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN to be $2\) $3/i;
#			}
#		} else {
#			$phrase =~ s/^\(vp \(to to\)/\(VP \(To \)/i;
#			$phrase =~ s/(\(vb (\w+)\))(.+)/\(VB to $2\) $3/i;
#		}
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;     #'
#		$content = $2;
#	}
#	# (To to) case 2: "in order to"
#	if ($phrase =~ /^\(sbar \(in in\) \(nn order\) \(s \(vp \(to to\)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		if ($phrase =~ /\(rb not\)/i) {
#			$phrase =~ s/^\(sbar \(in in\) \(nn order\) \(s \(vp \(rb not\) \(to to\) \(vp \(vb (\w+)\)/\(SBAR \(IN \) \(NN \) \(S \(VP \(RB \) \(TO \) \(VP \(VB in order not to $1\)/i;
#		} else {
#			$phrase =~ s/^\(sbar \(in in\) \(nn order\) \(s \(vp \(to to\) \(vp \(vb (\w+)\)/\(SBAR \(IN \) \(NN \) \(S \(VP \(TO \) \(VP \(VB in order to $1\)/i;
#		}
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;    #'
#		$content = $2;
#	}
#	
#	#
#	# MD --------------------------------------------------------------------------------------------------------------------
#	#
#	
#	# can case: can, cannot, could, will, would, shall, must, should, may, might
#	#	if ($phrase =~ /^\(vp \(md (can|cannot|could|will|would|shall|must|should)\)/i) {
#	if ($phrase =~ /^\(vp \(md (\w+)\)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		my $toReplace;
#		
#		if ($phrase =~ /\(vp \(vb have\) \(vp \(vbn been\)/i) {
#			# ex. may have been 
#			if ($phrase =~ /\(vbn been\) \(vp/i) {
#				# ex. may have been done 
#				if ($phrase =~ /\(md (\w+)\) \(rb not\)/i) {
#					$phrase =~ s/^\(vp \(md (\w+)\) \(rb not\) \(vp \(vb have\)/\(VP \(MD \) \(RB \) \(VP \(VB \)/i; 
#					$toReplace = $1;
#					
#					$phrase =~ s/\(vp \(vbn been\)/\(VP \(VBN \)/i;
#					$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN $toReplace not have been $2\) $3/i;
#				} else {
#					$phrase =~ s/^\(vp \(md (\w+)\) \(vp \(vb have\)/\(VP \(MD \) \(VP \(VB \)/i; 
#					$toReplace = $1;
#					
#					$phrase =~ s/\(vp \(vbn been\)/\(VP \(VBN \)/i;
#					$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN $toReplace have been $2\) $3/i;
#				}
#			} else {
#				# ex. can have done
#				if ($phrase =~ /\(md (\w+)\) \(rb not\)/i) {
#					$phrase =~ s/^\(vp \(md (\w+)\) \(rb not\) \(vp \(vb have\)/\(VP \(MD \) \(RB \) \(VP \(VB \)/i; 
#					$toReplace = $1;
#					
#					$phrase =~ s/\(vp \(vbn (\w+)\)/\(VP \(VBN $toReplace not have $1\)/i;
#				} else {
#					$phrase =~ s/^\(vp \(md (\w+)\) \(vp \(vb have\)/\(VP \(MD \) \(VP \(VB \)/i; 
#					$toReplace = $1;
#					
#					$phrase =~ s/\(vp \(vbn (\w+)\)/\(VP \(VBN $toReplace have $1\)/i;
#				}
#			}
#		}
#		
#		elsif ($phrase =~ /\(vb be\) \(vp/i) {
#			# ex. should be done 
#			if ($phrase =~ /\(md (\w+)\) \(rb not\)/i) {
#				$phrase =~ s/^\(vp \(md (\w+)\) \(rb not\)/\(VP \(MD \) \(RB \)/i; 
#				$toReplace = $1;
#				
#				$phrase =~ s/\(vp \(vb be\)/\(VP \(VB \)/i;
#				$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN $toReplace not be $2\) $3/i;
#			} else {
#				$phrase =~ s/^\(vp \(md (\w+)\)/\(VP \(MD \)/i; 
#				$toReplace = $1;
#				
#				$phrase =~ s/\(vp \(vb be\)/\(VP \(VB \)/i;
#				$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN $toReplace be $2\) $3/i;
#			}
#		} else {
#			if ($phrase =~ /\(md (\w+)\) \(rb not\)/i) {
#				# ex. can not do
#				$phrase =~ s/^\(vp \(md (\w+)\) \(rb not\)/\(VP \(MD \) \(RB \)/i;
#				$toReplace = $1;
#				$phrase =~ s/(\(vb (\w+)\))(.+)/\(VB $toReplace not $2\) $3/i;
#			} else {
#				$phrase =~ s/^\(vp \(md (\w+)\)/\(VP \(MD \)/i;
#				$toReplace = $1;
#				$phrase =~ s/(\(vb (\w+)\))(.+)/\(VB $toReplace $2\) $3/i;
#			}
#		}
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;     #'
#		$content = $2;
#	}
#	
#	#
#	# VBP (+ some VBZ case)-----------------------------------------------------------------------------------------------------------
#	#
#	
#	# VBP/VBZ case1: have/has/had/are/is/were/was + VBN case
#	if ($phrase =~ /^\(vp \(vb(p|z) (ha\w\w?|are|is|were|was)/i) {
#		my $toReplace;
#		
#		print STDERR "B: $phrase\n" if $debug;
#		
#		# Can have adjective
#		if ($phrase =~ /^\(vp \(vb(p|z) \w+\) \(adjp /i) {
#			return ($content, $IsToMove);
#		}	
#		
#		if ($phrase =~ /^\(vp \(vb(p|z) \w+\) \(rb not\) \(adjp /i) {
#			$phrase =~ s/^\(vp \(vb(p|z) (\w+)\) \(rb not\) \(adjp (.*)/\(VP \(VB$1 $2 not\) \(RB \) \(ADJP $3/i;
#			
#			# re-assign
#			$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;    #'
#			$content = $2;
#			
#			return ($content, $IsToMove);
#		}
#		
#		if ($phrase =~ /\(vbn /i) { 
#			# if there is no VBN, this means has/have/had is normal verb.
#			
#			if ($phrase =~ /^\(vp \(vb(p|z) (\w+)\) \(vp \(vbn been\)/i) {
#				# case: has/have/had been
#				
#				$phrase =~ s/^\(vp \(vb(p|z) (\w+)\) \(vp \(vbn been\) (.+)/\(VP \(VBZ \) \(VP \(VBN \) $3 \)/i;
#				my $vbz = $2;
#				$phrase =~ s/\(vp \(vbn (\w+)\) (.+)/\(VP \(VBN $vbz been $1\) $2 \)/i;
#				
#			} elsif ($phrase =~ /^\(vp \(vb(p|z) (\w+)\) ?\(rb not\)/i) {
#				# case: has/is not done
#				# $phrase =~ s/^\(vp \(vbp (ha\w\w?|are|is|were|was)\) \(rb not\) (.+\(vbn)\s([^\(]+)\)/\(VP \(VBN \) \(RB \) $2 $1 not $3\)/i;		
#				
#				$phrase =~ s/^\(vp \(vb(p|z) (\w+)\) ?\(rb not\)/\(VP \(VB$1 \) \(RB \)/i;
#				$toReplace = $2 || "";
#				print STDERR "Had trouble finding vp(p|z) content here: “$phrase”\n" unless $toReplace;
#				$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN $toReplace not $2\) $3/i;
#			} else {
#				# case: has/is done
#				#$phrase =~ s/^\(vp \(vbp (ha\w\w?|are|is|were|was)\) (.+\(vbn)\s([^\(]+)\)/\(VP \(VBN \) $2 $1 $3\)/i;
#				
#				$phrase =~ s/^\(vp \(vb(p|z) (\w+)\)/\(VP \(VB$1 \)/i;
#				$toReplace = $2;
#				
#				# if there is advp
#				my $advp = "";
#				if ($phrase =~ /\(advp \(rb /i) {
#					$phrase =~ s/\(advp \(rb (\w+)/\(ADVP \(RB /i;
#					$advp = $1 || "";
#				}
#				
#				$phrase =~ s/(\(vbn (\w+)\))(.+)/\(VBN $toReplace $advp $2\) $3/i;
#			}
#		} else {
#			# only not case
#			if ($phrase =~ /\(rb not\)/i) {
#				$phrase =~ s/^\(vp \(vb(p|z) (\w+)\) \(rb not\)/\(VP \(VB$1 $2 not\) \(RB \)/i;
#			}
#		}
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;      #'
#		$content = $2;
#	}
#	
#	# VBP case2: do/does/did + VB case
#	if ($phrase =~ /^\(vp \(vbp (do|does|did)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		if ($phrase =~ /\(rb not\)/i) {
#			$phrase =~ s/^\(vp \(vbp (do|does|did)\) \(rb not\) (.+\(vb)\s([^\(]+)\)/\(VP \(VBP \) \(RB \) $2 $1 not $3\)/i;
#		} else {
#			$phrase =~ s/^\(vp \(vbp (do|does|did)\) (.+\(vb)\s([^\(]+)\)/\(VP \(VB \) $2 $1 $3\)/i;
#		}
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;       #'
#		$content = $2;
#	}
#	
#	# VBP case3: are/is/were/was/do/does/did + not case (without VBN)
#	if ($phrase =~ /^\(vp \(vbp (\w+)\) \(rb not\)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		$phrase =~ s/^\(vp \(vbp (\w+)\) \(rb not\) (.+)/\(VP \(VBN $1 not\) \(RB \) $2/i;
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;     #'
#		$content = $2;
#	}
#	
#	#
#	# VBZ -------------------------------------------------------------------------------------------------------------------
#	#
#	
#	# VBZ case : isn|aren|haven|hasn|weren|wasn
#	#	if ($phrase =~ /^\(vp \(vbz (isn|aren|haven|hasn|hadn|weren|wasn|don|doesn)/i) {
#	if ($phrase =~ /^\(vp \(vbz (\w+)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		$phrase =~ s/^\(vp \(vbz (\w+)\) \(rb 't\) (.+)/\(VP \(VBZ $1 't\) \(RB \) $2 \)/i;
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;      #'
#		$content = $2;
#		$IsToMove = -1;
#	}
#	
#	#	# VBZ case2 : is|are|have|has|were|was + not
#	#	if ($phrase =~ /^\(vp \(vbz (is|are|have|has|had|were|was|do|does)\) \(rb not\)/i) {
#	if ($phrase =~ /^\(vp \(vbz (\w+)\) \(rb not\)/i) {
#		print STDERR "B: $phrase\n" if $debug;
#		
#		$phrase =~ s/^\(vp \(vbz (\w+)\) \(rb not\) (.+)/\(VP \(VBZ $1 not\) \(RB \) $2 \)/i;
#		
#		print STDERR "A: $phrase\n" if $debug;
#		
#		# re-assign
#		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;   #'
#		$content = $2;
#		$IsToMove = -1;
#	}
#	
#	# VBN case: ex. can do, have done, is done, etc.
#	if ($phrase =~ /^\(vbn\s\w+\s\w+/i) {
#		print STDERR "VBN case: " . $phrase . "\n" if $debug;
#		$IsToMove = -1;
#	}
#	
#	return ($content, $IsToMove);
#}
#
##
## 
##
#sub is_comman_exist () {
#	my @phrase = @_;
#	my $index = 0;
#	
#	foreach my $elm (@phrase) {
#		#		if ($elm =~ /^(\(, |\(cc )/i) {
#		#		if (($elm =~ /^(\(cc )/i) or ($elm =~ /^\(nn\w? \[\w+(\/\w+)+\]\)/i)) {
#		if ($elm =~ /^\(cc /i) {
#			print STDERR "$index - @phrase\n" if $debug; # DEBUG
#			
#			return $index;
#		}
#		$index++;
#	}
#	return -1;
#}

# CODE VERSION 2
sub pseudo_jpn {
	my ($phrase, $counter) = @_;
	
	# If it goes more than 1000 level, there is something wrong.
	# Typically there is a unknow tag.
	if ($level++ > 1000) {
		print STDERR "\n\n WARNING: unknown tag: $phrase" if defined $debug;
		exit;
	}
	
	#print "enter --> $phrase \n";
	
	# Extract content of this level by removing "([tag]" and ")"
	$phrase =~ m/^(\([\w\-\$\.:,'\#`]*)\s(.*)(\))$/;    #'
	
	my $top = $1;
	my $content = $2;
	my $tail = $3;
	my @result = (); # $[0]: $isToMove, $[1]: processed phrase
	my $pPrase = ""; # pseudo jpn phrase
	my $isToMove = 0;
	
	my @newPhrase;
	
	if ($top eq ($stanford ? "(ROOT" : "(TOP")) {
		# Top most level
		$newPhrase[0] = $content;
		#	} elsif ($top eq "(INC") {
		
	} else {
		
		#		print $phrase . "\n";
		
		#
		# Some cases are handled as exception
		# 
		my $isToSkip = 0;
		foreach my $elm (@langElementSkip) {
			if ($phrase =~ /^\Q$elm\E/i) {
				$isToSkip = 1;
				last;
			}
		}
		
		if (!$isToSkip) {
			
			# Check elements to move towards the end.
			foreach my $elm (@langElement2) {
				if ($phrase =~ /^\Q$elm\E/i) {
					$isToMove = -1;
					last;
					#					print "--> $phrase\n";
					#					exit;
				}
			}
			
			# Check elements to move towards the begining
			foreach my $elm (@langElement) {
				if ($phrase =~ /^\Q$elm\E/i) {
					$isToMove = 1;
					last;
					#					print "\t@ $phrase" . "\n";
					#					exit;
				}
			}
			
		}
		
		#
		# Exceptions (TODO: move this part into "handle_exceptions"
		#
		
		$isToMove = 1 if $phrase =~ /^\(in if\)/i;
#		if ($phrase =~ /^\(in if\)/i) {
#			$isToMove = 1;
#		}
		
		# Consider verb elements
		($content, $isToMove) = handle_exceptions($phrase, $content, $isToMove);
		
		# Find the next nested level
		@newPhrase = find_next_level($content);
		
		#
		# no more lower level : End condition of this recursive call
		#
		if (!@newPhrase) {
			# 
#			$content =~ s/^\s+//;
			
			print STDERR "no more lower level: $isToMove : $content \n" if defined $debug;
			return ($isToMove, $content);
		}
		
		#
		# if there is only one child, use the same result as child
		# unless $isToMove for this level is special (not 0).
		#
		# if this is (s (subject) don't move
		#
		if (@newPhrase == 1) {
			my @tmp = pseudo_jpn($newPhrase[0], $counter);
			
			$tmp[0] = $isToMove if $isToMove;
#			if ($isToMove != 0) {
#				$tmp[0] = $isToMove;
#			}
			
			return @tmp;
		}
		
	}
	
	#
	# Reconstruct the phrase by changing order
	#
	
	my $separatePos;
	
	# Check if there is any separator, such as "and", "or".
	$separatePos = is_comman_exist (@newPhrase);
	
	if ($separatePos > 0) {
		# print "== separate case ==\n"; # DEBUG
		my @part1 = @newPhrase[0 .. $separatePos-1];
		my @part2 = @newPhrase[$separatePos+1 .. (scalar @newPhrase)-1];
		my $connection = $newPhrase[$separatePos];
		
		$connection =~ /\s([\.,\?!&\w\[\]\/]+)\)$/i;
		$connection = $1;
		
		# print "@@@" . join (" ", @part2) . "\n";
		
		my @result1 = pseudo_jpn(($stanford ? "(root " : "(top ") . join(" ", @part1) . ")", $counter);
		my @result2 = pseudo_jpn(($stanford ? "(root " : "(top ") . join(" ", @part2) . ")", $counter);
		
		$pPrase = $result1[1] . " " . $connection . " " . $result2[1];
		#		print "temp result: $phrase\n";
		
	} else {
		# Normal case
		# print "== normal case ==\n"; # DEBUG	
		my @easyClause;
		my @hardClause;
		my @verb;
		my $period = "";
		my $previousMove = 0;
		
		foreach my $tmp (@newPhrase) {
			my @tmpResult = pseudo_jpn($tmp, $counter);
			
			if ($tmpResult[0] == 1) {
				push (@hardClause, $tmpResult[1]);
			} elsif ($tmpResult[0] == -1) {
				#print "\t<-- $tmpResult[1]" . "\n"; # DEBUG
				push (@verb, $tmpResult[1]);
			}else {
				if ($tmpResult[1] =~ /^(\.|\?|!)$/) {
					$period = " $1";
				} elsif ($tmpResult[1] =~ /^,$/) {
					# "," will follow the previous word???
					if ($previousMove == 0) {
						push (@easyClause, $tmpResult[1]);
					} elsif ($previousMove == 1) {
						push (@hardClause, $tmpResult[1]);
					} elsif ($previousMove == -1) {
						push (@verb, $tmpResult[1]);
					}
				} else {
					push (@easyClause, $tmpResult[1]);
				}
			}
			$previousMove = $tmpResult[0];
		}
		
		# Check: ideally there is only one element
		if (scalar @hardClause > 1) {
			print STDERR "$counter - WARNING: more than one grammatically difficult element\n" if defined $debug;
			@hardClause = reverse @hardClause;
			print STDERR join(" : ", @hardClause) . "\n" if defined $debug;
			
			if ($hardClause[0] eq ",") {
				$hardClause[0] = "";
				push (@hardClause, ",");
			}
		}
		if (scalar @verb > 1) {
			print STDERR "$counter - WARNING: more than one verb elements, reverse them\n" if defined $debug;
			@verb = reverse @verb;
			print STDERR join(" : ", @verb) . "\n" if defined $debug;
			
			if ($verb[0] eq ",") {
				$verb[0] = "";
				push (@verb, ",");
			}
		}
		
		$pPrase = join(" ",  @hardClause) . " " . join(" ", @easyClause) . " " . join(" ", @verb) . $period;
	}
	
	# clean spaces
#	$pPrase =~ s/^\s+//;
	
	print STDERR "\t <-- $isToMove : $pPrase\n" if defined $debug;
	return ($isToMove, $pPrase);
}



#
# handle_exceptions
#
# hand special case
# 
# 1. in order to : group all into "to"
# 2. (VP (VBD was/were)) : "(vp (vbd " can also be used also adjective, ex. file uploaded to the server. 
#                          "uploaded ..." is (vp (vbd. 2 cases are treated differently.
# 3. (vbx ) (cc and/or) (vbx ) : group all into the second "vbx"
# 4. (vbn/g : if it is used in (vp, move to the end, otherwise moved to the begining?
#
sub handle_exceptions () {
	my ($phrase, $content, $isToMove) = @_;
	
	# THERE ARE TOO FEW OF THESE TO MAKE IT WORTH THE HASSLE
	# (To to) case 2: "in order to"
#	if ($phrase =~ /^\Q(sbar (in in) (nn order) (s (vp \E(\(rb not\) )?\Q(to to)/i) {
#		print STDERR "B: $phrase\n" if defined $debug;
#		
#		if ($phrase =~ /\Q(rb not)/i) {
#			$phrase =~ s/^\Q(sbar (in in) (nn order) (s (vp (rb not) (to to) (vp (vb \E(\w+)\)/(SBAR (IN ) (NN ) (S (VP (RB ) (TO ) (VP (VB in order not to $1)/i;
#		} else {
#			$phrase =~ s/^\Q(sbar (in in) (nn order) (s (vp (to to) (vp (vb \E(\w+)\)/(SBAR (IN ) (NN ) (S (VP (TO ) (VP (VB in order to $1)/i;
#		}
#		
#		print STDERR "A: $phrase\n" if defined $debug;
#		
#		# re-assign
#		($content) = $phrase =~ m/^\([\w\-\$\.:,']*\s(.*)\)$/;   #'
##		$content = $1;
#	}
	
	# (VP (VBD was/were)) case, this should be normal verb
	$isToMove = -1 if $phrase =~ /^\(vp \(vbd (was|were)/i;
	
	
	# (vbx ) (cc and/or) (vbx )
	if ($phrase =~ /\((vb\w?) (\w+)\) \(cc (and|or)\) \((vb\w?) (\w+)/i) {
		print STDERR "CASE: (vbx ) (cc and/or) (vbx )\n" if defined $debug;
		print STDERR $phrase . "\n" if defined $debug;
		#		print $1 . "\n";
		#		print $2 . "\n";
		#		print $3 . "\n";
		#		print $4 . "\n";
		#		print $5 . "\n";
		
		#		$phrase =~ s/\((vb\w?) (\w+)\) \(cc (and|or)\) \((vb\w?) (\w+)\)/\($1 \) \(CC \) \($4 $2 $3 \5\)/i;
		$phrase =~ s/\((vb\w?) (\w+)\) \(cc (and|or)\) \((vb\w?) (\w+)\)/\($4 $2 $3 $5\)/i;
		#		print $phrase . "\n";
		
		# re-assign
		$phrase =~ m/^(\([\w\-\$\.:,']*)\s(.*)(\))$/;    #'
		$content = $2;
		
		print STDERR $content . "\n" if defined $debug;
	}
	
	# (vbn/g
	#	print "--> $phrase\n"; 
	if ($phrase =~ /\(vb[dng] /i) {
		print STDERR "VBN/G case in NP phrase\n" if defined $debug;
		print STDERR "Before:" . $content . "\n" if defined $debug;
		
		my @newPhrase = find_next_level($content);
		my $tmp = "";
		
		#
		# case 1 : (vbx is in (np or (s
		#     
		#     - in the second level (vp (vbx
		#     - in the first level (vbx
		#
		if ($phrase =~ /^\((np|s) /i) {
			
			if (scalar @newPhrase > 1) {
				
				my $vpElem = "";
				
				foreach my $elm (@newPhrase) {
					if ($elm =~ /^\(vp \(vb[dng]/i) {
						$vpElem = $vpElem . " " . $elm;
						print STDERR "@@@ case1-1" . $vpElem . "\n" if defined $debug;
					} elsif ($elm =~ /^\(vb[dng] /i) {
						$vpElem = $vpElem . " " . $elm;
						print STDERR "@@@ case1-2" . $vpElem . "\n" if defined $debug;
					} else {
						$tmp = $tmp . " " . $elm;
					}
				}
				$tmp = $vpElem . " " . $tmp;
				$tmp =~ s/\s+$//;
				
				$content = $tmp;
			}
			#
			# case 2 : (vbx is in (vp
			#
		} elsif ($phrase =~ /^\(vp /i) {
			
			if (scalar @newPhrase > 1) {
				
				my $vbnElem = "";
				
				print STDERR "\t case 2\n" if defined $debug;
				foreach my $elm (@newPhrase) {
					if ($elm =~ /^\(vb[ng] /i) {
						$vbnElem = $elm;
						print STDERR "@@@ case2" . $vbnElem . "\n" if defined $debug;
					} else {
						$tmp = $tmp . " " . $elm;
					}
				}
				$tmp = $tmp . " " . $vbnElem;
				$tmp =~ s/^\s+//;
				
				$content = $tmp;
			}
			
		}
		
		print STDERR "After:" . $content . "\n" if defined $debug;
	}
	
	
	return ($content, $isToMove);
}

#
# find_next_level
#
#   Used by pseudo_jpn to find the next level of nested phrase
#
sub find_next_level () {
	my ($phrase) = @_;
	
	#	print ">>> $phrase\n"; # DEBUG
	
	# clean the begining
	$phrase =~ s/^[\s\t]+//;
	
	my @buf = split(//, $phrase);
	my $openCounter = 0; # count "("
	
	my $tmpString = "";
	my @result = ();
	
	# Check if there is no "(" at the begining...
	# this means this is the leaf
	if (!(defined $buf[0]) || $buf[0] ne "(") {
		return @result;
	}
	
	#	print "\n--- BEGIN ---\n";
	
	foreach my $char (@buf) {
		#		print "$char ";
		if ($char eq "(") {
			$openCounter += 1;
			#			print "$openCounter";
		} elsif ($char eq ")") {
			$openCounter -= 1;
			#			print "$openCounter";
		}
		
		if ($openCounter == 0) {
			# counter=0 means there are equal number of ( and )
			$tmpString .= "$char";	
			
			# space between substrings gives empty string
			if ($tmpString eq " ") {
				# Just clean until some character appears...
				$tmpString = "";
			} else {
				#				print "\n" . $tmpString . "\n";
				push (@result, $tmpString);
				$tmpString = "";
			}
		} else {
			$tmpString .= "$char";	
		}
	}
	
	#	print "\n--- END ---\n";
	
	return @result;
}


#
# Find if "(cc and/or)" exits
#
# TODO: need to decide how to treat ","...
#
sub is_comman_exist () {
	my @phrase = @_;
	my $index = 0;
	
	foreach my $elm (@phrase) {
		#		if ($elm =~ /^(\(, |\(cc )/i) {
		#		if (($elm =~ /^(\(cc )/i) or ($elm =~ /^\(nn\w? \[\w+(\/\w+)+\]\)/i)) {
		#		if ($elm =~ /^(\(cc )/i) {
		#		if ($elm =~ /^(\(\. |\(cc )/i) {
		if (($elm =~ /^\(cc /i) or ($elm =~ / [\.\?!]\)$/i)){
			#			print "$index - @phrase\n"; # DEBUG
			
			if ($index < (scalar @phrase)-1) {
				# This check is necessary for "." at the end of phrase.
				return $index;
			}
		}
		$index++;
	}
	return -1;
}

#END# PSEUDO JAPANESE CODE #END#

1;