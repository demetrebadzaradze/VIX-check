FROM alpine:latest 

WORKDIR /home
COPY . .

RUN apk add --no-cache curl jq bash 
RUN chmod +x /home/vix_check.sh

RUN cat ./cron_job.txt >> /etc/crontabs/root
run cat /etc/crontabs/root

RUN rm -f ./cron_job.txt
			
CMD crond -f 
