# Ghost blog backup for Docker Cloud

This script backs up the entire `$GHOST_CONTENT` directory of a [Ghost](https://ghost.org/)
blog running in [Docker Cloud](https://cloud.docker.com/).

> Currently only Dropbox is supported as a storage option.

## Usage

```bash
$ ./backup.sh ghost my-stack
```

where `ghost` is the Service name of a running Ghost blog container and
`my-stack` is the name of the Stack that the Service is running under.

## Implementation

The script uses the Docker Cloud [backup strategy](https://docs.docker.com/docker-cloud/apps/volumes/#/back-up-data-volumes)
to copy all files in `$GHOST_CONTENT` locally to `/tmp/ghost-backup-...`.
Once all files are copied and a compressed tarball created, that archive
is uploaded to Dropbox using [Dropbox Uploader](https://github.com/andreafabrizi/Dropbox-Uploader).
The archive and all copied files are cleaned up on successful upload to Dropbox.
