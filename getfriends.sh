#!/bin/bash
#
# Version 1.
#
# Downloads the friends list of the given users from the Friendster api.
#  ./getfriends.sh FROM_ID TO_ID
#
# BEFORE USE: enter your Friendster account data in username.txt and password.txt
#

FROM_ID=$1
TO_ID=$2

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

API_KEY="0c868a9a9f2d332000cd09e1ed602ddc"
SECRET="7234cc4ad7689d0f8031b2023e252a3d"

mkdir -p tmp
tmp_file="tmp/result-$$.html"

echo "Logging in..."
curl -s --data "" "http://api.friendster.com/v1/token?api_key=${API_KEY}&nonce=${nonce}" > $tmp_file
auth_token=`grep -o -E "<auth_token>[^<]+" $tmp_file`
auth_token="${auth_token:12:100}"

curl -s -i --data "api_key=${API_KEY}&next=&src=login&auth_token=${auth_token}&email=${USERNAME}&password=${PASSWORD}" "http://www.friendster.com/widget_login.php" > $tmp_file
nonce=`grep -o -E "nonce=[^&]+" $tmp_file`
nonce="${nonce:6:100}"

sig=`echo -n "/v1/sessionapi_key=${API_KEY}auth_token=${auth_token}${SECRET}" | md5sum --text`
sig="${sig:0:32}"
curl -s --data "" "http://api.friendster.com/v1/session?api_key=${API_KEY}&auth_token=${auth_token}&sig=${sig}" > $tmp_file

session_key=`grep -o -E "<session_key>[^<]+" $tmp_file`
session_key="${session_key:13:100}"

# make nonce an integer
nonce="${nonce:0:10}"

i=$FROM_ID
while [ $i -le $TO_ID ]
do
  PROFILE_ID=$i
  uid=$i

  PROFILE_ID_WITH_PREFIX=$PROFILE_ID
  while [[ ${#PROFILE_ID_WITH_PREFIX} -lt 9 ]]
  do
    # id too short, prefix with 0
    PROFILE_ID_WITH_PREFIX=0$PROFILE_ID_WITH_PREFIX
  done
  PROFILE_DIR=data/${PROFILE_ID_WITH_PREFIX:0:3}/${PROFILE_ID_WITH_PREFIX:3:3}/${PROFILE_ID_WITH_PREFIX:6:3}
  mkdir -p $PROFILE_DIR
  
  id_list="$PROFILE_DIR/friends-$uid.xml"
  if [[ ! -f $id_list ]]
  then
    echo "$i"
    uid=$i
    nonce=$((nonce + 2))
    sig=`echo -n "/v1/friends/${uid}api_key=${API_KEY}nonce=${nonce}session_key=${session_key}${SECRET}" | md5sum --text`
    sig="${sig:0:32}"
    curl -s "http://api.friendster.com/v1/friends/${uid}?api_key=${API_KEY}&nonce=${nonce}&session_key=${session_key}&sig=${sig}" > $tmp_file
    mv $tmp_file $id_list
  fi

  i=$((i + 1))
done

