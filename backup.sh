#! /bin/sh

set -e

if [ "${MONGO_DB}" = "**None**" -a "${MONGO_DB_FILE}" = "**None**" ]; then
  echo "You need to set the MONGO_DB or MONGO_DB_FILE environment variable."
  exit 1
fi

if [ "${MONGO_HOST}" = "**None**" ]; then
  echo "You need to set the MONGO_HOST environment variable."
  exit 1
fi

if [ "${MONGO_USER}" = "**None**" -a "${MONGO_USER_FILE}" = "**None**" ]; then
  echo "You need to set the MONGO_USER or MONGO_USER_FILE environment variable."
  exit 1
fi

if [ "${MONGO_PASSWORD}" = "**None**" -a "${MONGO_PASSWORD_FILE}" = "**None**" -a "${MONGO_PASSFILE_STORE}" = "**None**" ]; then
  echo "You need to set the MONGO_PASSWORD or MONGO_PASSWORD_FILE or MONGO_PASSFILE_STORE environment variable or link to a container named MONGO."
  exit 1
fi

#Process vars
if [ "${MONGO_DB_FILE}" = "**None**" ]; then
  MONGO_DBS=$(echo "${MONGO_DB}" | tr , " ")
elif [ -r "${MONGO_DB_FILE}" ]; then
  MONGO_DBS=$(cat "${MONGO_DB_FILE}")
else
  echo "Missing MONGO_DB_FILE file."
  exit 1
fi
if [ "${MONGO_USER_FILE}" = "**None**" ]; then
  export MGUSER="${MONGO_USER}"
elif [ -r "${MONGO_USER_FILE}" ]; then
  export MGUSER=$(cat "${MONGO_USER_FILE}")
else
  echo "Missing MONGO_USER_FILE file."
  exit 1
fi
if [ "${MONGO_PASSWORD_FILE}" = "**None**" -a "${MONGO_PASSFILE_STORE}" = "**None**" ]; then
  export MGPASSWORD="${MONGO_PASSWORD}"
elif [ -r "${MONGO_PASSWORD_FILE}" ]; then
  export MGPASSWORD=$(cat "${MONGO_PASSWORD_FILE}")=
else
  echo "Missing MONGO_PASSWORD_FILE file."
  exit 1
fi
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

#Initialize dirs
mkdir -p "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

#Loop all databases
for DB in ${MONGO_DBS}; do
  #Initialize filename vers
  DFILE="${BACKUP_DIR}/daily/${DB}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
  WFILE="${BACKUP_DIR}/weekly/${DB}-`date +%G%V`${BACKUP_SUFFIX}"
  MFILE="${BACKUP_DIR}/monthly/${DB}-`date +%Y%m`${BACKUP_SUFFIX}"
  #Create dump
  echo "Creating dump of ${DB} database from ${MONGO_HOST}..."
  mongodump -d "${DB}" -u "${MGUSER}" -p "${MGPASSWORD}" --authenticationDatabase=admin --archive="${DFILE}" mongodb://$MONGO_HOST:$MONGO_PORT ${MONGO_EXTRA_OPTS}
  #Copy (hardlink) for each entry
  if [ -d "${DFILE}" ]; then
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${WFILENEW}" "${MFILENEW}"
    mkdir "${WFILENEW}" "${MFILENEW}"
    ln -f "${DFILE}/"* "${WFILENEW}/"
    ln -f "${DFILE}/"* "${MFILENEW}/"
    rm -rf "${WFILE}" "${MFILE}"
    mv -v "${WFILENEW}" "${WFILE}"
    mv -v "${MFILENEW}" "${MFILE}"
  else
    ln -vf "${DFILE}" "${WFILE}"
    ln -vf "${DFILE}" "${MFILE}"
  fi
  #Clean old files
  echo "Cleaning older than ${KEEP_DAYS} days for ${DB} database from ${MONGO_HOST}..."
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime +${KEEP_DAYS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime +${KEEP_WEEKS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime +${KEEP_MONTHS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
done

echo "Mongo backup created successfully"