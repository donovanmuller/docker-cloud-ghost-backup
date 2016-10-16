#!/bin/bash
set -e

if [ -z "$*" ]; then
  echo "Usage: ./backup.sh <ghost service name> <stack name> [cleanup:-true]";
  exit 0;
fi

if [ -z "$1" ]; then
  echo "Please provide the Ghost Service name to backup";
  exit 0;
fi

if [[ -z "$2" ]] ; then
    echo 'Please provide the Stack name where the Ghost Service is running'
    exit 0
fi

ghost_service_name=$1
ghost_stack_name=$2
cleanup=${3:-true}

# Get the UUID of the 'ghost' service
echo "Getting 'ghost' service UUID for service [${ghost_service_name}] on stack [${ghost_stack_name}]"
ghost_service_uuid=`docker-cloud service ps \
  --status Running \
  --stack ${ghost_stack_name} \
  | grep "^${ghost_service_name}" \
  | awk '{print $2}'`

if [ -z "${ghost_service_uuid}" ]; then
  echo "Error: There was no running 'ghost' service [${ghost_service_name}] on stack [${ghost_stack_name}]";
  exit 0;
fi
echo "Using 'ghost' service UUID [${ghost_service_uuid}]"

# Create the 'ghost-backup' service
echo "Creating 'ghost-backup' service..."
docker-cloud service run -n ghost-backup \
  -p 2222:22 \
  -e AUTHORIZED_KEYS="$(cat ~/.ssh/id_rsa.pub)" \
  --volumes-from ${ghost_service_uuid} \
  tutum/ubuntu

# Wait until it's running
for i in {1..10}
do
  echo "Waiting for 'ghost-backup' to start..."
  ghost_backup_container_uuid=`docker-cloud container ps \
    --status Running \
    | grep "^ghost-backup" \
    | awk '{print $2}'`
  if [ -z "${ghost_backup_container_uuid}" ]; then
    sleep 10
  else
    echo "'ghost-backup' service started"
    break
  fi
done

# Get the container public DNS
echo "Getting 'ghost-backup' container endpoint for [${ghost_backup_container_uuid}]"
ghost_backup_dns=`docker-cloud container inspect ${ghost_backup_container_uuid} \
  | jq -r '.public_dns'`

# scp ${GHOST_CONTENT} and tar up file
echo "Backing up \${GHOST_CONTENT} from [${ghost_backup_dns}]..."
backup_file="ghost-backup-$(date "+%Y%m%d%H%M")"
backup_directory="/tmp/${backup_file}"
backup_archive="ghost-backup-$(date "+%Y%m%d%H%M").tar.bz2"
backup_archive_location="/tmp/${backup_archive}"
mkdir -p ${backup_directory}
echo "Copying and archiving into backup directory [${backup_directory}]"
scp \
  -o StrictHostKeyChecking=no \
  -r \
  -P 2222 \
  root@${ghost_backup_dns}:/var/lib/ghost/* ${backup_directory} && \
  tar -jvcf /tmp/${backup_archive} ${backup_directory}

# Upload to Dropbox
echo "Uploading to Dropbox..."
/Users/donovan/Downloads/dropbox_uploader.sh upload ${backup_archive_location} ${backup_archive}

# Terminate the 'ghost-backup' service
ghost_backup_service_uuid=`docker-cloud service ps \
  --status Running \
  | grep "^ghost-backup" \
  | awk '{print $2}'`
echo "Terminating 'ghost-backup' service [${ghost_backup_service_uuid}]"
docker-cloud service terminate ${ghost_backup_service_uuid}

# Cleanup
if [ "${cleanup}" = true ]; then
  echo "Cleaning up [${backup_directory}] and [${backup_archive_location}]..."
  rm -rf ${backup_directory}
  rm -f ${backup_archive_location}
fi
