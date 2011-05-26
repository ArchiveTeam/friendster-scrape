#!/bin/bash
# fix-structure.sh: fixes the data directory so that downloading
# chuncks of 100k userids will work correctly on most filesystems when
# the userids are above 10 million

if [ -f $1 ]; then
  DIR=data
else
  DIR=$1
fi
DIR=`echo $DIR | sed -e 's/\///'`
BACKUP=$DIR.backup.$$

mv $DIR $BACKUP
mkdir $DIR
find $BACKUP -mindepth 4 -maxdepth 4 | while read line; do
    PROFILE_ID=`basename $line`
    # build directory name
    WITH_PREFIX=$PROFILE_ID
    while [[ ${#WITH_PREFIX} -lt 9 ]]; do
        # id too short, prefix with 0
        WITH_PREFIX=0$WITH_PREFIX
    done
    PROFILE_DIR=$DIR/${WITH_PREFIX:0:3}/${WITH_PREFIX:3:3}/${WITH_PREFIX:6:3}
    mkdir -p $PROFILE_DIR
    OLD_PROFILE_DIR=`echo $PROFILE_DIR | sed -e "s/$DIR/$BACKUP/"`
    echo mv $OLD_PROFILE_DIR/$PROFILE_ID $PROFILE_DIR
done
rm -rf $BACKUP
