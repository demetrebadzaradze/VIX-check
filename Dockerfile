FROM alpine:latest 

WORKDIR /home
COPY . .

RUN apk add --no-cache curl jq bash
RUN chmod +x /home/vix_check.sh

CMD ["/home/vix_check.sh"]
