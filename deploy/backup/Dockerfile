# F-02: the backup image has openssl built in. backup.sh used to run "apk add openssl" on first use,
# so a backup depended on the Alpine mirror being reachable each time the container was recreated.
FROM postgres:16.15-alpine
RUN apk add --no-cache openssl
