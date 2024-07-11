#!/usr/bin/env bash

### Bash Environment Setup
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
IFS=$'\n'

# Initialize variables
project_dir="${PWD}"
project_name=$(basename "$project_dir")

# Check for docker-compose.yml
if [ -f "$project_dir/docker-compose.yml" ]; then
	echo "[i] Found docker-compose config at $project_dir/docker-compose.yml"
else
	echo "[X] Could not find a docker-compose.yml file in $project_dir"
	exit 1
fi

# Load environment variables if available
[ -f "$project_dir/docker-compose.env" ] && source "$project_dir/docker-compose.env"
[ -f "$project_dir/.env" ] && source "$project_dir/.env"

# Restore Docker images
echo "[+] Restoring Docker images..."
for service_name in $(docker compose config --services); do
	service_image_dir="$project_dir/data/services/$service_name"
	if [ -f "$service_image_dir/image.tar" ]; then
		echo "[*] Loading Docker image for ${service_name} from ${service_image_dir}/image.tar"
		docker load -i "$service_image_dir/image.tar"
	else
		echo "    - No image found for ${service_name}, skipping image restore."
	fi
done

# Create Docker volumes and containers without starting them
echo "[+] Creating Docker volumes and containers..."
docker compose up --no-start

# Restore data into volumes
echo "[+] Restoring data into volumes..."
for service_name in $(docker compose config --services); do
	echo "[*] Restoring volumes for ${service_name}..."
	service_volume_dir="$project_dir/data/services/$service_name/volumes"

	if [ -d "$service_volume_dir" ]; then
		for volume_path in "$service_volume_dir"/*; do
			volume_name=$(basename "$volume_path")
			target_volume="${project_name}_${volume_name}"

			if [ "$(docker volume ls -q -f name="${target_volume}")" ]; then
				echo "    - Copying data to volume ${target_volume}"
				docker run --rm -v "${target_volume}:/volume_data" -v "${volume_path}/_data:/backup" busybox cp -a /backup/. /volume_data
			else
				echo "    - Volume ${target_volume} does not exist. Skipping..."
			fi
		done
	else
		echo "    - No volumes directory found for ${service_name}"
	fi
done

# Restore Docker containers
echo "[+] Restoring Docker containers..."
for service_name in $(docker compose config --services); do
	service_dir="$project_dir/data/services/$service_name"
	if [ -f "$service_dir/container.tar" ]; then
		echo "[*] Restoring container for ${service_name} from ${service_dir}/container.tar"
		docker import "$service_dir/container.tar" "${service_name}_container"
	else
		echo "    - No container backup found for ${service_name}, skipping container restore."
	fi
done

# Start Docker containers
echo "[+] Starting Docker containers..."
docker compose up -d

echo "[√] Restoration completed."
