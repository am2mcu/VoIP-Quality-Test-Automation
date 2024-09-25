#!/bin/bash

LOG_LEVEL="INFO"
PACKAGE_NAME="tcpdump"


log() {
    declare -A log_levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [CRIT]=4)
    local log_priority=$1
    local log_msg=$2

    [[ ${log_levels[$log_priority]} ]] || return 1
    (( ${log_levels[$log_priority]} < ${log_levels[$LOG_LEVEL]} )) && return 2

    echo -e "${log_priority}: ${log_msg}"
}

check_permission() {
    if [[ $(id -u) != 0 ]]; then
        log "ERROR" "Run as root"
        exit 1
    fi
}

check_network() {
    if ! ping -q -c1 1.1.1.1 &>/dev/null; then
        log "ERROR" "No internet connection available"
        exit 1
    fi
}

install_package() {
    local package_name=$1

    if ! dpkg -s $package_name &> /dev/null; then
        log "ERROR" "$package_name not found."
        apt -y install $package_name
    fi
}

main() {
    check_permission
    check_network

    install_package $PACKAGE_NAME
}

main