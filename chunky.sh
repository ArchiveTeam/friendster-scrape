#!/bin/bash

# usage: ./chunky.sh START END THREADS
# will download range START to END in chunks of 1000, keeping THREADS downloaders going
# press ^C to exit or to change the number of threads.
# while running, statistics are occasionally output

if [ $# -ne 3 ]; then
	echo USAGE: $0 START END THREADS
	echo The number of threads can be changed while running by pressing ^C
	exit 1
fi

START=$1
END=$2
WANT=$3

RUNNING=0
CUR=$START

RANGE=$((END-START+1))

calcpct()
{
	v=$((CUR-START))
	pct=$((100 * v / RANGE))
	return $pct
}

# map from PID to cookie jar
declare -A CHILDREN

# map from cookie jar to PID
declare -A COOKIEJARS

KEEPGOING=1
GETINPUT=0

startchild()
{
	# find an available cookie jar
	jarnum=$WANT
	for ((jar=0; jar<$WANT; jar++)); do
		if [ -z "${COOKIEJARS[$jar]}" ]; then
			jarnum=$jar
		fi
	done

	# calculate range for this child
	s=$CUR
	CUR=$((CUR+1000))
	e=$((CUR-1))

	# start the child and get the PID
	./bff-thread.sh $s $e cookies${jarnum}.txt > friendster.${s}-${e}.log 2>&1 &
	cn=$!
	
	# record the new child
	CHILDREN[$cn]=$jarnum
	COOKIEJARS[$jarnum]=$cn
	RUNNING=${#CHILDREN[@]}

	# if we hit the end of the range, we don't want to start more children, ever
	if [ $CUR -ge $END ]; then
		WANT=0
	fi
}

checkchildren()
{
	for c in ${COOKIEJARS[@]}; do
		kill -0 $c 2>/dev/null
		if [ $? -eq 1 ]; then
			jar=${CHILDREN[$c]}
			unset CHILDREN[$c]
			unset COOKIEJARS[$jar]
		fi
	done
	RUNNING=${#CHILDREN[*]}
}

inttrap()
{
	GETINPUT=1
}

trap inttrap INT

getinput()
{
	echo "Do you wish to stop? [y/N]"
	read e
	if [ "$e" == "y" ]; then
		# stop the loop
		KEEPGOING=0
		# tell our children to stop
		touch STOP
	else
		if [ $WANT -eq 0 ]; then
			echo no more blocks to assign. unable to change thread count.
		else
			echo "How many threads do you want to run? [$WANT]"
			read w
			if [ -n "$w" ]; then
				# verify a valid number
				w=`echo $w|grep -E '^[1-9][0-9]*$'`
				if [ -z "$w" ]; then
					echo invalid thread count. staying with $WANT
				else
					WANT=$w
				fi
			fi
		fi
	fi
}

# before we start, remove the STOP file, or bff-thread.sh will stop after 1 profile
[ -f STOP ] && rm STOP

while [ $KEEPGOING -eq 1 ]; do

	# check to see if ^C was pressed
	if [ $GETINPUT -eq 1 ]; then
		# present the prompts
		getinput
		GETINPUT=0
		# if the user selected to stop, then skip the rest of the loop
		if [ $KEEPGOING -eq 0 ]; then continue; fi
	fi

	# check to see if any children have finished
	checkchildren

	# start new threads to fill voids left by ones that finished
	while [ $RUNNING -lt $WANT ]; do
		startchild
	done

	# present statistics
	calcpct
	echo "next block starts at $CUR. ${?}% of range assigned or completed."
	echo "$RUNNING (of ${WANT}) threads running."
	echo "press ^C to exit or change number of threads"

	# check to see if we should keep going this is before the sleep so that
	# the sleep is almost certainly what gets interrupted with ^c, as everything
	# else is fast
	if [ $CUR -ge $END ] && [ $RUNNING -eq 0 ]; then
		KEEPGOING=0
	fi

	# sleep for a bit
	[ $KEEPGOING -eq 1 ] && sleep 30
done

if [ ${#COOKIEJARS[@]} -gt 0 ]; then
	echo out of loop, waiting for ${#COOKIEJARS[@]} children to finish
	wait ${COOKIEJARS[@]}
fi
echo done.

