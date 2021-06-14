![Docker Pulls](https://img.shields.io/docker/pulls/acouvreur/mongo-backup-local)

# mongodb-backup-local

Backup MongoDB to the local filesystem with periodic rotating backups, based on [docker-postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local).
Backup multiple databases from the same host by setting the database names in `MONGO_DB` separated by commas or spaces.

Supports the following Docker architectures: `linux/amd64`, `linux/arm64`, `linux/arm/v7`, `linux/s390x`, `linux/ppc64le`.

## Usage

Docker:

```sh
docker run -e MONGO_HOST=MONGO -e MONGO_DB=dbname -e MONGO_USER=user -e MONGO_PASSWORD=password acouvreur/mongo-backup-local:latest
```

Docker Compose:

```yaml
version: '2'
services:
    mongodb:
        image: mongo
        restart: always
        environment:
            - MONGO_INITDB_DATABASE=database
            - MONGO_INITDB_ROOT_USERNAME=mongo
            - MONGO_INITDB_ROOT_PASSWORD=mongo
         #  - MONGO_INITDB_ROOT_PASSWORD_FILE=/run/secrets/db_password <-- alternative for MONGO_INITDB_ROOT_PASSWORD (to use with docker secrets)

    mongo-backup:
        image: acouvreur/mongo-backup-local:latest
        restart: always
        volumes:
            - /var/opt/mongobackups:/backups
        links:
            - mongodb
        depends_on:
            - mongodb
        environment:
            - MONGO_HOST=mongodb
            - MONGO_DB=database
            - MONGO_USER=mongo
            - MONGO_PASSWORD=mongo
         #  - MONGO_PASSWORD_FILE=/run/secrets/db_password <-- alternative for MONGO_PASSWORD (to use with docker secrets)
            - SCHEDULE=@daily
            - BACKUP_KEEP_DAYS=7
            - BACKUP_KEEP_WEEKS=4
            - BACKUP_KEEP_MONTHS=6
            - HEALTHCHECK_PORT=8080
```

### Environment Variables

| env variable | description |
|--|--|
| BACKUP_DIR | Directory to save the backup at. Defaults to `/backups`. |
| BACKUP_SUFFIX | Filename suffix to save the backup. Defaults to `.sql.gz`. |
| BACKUP_KEEP_DAYS | Number of daily backups to keep before removal. Defaults to `7`. |
| BACKUP_KEEP_WEEKS | Number of weekly backups to keep before removal. Defaults to `4`. |
| BACKUP_KEEP_MONTHS | Number of monthly backups to keep before removal. Defaults to `6`. |
| HEALTHCHECK_PORT | Port listening for cron-schedule health check. Defaults to `8080`. |
| MONGO_DB | Comma or space separated list of MONGO databases to backup. Required. |
| MONGO_DB_FILE | Alternative to MONGO_DB, but with one database per line, for usage with docker secrets. |
| MONGO_HOST | MONGO connection parameter; MONGO host to connect to. Required. |
| MONGO_PASSWORD | MONGO connection parameter; MONGO password to connect with. Required. |
| MONGO_PASSWORD_FILE | Alternative to MONGO_PASSWORD, for usage with docker secrets. |
| MONGO_PORT | MONGO connection parameter; mongo port to connect to. Defaults to `27017`. |
| MONGO_USER | MONGO connection parameter; mongo user to connect with. Required. |
| MONGO_USER_FILE | Alternative to MONGO_USER, for usage with docker secrets. |
| SCHEDULE | [Cron-schedule](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules) specifying the interval between mongo backups. Defaults to `@daily`. |
| TZ | [POSIX TZ variable](https://www.gnu.org/software/libc/manual/html_node/TZ-Variable.html) specifying the timezone used to evaluate SCHEDULE cron (example "Europe/Paris"). |

### Manual Backups

By default this container makes daily backups, but you can start a manual backup by running `/backup.sh`.

This script as example creates one backup as the running user and saves it the working folder.

```sh
docker run --rm -v "$PWD:/backups" -u "$(id -u):$(id -g)" -e MONGO_HOST=mongo -e MONGO_DB=dbname -e MONGO_USER=user -e MONGO_PASSWORD=password  acouvreur/mongo-backup-local /backup.sh
```

### Automatic Periodic Backups

You can change the `SCHEDULE` environment variable in `-e SCHEDULE="@daily"` to alter the default frequency. Default is `daily`.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

Folders `daily`, `weekly` and `monthly` are created and populated using hard links to save disk space.

## Restore examples

Some examples to restore/apply the backups.

### Restore locally

Replace the backupfile name, `$CONTAINER`, `$USERNAME` and `$DBNAME` from the following command:

```sh
zcat backupfile.sql.gz | docker exec --tty --interactive $CONTAINER psql --username=$USERNAME --dbname=$DBNAME -W
```

### Restore to a remote server

Replace `$BACKUPFILE`, `$VERSION`, `$HOSTNAME`, `$PORT`, `$USERNAME` and `$DBNAME` from the following command:

```sh
docker run --rm --tty --interactive -v $BACKUPFILE:/tmp/backupfile.archive mongo:$VERSION /bin/sh -c "zcat /tmp/backupfile.sql.gz | psql --host=$HOSTNAME --port=$PORT --username=$USERNAME --dbname=$DBNAME -W"
```
