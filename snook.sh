#!/bin/bash
#./snook.sh start end processes
function instantiate
{
  echo "started a thread that goes from $1 to $2"
  bash -c "seq $1 $2 | xargs -n 1 -i ./bff.sh '{}' cookies-\$\$.txt" >>$1"-"$2.log 2>&1 &
}

USERNAME=`cat username.txt`
PASSWORD=`cat password.txt`
# trim whitespace
USERNAME=${USERNAME/ /}
PASSWORD=${PASSWORD/ /}

if [[ ! $USERNAME =~ @ ]]
then
  echo "Enter your username (your Friendster email) in username.txt and your password in password.txt."
  exit 3
fi

START=$1
END=$2
NUMPROC=$3
idcount=$((END - START+1))
perproc=$((idcount / NUMPROC)) 
extra=$((idcount-perproc*NUMPROC))

echo "Running $idcount IDs in $NUMPROC processes, with $perproc per process. The last process has $extra extra due to division mismatch"

for thread in `seq 0 $((NUMPROC-2))`; do
  threadstart=$((START+(perproc * thread)-1))
  threadend=$((threadstart+perproc))
  instantiate $threadstart $threadend
done

threadstart=$((START+(perproc*(NUMPROC-1)-1)))
threadend=$END
instantiate $threadstart $threadend
