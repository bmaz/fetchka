FROM python

RUN pip install minet

RUN addgroup --gid 1548 bmazoyer && \
    adduser --system --home /home/bmazoyer --uid 1548 --gid 1548 bmazoyer
USER bmazoyer

ENTRYPOINT ["minet"]
#CMD python -m minet.cli twitter user-tweets --rcfile /usr/src/app/.minetrc --ids --min-date {date} user_numeric_id /usr/src/app/twitter_handles_2022_02_28.csv > /usr/src/app/last_tweets_since_{date}.csv