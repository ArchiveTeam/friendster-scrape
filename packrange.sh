#!/bin/bash

# packs up a range using tar, with a handy progress bar if pv is installed

DATADIR=$1
RANGE=$2

if [ $# -ne 2 ]; then
	echo usage: packrange.sh datadir range
	echo for example: packrange.sh data 1000-3000
	exit 1
fi

if [ ! -d $DATADIR ]; then
	echo data directory does not exist or is not a directory.
	exit 1
fi

PV=`which pv`

if [ -n "$PV" ]; then
	echo collecting total data size
	DIRCOUNT=`find $DATADIR -type d | wc -l`
	FILEBLOCKS=`find $DATADIR -type f -printf "%s\n" | awk '{SUM += 1 + int(($1/512)+0.999) } END {print SUM}'`
	TARSIZE=$((DIRCOUNT + FILEBLOCKS + 2))
	TARSIZE=$((TARSIZE * 512))

	echo tarring up data
	tar cf - --numeric-owner --totals $DATADIR | pv -s $TARSIZE | bzip2 -9c > friendster.${RANGE}.tar.bz2
else
	# tar everything up
	echo tarring up data
	tar cjf friendster.${RANGE}.tar.bz2 --totals $DATADIR
fi

