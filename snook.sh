#!/bin/bash
#./snook.sh start end processes
function instantiate
{
  for id in `seq $1 $2`; do ./bff.sh $id cookies-$$.sh;done >$1"-"$2.log 2>&1 &
}

START=$1
END=$2
NUMPROC=$3
idcount=$((END - START+1))
perproc=$((idcount / NUMPROC)) 
extra=$((idcount-perproc*NUMPROC))

echo "Running $idcount IDs in $NUMPROC processes, with $perproc per process. The last process has $extra extra due to division mismatch"

for thread in `seq 0 $((NUMPROC-2))`; do
  threadstart=$((START+(perproc * thread+1)))
  threadend=$((threadstart+perproc-1))
  echo "threadstart is $threadstart and threadend is $threadend"
  instantiate $threadstart $threadend
done

threadstart=$((START+(perproc*(NUMPROC-1)+1)))
threadend=$((threadstart+perproc+extra-1))
echo "threadstart is $threadstart and threadend is $threadend"
instantiate $threadstart $threadend
