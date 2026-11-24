FROM alpine:latest

WORKDIR /home

RUN apk add --no-cache bash curl

COPY vix_check.sh /home/vix_check.sh
COPY cron_job.txt /etc/crontabs/root

RUN chmod +x /home/vix_check.sh && chmod 600 /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]
