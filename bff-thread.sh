#!/bin/bash
#./bff-thread.sh start end
seq $1 $2 | while read id; do
  ./bff.sh $id cookies-\$\$.txt;
  if [ -f STOP ]; then
    echo "Stopping at user request";
    exit 0;
  fi;
done
