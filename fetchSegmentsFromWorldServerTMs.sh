#!/bin/bash

# Wrapper for fetchSegmentsFromAthena.pl
# Makes sure the Perl script is executable by including pointers to Oracle's ins
tantclient libraries

# Usage: fetchSegmentsFromAthena.sh [any arguments you'd pass to the respective .pl file]

sudo DYLD_LIBRARY_PATH=/Library/Oracle/instantclient_11_2:$DYLD_LIBRARY_PATH perl fetchSegmentsFromAthena.pl $@
