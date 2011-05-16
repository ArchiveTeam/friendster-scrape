#!/bin/bash

# usage: ./chunky.sh START END THREADS
# will download range START to END in chunks, keeping THREADS downloaders going
# press e to exit or t to change the number of threads.
# while running, statistics are occasionally output

if [ $# -ne 3 ]; then
	echo USAGE: $0 START END THREADS
	echo The number of threads can be changed while running by pressing t
	exit 1
fi

START=$1
END=$2
WANT=$3
STEP=100

RUNNING=0
CUR=$START

RANGE=$((END-START+1))

# map from PID to cookie jar
declare -A CHILDREN

# map from cookie jar to PID
declare -A COOKIEJARS

# what is the start of the range for each PID
declare -A thread_range
# and current profile
declare -A thread_current

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
	CUR=$((CUR+STEP))
	if [ $CUR -gt $END ]; then
		CUR=$((END+1))
	fi
	e=$((CUR-1))
	rng=$((e-s+1))

	# start the child and get the PID
	./bff-thread.sh $s $e cookies${jarnum}.txt >> friendster.${s}-${e}.log 2>&1 &
	cn=$!
	
	# record the new child
	CHILDREN[$cn]=$jarnum
	COOKIEJARS[$jarnum]=$cn
	thread_range[$cn]=${s}:${rng}
	thread_current[$cn]=$s
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
			# thread is gone. clear information related to it
			jar=${CHILDREN[$c]}
			unset CHILDREN[$c]
			unset COOKIEJARS[$jar]
			unset thread_range[$c]
			unset thread_current[$c]
		else
			# thread is alive. get the current status of the thread
			cur=`cat bffthread-${c} 2>/dev/null`
			if [ "$cur" ]; then
				thread_current[$c]=$cur
			fi
		fi
	done
	RUNNING=${#CHILDREN[*]}
}

askexit()
{
	echo
	echo "Do you wish to stop? [y/N]"
	read e
	if [ "$e" == "y" ]; then
		# stop the loop
		KEEPGOING=0
		# tell our children to stop
		touch STOP
	fi
}

askthreads()
{
	echo
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
}

# before we start, remove the STOP file, or bff-thread.sh will stop after 1 profile
[ -f STOP ] && rm STOP

while [ $KEEPGOING -eq 1 ]; do
	# check to see if any children have finished
	checkchildren

	# start new threads to fill voids left by ones that finished
	while [ $RUNNING -lt $WANT ]; do
		startchild
	done

	# present statistics
	v=$((CUR-START))
	pct=$((100 * v / RANGE))
	echo
	[ $CUR -le $END ] && echo "next block starts at $CUR."
	echo "${pct}% of range ${START}-${END} assigned or completed."
	echo "running threads (${RUNNING}/${WANT}):"
	for c in ${COOKIEJARS[@]}; do
		s=${thread_range[$c]}
		rng=${s#*:}
		s=${s%:*}
		e=$((s+rng-1))
		cur=${thread_current[$c]}
		v=$((cur-s))
		pct=$((100 * v / rng))
		echo " thread covering ${s}-${e}: ${cur} (${pct}%)"
	done
	echo "press e to exit or t to change number of threads"
	echo "any other key will update stats, or wait 30 seconds"

	# check to see if we should keep going this is before the sleep so that
	# the sleep is almost certainly what gets interrupted with ^c, as everything
	# else is fast
	if [ $CUR -ge $END ] && [ $RUNNING -eq 0 ]; then
		KEEPGOING=0
	fi

	# sleep for a bit
	read -t 30 -n 1 dummy
	# exit code greater than 128 means timeout
	if [ $? -le 128 ]; then
		case "$dummy" in
		e|E) askexit;;
		t|T) askthreads;;
		esac
	fi
done

# wait for any running threads to finish (will only happen if we stopped early)
while [ $RUNNING -gt 0 ]; do
	echo waiting for $RUNNING threads to finish their current profile
	sleep 10
	checkchildren
done

echo done.

