# Backup and Restore Scripts

## Table of Contents

- [Backup and Restore Scripts](#backup-and-restore-scripts)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Requirements](#requirements)
  - [Directory Structure](#directory-structure)
  - [Backup Instructions](#backup-instructions)
    - [Usage](#usage)
    - [Options](#options)
  - [Restore Instructions](#restore-instructions)
    - [Usage](#usage-1)
    - [Restore Process](#restore-process)
    - [Notes](#notes)

## Introduction

This set of scripts includes `backup.sh` and `restore.sh` for backing up and restoring Docker images, containers, and volumes for a Docker Compose project.

## Requirements

Before using these scripts, you need to install the following tools:

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [jq](https://stedolan.github.io/jq/download/)
- [pv](https://linux.die.net/man/1/pv)
- [busybox](https://busybox.net/downloads/binaries/)

To install these tools on Ubuntu, you can use the following commands:

```sh
sudo apt update
sudo apt install docker.io docker-compose jq pv busybox
```

## Directory Structure

Example directory structure for a Docker Compose project (e.g., a WordPress setup) after extracting the backup:

```sh
├── backup.sh
├── data
│   ├── dumps
│   └── services
│       ├── db
│       │   └── volumes
│       │       └── db
│       │           └── _data
│       └── wordpress
│           └── volumes
│               └── wordpress
│                   └── _data
├── docker-compose.yml
└── restore.sh
```

## Backup Instructions

The backup.sh script will back up Docker images, containers, and volumes.

### Usage

1.	Navigate to the directory containing your Docker Compose project.
2.	Run the backup.sh script.

```sh
./backup.sh
```

### Options

•	--skip-images: Skip backing up Docker images.
•	--skip-containers: Skip backing up Docker containers.

Example:

```sh
./backup.sh --skip-images
```

## Restore Instructions

The restore.sh script will restore Docker images, containers, and volumes from the backup.

### Usage

1.	Download and extract the backup to your project directory.
2.	Rename the extracted backup directory to use it as the project directory.
3.	Navigate to the project directory and run the restore.sh script.

```sh
cd /path/to/your/project_dir
./restore.sh
```

### Restore Process

1.	Create Docker volumes and containers without starting them.
2.	Restore data into the volumes.
3.	Restore Docker images.
4.	Restore Docker containers.
5.	Start the containers.

### Notes

•	Ensure that the required tools are installed before running the script.
•	Verify that the directories and files in the backup are correctly extracted before running the script.

Good luck!