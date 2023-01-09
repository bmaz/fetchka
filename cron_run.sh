#!/bin/bash
set -e

export PATH="$HOME/.cargo/bin:$PATH"

# Corpus directory assumed to be the same as the script's
CORPUSDIR=$(dirname "$0")
cd $CORPUSDIR

LAST_FILE=$(ls -t last_tweets_*.csv | head -1)
NOW=$(date +"%Y-%m-%dT%H")
NEW_FILE="last_tweets_${NOW}.csv"
LOG_FILE="logs.log"

echo "$(date) : load tweets from users" >> $LOG_FILE
# Collect tweets from the last 31 days from our users
docker build -t minet .
docker run --name minet-users -v /rex/local/bmtweet/factcheck/:/usr/src/app minet twitter user-tweets --rcfile /usr/src/app/.minetrc --ids user_numeric_id /usr/src/app/twitter_unique_handles_2022_02_28.csv -o /usr/src/app/${NEW_FILE} --min-date $(date --date='-31days' +'%Y-%m-%d')
docker rm minet-users

echo "$(date) : create union of past ids and new ids" >> $LOG_FILE
# Compute list of unique tweet ids in both files
xsv cat rows $LAST_FILE $NEW_FILE | xsv select id,user_id | xsv sort -u > tmp_id_list.csv

echo "$(date) : find removed tweets" >> $LOG_FILE
# Find complete data in the new file - tweets from last file not in the new file will remain empty rows
# Add a fictive collection time to empty rows, to help estimate deletion time
COLUMNS="id[0],user_id[0],collection_time,timestamp_utc,local_time,user_screen_name,text,possibly_sensitive,retweet_count,like_count,reply_count,lang,to_username,to_userid,to_tweetid,source_name,source_url,user_location,lat,lng,user_name,user_verified,user_description,user_url,user_image,user_tweets,user_followers,user_friends,user_likes,user_lists,user_created_at,user_timestamp_utc,collected_via,match_query,retweeted_id,retweeted_user,retweeted_user_id,retweeted_timestamp_utc,quoted_id,quoted_user,quoted_user_id,quoted_timestamp_utc,url,place_country_code,place_name,place_type,place_coordinates,links,domains,media_urls,media_files,media_types,mentioned_names,mentioned_ids,hashtags"
NOW=$(date +"%Y-%m-%dT%H:%M:%S.%N" -u)
xsv join --left id,user_id tmp_id_list.csv id,user_id $NEW_FILE | xsv select $COLUMNS | xsv replace -s collection_time ^$ ${NOW:0:26} > tmp_attrition.csv

echo "$(date) : run minet attrition" >> $LOG_FILE
# Run minet attrition
docker run --name minet-attrition -v /rex/local/bmtweet/factcheck/:/usr/src/app minet twitter attrition --rcfile /usr/src/app/.minetrc --ids --user user_id id /usr/src/app/tmp_attrition.csv -o /usr/src/app/tmp_tmp_attrition.csv
docker rm minet-attrition

# Add result to final file
xsv select "tweet_current_status,${COLUMNS}" tmp_tmp_attrition.csv | xsv replace -s text,user_location,user_description,user_name,url,links,place_name "," "" | xsv replace -s place_coordinates "," ";" | xsv behead >> past_tweets_users.csv

#echo "$(date) : compress last file" >> $LOG_FILE
## Compress last file
#gzip $LAST_FILE

echo "$(date) : remove temporary files" >> $LOG_FILE
# Remove temporary files
rm tmp*.csv

echo "$(date) : done" >> $LOG_FILE
echo "***************************************************" >> $LOG_FILE
