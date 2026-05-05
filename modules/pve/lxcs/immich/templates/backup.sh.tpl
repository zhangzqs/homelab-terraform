#!/usr/bin/env bash

set -euo pipefail

mkdir -p "${backup_target_dir}/immich_data"
mkdir -p "${backup_target_dir}/immich_postgres_data"

rsync -a "${upload_location}/" "${backup_target_dir}/immich_data/"
rsync -a "${db_data_location}/" "${backup_target_dir}/immich_postgres_data/"
