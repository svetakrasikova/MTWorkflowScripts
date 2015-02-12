#!/bin/bash

# Wrapper for fetchSegmentsFromAthena.pl
# Makes sure the Perl script is executable by including pointers to Oracle's instantclient libraries

# Usage: fetchSegmentsFromWorldServerTMs.sh [any arguments you'd pass to the respective .pl file]

DYLD_LIBRARY_PATH=/Library/Oracle/instantclient_11_2:$DYLD_LIBRARY_PATH perl /OptiBay/ADSK_Software/fetchSegmentsFromWorldServerTMs.pl $@
