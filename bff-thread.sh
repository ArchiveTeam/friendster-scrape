#!/bin/bash
#./bff-thread.sh start end
for ((x=${1}; x<=${2}; x++)); do echo $x; done | while read id; do
  ./bff.sh $id cookies-\$\$.txt;
  if [ -f STOP ]; then
    echo "Stopping at user request";
    exit 0;
  fi;
done
