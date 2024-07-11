#!/usr/bin/env bash

### Bash Environment Setup
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# set -o xtrace
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n'

# Initialize variables
project_dir="${PWD}"
project_name=$(basename "$project_dir")
skip_images=false
skip_containers=false

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-images)
            skip_images=true
            shift
            ;;
        --skip-containers)
            skip_containers=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -f "$project_dir/docker-compose.yml" ]; then
    echo "[i] Found docker-compose config at $project_dir/docker-compose.yml"
else
    echo "[X] Could not find a docker-compose.yml file in $project_dir"
    exit 1
fi

backup_time=$(date +"%Y-%m-%d_%H-%M")
backup_dir="$project_dir/backups/$project_name-$backup_time"
backup_tar="$project_dir/backups/$project_name-$backup_time.tar.gz"
data_backup_dir="$backup_dir/data"

# Source any needed environment variables
[ -f "$project_dir/docker-compose.env" ] && source "$project_dir/docker-compose.env"
[ -f "$project_dir/.env" ] && source "$project_dir/.env"

echo "[+] Backing up $project_name project to $backup_dir"
mkdir -p "$data_backup_dir"

echo "    - Saving docker-compose.yml config"
cp "$project_dir/docker-compose.yml" "$backup_dir/docker-compose.yml"
cp "$project_dir/backup.sh" "$backup_dir/backup.sh"
cp "$project_dir/restore.sh" "$backup_dir/restore.sh"

# Optional: pause the containers before backing up to ensure consistency
# docker compose pause

# Optional: run a command inside the container to dump your application's state/database to a stable file
echo "    - Saving application state to ./dumps"
mkdir -p "$data_backup_dir/dumps"
# your database/stateful service export commands to run inside docker go here, e.g.
#   docker compose exec postgres env PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip -9 > "$data_bac
kup_dir/dumps/$POSTGRES_DB.sql.gz"
#   docker compose exec redis redis-cli SAVE
#   docker compose exec redis cat /data/dump.rdb | gzip -9 > "$data_backup_dir/dumps/redis.rdb.gz"

for service_name in $(docker compose config --services); do
    image_id=$(docker compose images -q "$service_name")
    image_name=$(docker image inspect --format '{{json .RepoTags}}' "$image_id" | jq -r '.[0]')
    container_id=$(docker compose ps -q "$service_name")

    service_dir="$data_backup_dir/services/$service_name"
    echo "[*] Backing up ${project_name}__${service_name} to ./services/$service_name..."
    mkdir -p "$service_dir"
    
    if [ "$skip_images" = false ]; then
        # save image
        echo "    - Saving $image_name image to ./services/$service_name/image.tar"
        docker save --output "$service_dir/image.tar" "$image_id"
    else
        echo "    - Skipping backup of Docker image for $service_name"
    fi

    if [[ -z "$container_id" ]]; then
        echo "    - Warning: $service_name has no container yet."
        echo "         (has it been started at least once?)"
        continue
    fi

    if [ "$skip_containers" = false ]; then
        # save config
        echo "    - Saving container config to ./services/$service_name/config.json"
        docker inspect "$container_id" > "$service_dir/config.json"

        # save logs
        echo "    - Saving stdout/stderr logs to ./services/$service_name/docker.{out,err}"
        docker logs "$container_id" > "$service_dir/docker.out" 2> "$service_dir/docker.err"

        # save container filesystem
        echo "    - Saving container filesystem to ./services/$service_name/container.tar"
        docker export --output "$service_dir/container.tar" "$container_id"

        # save entire container root dir
        echo "    - Saving container root to $service_dir/root"
        cp -a -r "/var/lib/docker/containers/$container_id" "$service_dir/root"
    else
        echo "    - Skipping backup of Docker container for $service_name"
    fi

    # save data volumes
    for volume_info in $(docker inspect --format '{{range .Mounts}}{{.Name}} {{.Source}}{{end}}' "$container_id"); do
        volume_name=$(echo "$volume_info" | awk '{print $1}')
        volume_source=$(echo "$volume_info" | awk '{print $2}')
        volume_name_cleaned=${volume_name#${project_name}_}
        volume_dir="$service_dir/volumes/$volume_name_cleaned/_data"
        echo "    - Saving $volume_source volume to ./services/$service_name/volumes/$volume_name_cleaned/_data"
        mkdir -p "$volume_dir"
        cp -a -r "$volume_source/." "$volume_dir"
    done
done

#echo "[*] Compressing backup folder to $backup_dir.tar.gz"
# tar -zcf "$backup_dir.tar.gz" --totals -P  "$backup_dir" && rm -Rf "$backup_dir"

# Get the size of the directory for pv
dir_size=$(du -sb "$backup_dir" | awk '{print $1}')

echo "[*] Compressing backup folder to $backup_tar"
tar -cf - -C "$project_dir/backups" "$(basename $backup_dir)" | pv -s "$dir_size" | gzip > "$backup_tar" && rm -Rf "$backup_dir"

echo "[√] Finished Backing up $project_name to $backup_tar."

# Resume the containers if paused above
# docker compose unpause

