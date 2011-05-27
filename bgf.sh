#!/bin/bash
#
# Version 1: ATTENTION: There is a strange problem with Friendster's forums.
#                       Sometimes requests return a zero-length page. Retrying
#                       does not help. If you restart the round, the pages will
#                       work (but others, which previously worked, fail).
#
# Download a Friendster group.
# ./bgf.sh GROUP_ID [COOKIES_FILE]
#
# Currently downloads:
#  - the main group page (http://www.friendster.com/group/tabmain.php?gid=$GROUP_ID)
#  - the members list (http://www.friendster.com/group/tabmember.php?gid=$GROUP_ID&page=0)
#  - the group's photos (http://www.friendster.com/group/tabphoto.php?fid=$GROUP_FID)
#  - the group's discussions (http://www.friendster.com/group-discussion/index.php?t=thread&frm_id=$GROUP_FRM_ID)
#  - the group's announcements (http://www.friendster.com/group/tabbulletin.php?fid=$GROUP_FID)
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
GROUP_DIR=data/${GROUP_ID_WITH_PREFIX:0:2}/${GROUP_ID_WITH_PREFIX:2:2}/${GROUP_ID_WITH_PREFIX:4:2}/$GROUP_ID


USER_AGENT="Googlebot/2.1 (+http://www.googlebot.com/bot.html)"
WGET="wget --no-clobber -nv -a $GROUP_DIR/wget.log --keep-session-cookies --save-cookies $COOKIES_FILE --load-cookies $COOKIES_FILE "


# incomplete result from a previous run?
if [ -f $GROUP_DIR/.incomplete ]
then
  echo "Deleting incomplete group $GROUP_ID..."
  rm -rf $GROUP_DIR
fi


# user should not exist
if [ -d $GROUP_DIR ]
then
  echo "Group directory $GROUP_DIR already exists. Not downloading."
  exit 2
fi


echo "Downloading $GROUP_ID:"

# make directories
mkdir -p $GROUP_DIR
mkdir -p $GROUP_DIR/photos
mkdir -p $GROUP_DIR/discussions
mkdir -p $GROUP_DIR/bulletins

# touch incomplete
touch $GROUP_DIR/.incomplete


# make sure the cookies file exists (may be empty)
touch $COOKIES_FILE


# download group page
echo " - group page"
# reuse the session cookies, if there are any
$WGET -U "$USER_AGENT" -O $GROUP_DIR/group.html "http://www.friendster.com/group/tabmain.php?gid=$GROUP_ID"


# check if we are logged in, if not: do so
if ! grep -q "http://www.friendster.com/logout.php" $GROUP_DIR/group.html
then
  echo "Logging in..."
  rm -f $COOKIES_FILE
  login_result_file=login_result_$$.html
  rm -f $login_result_file

  $WGET -U "$USER_AGENT" http://www.friendster.com/login.php -O $login_result_file --post-data="_submitted=1&next=/&tzoffset=-120&email=$USERNAME&password=$PASSWORD"

  if grep -q "Log Out" $login_result_file
  then
    echo "Login successful."

    # redownload the group page, now that we are logged in
    $WGET -U "$USER_AGENT" -O $GROUP_DIR/group.html "http://www.friendster.com/group/tabmain.php?gid=$GROUP_ID"
  else
    echo "Login failed."
  fi

  rm -f $login_result_file
fi


# is this group available?
if grep -q "The group that you were trying to view is no longer available." $GROUP_DIR/group.html
then
  echo "   Group $GROUP_ID not available."
  rm $GROUP_DIR/.incomplete
  exit 5
fi



# download group image
echo " - group profile photo"
group_photo_url=`grep -E "imgblock.+img src=\".+m\.jpg\"" $GROUP_DIR/group.html | grep -o -E "src=\"http.+\.jpg" | grep -o -E "http.+"`
if [[ "$group_photo_url" =~ "http://" ]]
then
  # url for original size
  photo_url_orig=${group_photo_url/s.jpg/.jpg}
  # extract photo id
  photo_id=`expr "$group_photo_url" : '.\+/photos/\(.\+\)s.jpg'`
  mkdir -p $GROUP_DIR/photos/`dirname $photo_id`

  $WGET -U "$USER_AGENT" -O $GROUP_DIR/photos/$photo_id.jpg "$photo_url_orig"

  cp $GROUP_DIR/photos/$photo_id.jpg $GROUP_DIR/group_photo.jpg
fi

# download member list
page=0
max_page=0
while [[ $page -le $max_page ]]
do
  echo " - members page $page"
  # download page
  $WGET -U "$USER_AGENT" --max-redirect=0 -O $GROUP_DIR/members_${page}.html "http://www.friendster.com/group/tabmember.php?gid=$GROUP_ID&page=${page}"

  # get page links
  page_numbers=`grep -o -E "/group/tabmember.php\?page=[0-9]+&" $GROUP_DIR/members_${page}.html | grep -o -E "[0-9]+"`
  # update max page number
  for new_page_num in $page_numbers
  do
    if [[ $max_page -lt $new_page_num ]]
    then
      max_page=$new_page_num
    fi
  done

  let "page = $page + 1"
done

# download group photos
echo " - group photos"
$WGET -U "$USER_AGENT" -O $GROUP_DIR/photo.html "http://www.friendster.com/group/tabphoto.php?gid=$GROUP_ID"
photo_urls=`grep -o -E "http://photos-p.friendster.com/photos/group/[^\"]+\.jpg" $GROUP_DIR/photo.html`
for photo_url in $photo_urls
do
  # url for original size
  photo_url_orig=${photo_url/[slm].jpg/.jpg}
  # extract photo id
  photo_id=`expr "$photo_url_orig" : '.\+/photos/\(.\+\).jpg'`
  mkdir -p $GROUP_DIR/photos/`dirname $photo_id`

  $WGET -U "$USER_AGENT" -O $GROUP_DIR/photos/$photo_id.jpg "$photo_url_orig"
done

# extract the forum url
forum_id=`grep -o -E "http://www.friendster.com/group-discussion/index.php\?t=thread&amp;frm_id=[0-9]+" $GROUP_DIR/group.html | grep -o -E "[0-9]+" | uniq`
if [[ "$forum_id" =~ [0-9]+ ]]
then
  # forum exists, download
  page=0
  max_page=0
  while [[ $page -le $max_page ]]
  do
    echo " - forum index page $page"
    tries=0
    while [ ! -f $GROUP_DIR/discussions/index_$page.html ] || [ ! -s $GROUP_DIR/discussions/index_$page.html ]
    do
      $WGET -U "$USER_AGENT" -O $GROUP_DIR/discussions/index_$page.html "http://www.friendster.com/group-discussion/index.php?t=thread&frm_id=$forum_id&start=$page&r=$tries"
      if [ ! -s $GROUP_DIR/discussions/index_$page.html ]
      then
        # zero-size file
        echo "Error: the downloaded page is empty." 
        sleep 10
      fi
      tries=$((tries + 1))
      if [[ $tries -ge 5 ]]
      then
        echo "Failed 5 times, skipping this page."
        break
      fi
    done

    # get page links
    page_numbers=`grep -o -E "t=thread&.+start=[0-9]+" $GROUP_DIR/discussions/index_${page}.html | grep -o -E "start=[0-9]+" | grep -o -E "[0-9]+"`
    # update max page number
    for new_page_num in $page_numbers
    do
      if [[ $max_page -lt $new_page_num ]]
      then
        max_page=$new_page_num
      fi
    done

    let "page = $page + 40"
  done

  # download threads
  thread_ids=`grep -o -h -E "t=msg&amp;th=[0-9]+" $GROUP_DIR/discussions/index_*.html | grep -o -E "[0-9]+"`
  for thread_id in $thread_ids
  do
    echo " - forum thread $thread_id"
    page=0
    max_page=0
    while [[ $page -le $max_page ]]
    do
      echo "   - thread page $page"
      tries=0
      while [ ! -f $GROUP_DIR/discussions/thread_${thread_id}_$page.html ] || [ ! -s $GROUP_DIR/discussions/thread_${thread_id}_$page.html ]
      do
        $WGET -U "$USER_AGENT" -O $GROUP_DIR/discussions/thread_${thread_id}_$page.html "http://www.friendster.com/group-discussion/index.php?t=msg&th=$thread_id&start=$page&r=$tries"
        if [ ! -s $GROUP_DIR/discussions/thread_${thread_id}_$page.html ]
        then
          # zero-size file
          echo "Error: the downloaded page is empty." 
          sleep 10
        fi
        tries=$((tries + 1))
        if [[ $tries -ge 5 ]]
        then
          echo "Failed 5 times, skipping this page."
          break
        fi
      done

      # get page links
      page_numbers=`grep -o -E "t=msg&.+start=[0-9]+" $GROUP_DIR/discussions/thread_${thread_id}_${page}.html | grep -o -E "start=[0-9]+" | grep -o -E "[0-9]+"`
      # update max page number
      for new_page_num in $page_numbers
      do
        if [[ $max_page -lt $new_page_num ]]
        then
          max_page=$new_page_num
        fi
      done

      let "page = $page + 40"
    done

  done
fi

# download bulletin list
page=0
max_page=0
while [[ $page -le $max_page ]]
do
  echo " - bulletins list, page $page"
  # download page
  $WGET -U "$USER_AGENT" --max-redirect=0 -O $GROUP_DIR/bulletin_list_${page}.html "http://www.friendster.com/group/tabbulletin.php?gid=$GROUP_ID&page=${page}"

  # get page links
  page_numbers=`grep -o -E "/group/tabbulletin.php\?page=[0-9]+&" $GROUP_DIR/bulletin_list_${page}.html | grep -o -E "[0-9]+"`
  # update max page number
  for new_page_num in $page_numbers
  do
    if [[ $max_page -lt $new_page_num ]]
    then
      max_page=$new_page_num
    fi
  done

  let "page = $page + 1"
done

# download each bulletin
echo " - bulletins"
bulletin_ids=`grep -h -o -E ";bid=[0-9]+" $GROUP_DIR/bulletin_list_*.html | grep -o -E "[0-9]+"`
for bid in $bulletin_ids
do
  echo "   - bulletin $bid"
  $WGET -U "$USER_AGENT" --max-redirect=0 -O $GROUP_DIR/bulletins/bulletin_$bid.html "http://www.friendster.com/group/tabbulletin.php?gid=$GROUP_ID&bid=$bid"
done


# done
rm $GROUP_DIR/.incomplete


END=$(date +%s)
DIFF=$(( $END - $START ))

echo " Group $GROUP_ID done. ($DIFF seconds)"
