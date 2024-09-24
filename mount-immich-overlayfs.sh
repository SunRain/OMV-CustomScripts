#!/usr/bin/bash

MASTER_NAS_PATH="/srv/remotemount/master_NAS"
DOCKER_CONTAINER_IMMICH_NAME="immich"
DOCKER_CONTAINER_YML_FILE="/srv/dev-disk-by-id-ata-KIOXIA-EXCERIA_SATA_SSD_93RB70X8K0Z5/docker/ComposeFile/immich/immich.yml"

OVERLAYFS_LOWER="${MASTER_NAS_PATH}/Photos/library"
OVERLAYFS_UPPER="/srv/dev-disk-by-id-ata-KIOXIA-EXCERIA_SATA_SSD_93RB70X8K0Z5/immich_lib_upper"
OVERLAYFS_MERGED="/srv/dev-disk-by-id-ata-KIOXIA-EXCERIA_SATA_SSD_93RB70X8K0Z5/immich_lib_merged"
OVERLAYFS_WORK="/srv/dev-disk-by-id-ata-KIOXIA-EXCERIA_SATA_SSD_93RB70X8K0Z5/immich_lib_worker"

# /srv/dev-disk-by-id-ata-KIOXIA-EXCERIA_SATA_SSD_93RB70X8K0Z5/docker/ComposeFile/immich

function chk_master_nas_nfs_mount() {
    echo "Check if master nas path is mounted"
    local cnt=0
    while ((cnt <= 10)); do
        if grep ${MASTER_NAS_PATH} /proc/mounts; then
            echo "Master nas path is mounted"
            return 0
        fi
        echo "loop ${cnt} for waiting master nas mounted"
        ((cnt++)) || true
        sleep 5s
    done
    return 1
}

function mv_files_from_merged_dir_to_upper_dir() {
    #TODO refactor later
    echo "SIMPLY Move merged files to upper"
    if cp -a ${OVERLAYFS_MERGED:?}/* ${OVERLAYFS_UPPER:?}; then
        # rm -rf ${OVERLAYFS_MERGED}/*
        rm -rf "${OVERLAYFS_MERGED:?}/"*
    fi
}

function compose_up_immich_container() {
    local cnt=0
    while ((cnt <= 10)); do
        if ! docker ps | grep ${DOCKER_CONTAINER_IMMICH_NAME}; then
            echo "immich container is not running, try to start it, cnt ${cnt}}"
            docker compose -f ${DOCKER_CONTAINER_YML_FILE} up -d
        else
            echo "immich container is running"
            return 0
        fi
        ((cnt++)) || true
        sleep 10s
    done
    return 1
}

function compose_down_immich_container() {
    local cnt=0
    while ((cnt <= 10)); do
        if docker ps | grep ${DOCKER_CONTAINER_IMMICH_NAME}; then
            echo "immich container is running, try to compose down, cnt ${cnt}}"
            docker compose -f ${DOCKER_CONTAINER_YML_FILE} down
        else
            echo "immich container is not running"
            return 0
        fi
        ((cnt++)) || true
        sleep 10s
    done
    return 1
}

function mount_and_start_immich_overlayfs() {
    echo "Start mount immich overlayfs"
    if ! compose_down_immich_container; then
        echo "immich container is not stopped, can't stop it"
        return 1
    fi

    if docker ps | grep ${DOCKER_CONTAINER_IMMICH_NAME}; then
        echo "immich container is running, can't stop it"
        return 1
    fi

    if ! mountpoint -q ${OVERLAYFS_MERGED}; then
        echo "Mount immich overlayfs"
        mkdir -p ${OVERLAYFS_LOWER} ${OVERLAYFS_UPPER} ${OVERLAYFS_MERGED} ${OVERLAYFS_WORK}
        if ! mount -t overlay overlay -o redirect_dir=on,nfs_export=on,index=on,lowerdir=${OVERLAYFS_LOWER},upperdir=${OVERLAYFS_UPPER},workdir=${OVERLAYFS_WORK} ${OVERLAYFS_MERGED}; then
            echo "Mount immich overlayfs failed"
            return 1
        fi
    fi

    echo "now start immich container"
    if compose_up_immich_container; then
        echo "immich container is running"
        return 0
    else
        echo "immich container is not running"
        return 1
    fi

}

function chk_docker_status() {
    echo "Check docker status"
    local cnt=0
    while ((cnt <= 10)); do
        if ! systemctl status docker | grep "Active:" | grep "running"; then
            echo "Docker is not running, try restart docker, cnt ${cnt}"
            systemctl restart docker
        else
            echo "Docker is running"
            return 0
        fi
        ((cnt++)) || true
        sleep 20s
    done
    return 1
}

function main() {
    if ! chk_docker_status; then
        echo "Docker is not running"
        return 1
    fi

    if ! compose_down_immich_container; then
        echo "can't stop immich server, ignore next setps"
        return 1
    fi

    if ! chk_master_nas_nfs_mount; then
        echo "Master nas path is not mounted, start immich directly"
        compose_up_immich_container
    else
        mv_files_from_merged_dir_to_upper_dir
        mount_and_start_immich_overlayfs
    fi

}

main &

