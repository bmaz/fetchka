# Corpus directory assumed to be the same as the script's
CORPUSDIR=$(dirname "$0")
cd $CORPUSDIR

LAST_FILE=$(ls -t last_tweets_*.csv | head -1)
NOW=$(date +"%Y-%m-%dT%H")
NEW_FILE="last_tweets_${NOW}.csv"
LOG_FILE="logs.log"

echo "$(date) : load tweets from users" >> $LOG_FILE
# Collect tweets from the last 31 days from our users
minet twitter user-tweets --rcfile /home/bmazoyer/Dev/minet/.minetrc.json --ids user_numeric_id twitter_unique_handles_2022_02_28.csv -o $NEW_FILE --min-date $(date --date='-31days' +'%Y-%m-%d')

# Compute list of unique tweet ids in both files
xsv cat rows $LAST_FILE $NEW_FILE | xsv select id,user_id | xsv sort -u > tmp_id_list.csv

echo "$(date) : find removed tweets" >> $LOG_FILE
# Find complete data in the new file - tweets from last file not in the new file will remain empty rows
# Add a fictive collection time to empty rows, to help estimate deletion time
COLUMNS="id[0],user_id[0],collection_time,timestamp_utc,local_time,user_screen_name,text,possibly_sensitive,retweet_count,like_count,reply_count,lang,to_username,to_userid,to_tweetid,source_name,source_url,user_location,lat,lng,user_name,user_verified,user_description,user_url,user_image,user_tweets,user_followers,user_friends,user_likes,user_lists,user_created_at,user_timestamp_utc,collected_via,match_query,retweeted_id,retweeted_user,retweeted_user_id,retweeted_timestamp_utc,quoted_id,quoted_user,quoted_user_id,quoted_timestamp_utc,url,place_country_code,place_name,place_type,place_coordinates,links,domains,media_urls,media_files,media_types,mentioned_names,mentioned_ids,hashtags"
NOW=$(date +"%Y-%m-%dT%H:%M:%S.%N")
xsv join --left id,user_id tmp_id_list.csv id,user_id $NEW_FILE | xsv select $COLUMNS | xsv replace -s collection_time ^$ ${NOW:0:26} > tmp_attrition.csv

echo "$(date) : run minet attrition" >> $LOG_FILE
# Run minet attrition
minet twitter attrition --rcfile /home/bmazoyer/Dev/minet/.minetrc.json --ids --user user_id id tmp_attrition.csv -o tmp_tmp_attrition.csv

# Add result to final file
COLUMNS="tweet_current_status,id,user_id,collection_time,timestamp_utc,local_time,user_screen_name,text,possibly_sensitive,retweet_count,like_count,reply_count,lang,to_username,to_userid,to_tweetid,source_name,source_url,user_location,lat,lng,user_name,user_verified,user_description,user_url,user_image,user_tweets,user_followers,user_friends,user_likes,user_lists,user_created_at,user_timestamp_utc,collected_via,match_query,retweeted_id,retweeted_user,retweeted_user_id,retweeted_timestamp_utc,quoted_id,quoted_user,quoted_user_id,quoted_timestamp_utc,url,place_country_code,place_name,place_type,place_coordinates,links,domains,media_urls,media_files,media_types,mentioned_names,mentioned_ids,hashtags"
xsv select $COLUMNS tmp_tmp_attrition.csv | xsv behead >> past_tweets_users.csv

#echo "$(date) : compress last file" >> $LOG_FILE
## Compress last file
#gzip $LAST_FILE

echo "$(date) : remove temporary files" >> $LOG_FILE
# Remove temporary files
rm tmp*.csv

echo "$(date) : done" >> $LOG_FILE
echo "***************************************************" >> $LOG_FILE