#!/bin/bash
#./bff-thread.sh start end [cookiefile]

COOKIEJAR=$3
if [ -z "$COOKIEJAR" ]; then
	COOKIEJAR=cookies-$$.txt
fi

THREADSTATUS=bffthread-$$

for ((id=${1}; id<=${2}; id++)); do
  echo $id > $THREADSTATUS
  ./bff.sh $id $COOKIEJAR
  if [ -f STOP ]; then
    echo "Stopping at user request"
    rm $THREADSTATUS
    exit 0
  fi
done
rm $THREADSTATUS

