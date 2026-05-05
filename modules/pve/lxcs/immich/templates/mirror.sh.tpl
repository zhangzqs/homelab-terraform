#!/usr/bin/env bash

set -euo pipefail

mkdir -p "${mirror_target_dir}/immich_data"
mkdir -p "${mirror_target_dir}/immich_postgres_data"

rsync -a --delete "${upload_location}/" "${mirror_target_dir}/immich_data/"
rsync -a --delete "${db_data_location}/" "${mirror_target_dir}/immich_postgres_data/"
