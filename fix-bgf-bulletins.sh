#!/bin/bash
#
# Fix the bulletins of a group profile downloaded with bgf.sh version 3 or earlier.
# ./fix-bgf-bulletins.sh GROUP_ID [COOKIES_FILE]
#
# Versions of bgf.sh before version 4 did not download the bulletins correctly.
# Run this script to download these bulletins again.
#
#
# BEFORE USE: enter your Friendster account data in username.txt and password.txt
#
#

GROUP_ID=$1
COOKIES_FILE=$2
if [[ ! $COOKIES_FILE =~ .txt ]]
then
  COOKIES_FILE=cookies.txt
fi

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

# check the id
if [[ ! $GROUP_ID =~ ^[0-9]+$ ]]
then
  echo "No group id given."
  exit 1
fi


START=$(date +%s)

# build directory name
GROUP_ID_WITH_PREFIX=$GROUP_ID
while [[ ${#GROUP_ID_WITH_PREFIX} -lt 6 ]]
do
  # id too short, prefix with 0
  GROUP_ID_WITH_PREFIX=0$GROUP_ID_WITH_PREFIX
done
GROUP_DIR=data/groups/${GROUP_ID_WITH_PREFIX:0:2}/${GROUP_ID_WITH_PREFIX:2:2}/${GROUP_ID_WITH_PREFIX:4:2}/g$GROUP_ID


USER_AGENT="Googlebot/2.1 (+http://www.googlebot.com/bot.html)"
WGET="wget --no-clobber -nv -a $GROUP_DIR/wget.log --keep-session-cookies --save-cookies $COOKIES_FILE --load-cookies $COOKIES_FILE "



# group should exist
if [ ! -d $GROUP_DIR ]
then
  echo "Group directory $GROUP_DIR does not exist. Not fixing."
  exit 2
fi

# incomplete result from a previous run?
if [ -f $GROUP_DIR/.incomplete ]
then
  echo "Incomplete group $GROUP_ID. Run normal bgf.sh."
  exit 2
fi



echo "Updating bulletins for $GROUP_ID:"

# touch incomplete
touch $GROUP_DIR/.incomplete


# make sure the cookies file exists (may be empty)
touch $COOKIES_FILE


# redownload group page to check login
login_result_file=login_result_$$.html
rm -f $login_result_file
# reuse the session cookies, if there are any
$WGET -U "$USER_AGENT" -O $login_result_file "http://www.friendster.com/group/tabmain.php?gid=$GROUP_ID"


# check if we are logged in, if not: do so
if ! grep -q "http://www.friendster.com/logout.php" $login_result_file
then
  echo "Logging in..."
  rm -f $COOKIES_FILE
  rm -f $login_result_file

  $WGET -U "$USER_AGENT" http://www.friendster.com/login.php -O $login_result_file --post-data="_submitted=1&next=/&tzoffset=-120&email=$USERNAME&password=$PASSWORD"

  if grep -q "Log Out" $login_result_file
  then
    echo "Login successful."
  else
    echo "Login failed."
  fi
fi

rm -f $login_result_file


# is this group available?
if grep -q "The group that you were trying to view is no longer available." $GROUP_DIR/group.html
then
  echo "   Group $GROUP_ID not available."
  rm $GROUP_DIR/.incomplete
  exit 5
fi


# redownload each bulletin
bulletin_ids=( `grep -h -o -E ";bid=[0-9]+" $GROUP_DIR/bulletin_list_*.html | grep -o -E "[0-9]+"` )
echo " - bulletins (${#bulletin_ids[@]})"
for bid in "${bulletin_ids[@]}"
do
  echo "   - bulletin $bid"
  rm -f $GROUP_DIR/bulletins/bulletin_$bid.html
  $WGET -U "$USER_AGENT" --max-redirect=0 -O $GROUP_DIR/bulletins/bulletin_$bid.html "http://www.friendster.com/group/bulletin.php?gid=$GROUP_ID&bid=$bid"
done


# done
rm $GROUP_DIR/.incomplete


END=$(date +%s)
DIFF=$(( $END - $START ))

echo " Group $GROUP_ID fixed. ($DIFF seconds)"

