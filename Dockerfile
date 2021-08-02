ARG BASETAG=latest
FROM mongo:$BASETAG

ARG GOCRONVER=v0.0.10
ARG TARGETOS
ARG TARGETARCH
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/* \
	&& curl -L https://github.com/prodrigestivill/go-cron/releases/download/$GOCRONVER/go-cron-$TARGETOS-$TARGETARCH.gz | zcat > /usr/local/bin/go-cron \
	&& chmod a+x /usr/local/bin/go-cron \
	&& apt-get purge -y --auto-remove ca-certificates && apt-get clean

ENV MONGO_DB=**None** \
    MONGO_DB_FILE=**None** \
    MONGO_HOST=**None** \
    MONGO_PORT=27017 \
    MONGO_USER=**None** \
    MONGO_USER_FILE=**None** \
    MONGO_PASSWORD=**None** \
    MONGO_PASSWORD_FILE=**None** \
    MONGO_PASSFILE_STORE=**None** \
    MONGO_EXTRA_OPTS="" \
    SCHEDULE="@daily" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".archive" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    HEALTHCHECK_PORT=8080

COPY backup.sh /backup.sh

VOLUME /backups

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec /usr/local/bin/go-cron -s \"$SCHEDULE\" -p \"$HEALTHCHECK_PORT\" -- /backup.sh"]

HEALTHCHECK --timeout=3s \
  CMD curl -f "http://localhost:$HEALTHCHECK_PORT/" || exit 1
