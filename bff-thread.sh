#!/bin/bash
#./bff-thread.sh start end
for ((id=${1}; id<=${2}; id++)); do
  ./bff.sh $id cookies-$$.txt;
  if [ -f STOP ]; then
    echo "Stopping at user request";
    exit 0;
  fi;
done
