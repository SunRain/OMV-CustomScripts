#!/usr/bin/bash

RC_CFG_NAME="123panWebdav:"
RC_MOUNT_PATH="/srv/rclonemount/123panWebdav"
RC_CACHE_DIR="/var/cache/rclone"
RC_MOUNT_OPTS=(
    "--daemon"
    "--vfs-cache-mode" "writes"
    "--allow-other"
    "--umask" "000"
    "--cache-dir" "${RC_CACHE_DIR}"
)

BORGBACKUP_REPO_DATA_DIR_TO="/srv/dev-disk-by-id-ata-KIOXIA-EXCERIA_SATA_SSD_93RB70X8K0Z5/BorgBackupRepo/data"
BORGBACKUP_REPO_DATA_DIR_FROM="${RC_MOUNT_PATH}/omv128gBackup/BorgBackupData/data"
PAN123_DAVFS_MOUNT_PATH="/srv/remotemount/123panDavfs"


function chk_davfs_mount() {
    echo "Check if 123pan davfs is mounted"
    local cnt=0
    while ((cnt <= 10)); do
        if grep "${PAN123_DAVFS_MOUNT_PATH}" /proc/mounts; then
            echo "123pan davfs path is mounted"
            return 0
        fi
        echo "loop ${cnt} for waiting 123pan davfs path mounted"
        ((cnt++)) || true
        sleep 5s
    done
    return 1
}

function mount_rclone_path() {
    echo "Mount rclone path"

    if [ ! -d "${RC_MOUNT_PATH}" ]; then
        echo "rclone mount path is not exist, try to create it"
        if ! mkdir -p "${RC_MOUNT_PATH}"; then
            echo "Create rclone mount path failed"
            return 1
        fi
        chmod 0775 "${RC_MOUNT_PATH}"
    fi

    if [ ! -d "${RC_CACHE_DIR}" ]; then
        echo "rclone cache dir is not exist, try to create it"
        if ! mkdir -p "${RC_CACHE_DIR}"; then
            echo "Create rclone cache dir failed"
            return 1
        fi
        chmod 0775 "${RC_CACHE_DIR}"
    fi

    if ! mountpoint -q "${RC_MOUNT_PATH}"; then
        echo "Try mount rclone path"
        local cnt=0
        while ((cnt <= 10)); do
        #rclone mount test: /mnt/test2 --daemon --vfs-cache-mode writes --allow-other --umask 000 --cache-dir /tmp/rclone

            if ! rclone mount "${RC_CFG_NAME}" "${RC_MOUNT_PATH}" "${RC_MOUNT_OPTS[@]}"; then
                echo "Mount rclone path failed, try again, cnt ${cnt}"
                ((cnt++)) || true
                sleep 5s
            else
                echo "Mount rclone path success"
                return 0
            fi
        done
    fi
    echo "Mount rclone path failed"
    return 1
}

function mount_bind_data_dir() {
    echo "Mount bind data dir"
    if [ ! -d "${BORGBACKUP_REPO_DATA_DIR_TO}" ]; then
        echo "BorgBackupRepo data target dir is not exist."
        return 1
    fi

    if [ ! -d "${BORGBACKUP_REPO_DATA_DIR_FROM}" ]; then
        echo "BorgBackupRepo data from 123pan dir is not exist."
        return 1
    fi

    if ! mount -o bind "${BORGBACKUP_REPO_DATA_DIR_FROM}" "${BORGBACKUP_REPO_DATA_DIR_TO}"; then
        echo "Mount bind data dir failed"
        return 1
    fi
}


function main() {
    if ! chk_davfs_mount; then
        echo "123pan davfs is not mounted"
        return 1
    fi

    if ! mount_rclone_path; then
        echo "Mount rclone path failed"
        return 1
    fi
    if ! mount_bind_data_dir; then
        echo "Mount bind data dir failed"
        return 1
    fi
    echo "Mount bind data dir success"
}

main