#!/bin/bash
#./bff-thread.sh start end [cookiefile]

COOKIEJAR=$3
if [ -z "$COOKIEJAR" ]; then
	COOKIEJAR=cookies-$$.txt
fi

for ((id=${1}; id<=${2}; id++)); do
  ./bff.sh $id $COOKIEJAR
  if [ -f STOP ]; then
    echo "Stopping at user request"
    exit 0
  fi
done
