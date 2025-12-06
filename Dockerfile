FROM alpine:latest 

WORKDIR /home
COPY . .

RUN apk add --no-cache curl jq bash 
RUN chmod +x /home/vix_check.sh

RUN echo "0 5 * * * /home/vix_check.sh > /proc/1/fd/1 2>&1" >> /etc/crontabs/root
					
CMD crond -f 
