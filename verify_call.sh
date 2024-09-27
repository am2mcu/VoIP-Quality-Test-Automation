#!/bin/bash

LOG_LEVEL="INFO"
PACKAGE_NAME="tcpdump"
INTERFACE="any"
TCPDUMP_TIMEOUT=5

log() {
    declare -A log_levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [CRIT]=4)
    local log_priority=$1
    local log_msg=$2

    [[ ${log_levels[$log_priority]} ]] || return 1
    ((${log_levels[$log_priority]} < ${log_levels[$LOG_LEVEL]})) && return 2

    echo -e "[${log_priority}] ${log_msg}"
}

print_usage() {
    echo "Usage: verify_host_connection [ip:port] [ip:port] [ip:port] [ip:port]"
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

    if ! dpkg -s $package_name &>/dev/null; then
        log "ERROR" "$package_name not found."
        apt -y install $package_name
    fi
}

verify_host_connection() {
    local src_ip=$1
    local src_port=$2
    local dst_ip=$3
    local dst_port=$4

    if timeout $TCPDUMP_TIMEOUT \
        tcpdump -q -n -c1 -i $INTERFACE \
        "(src host $src_ip && src port $src_port) && (dst host $dst_ip && dst port $dst_port)" \
        &>/dev/null; then

        log "INFO" "Connection stablished"
        return 0
    else
        log "ERROR" "No connection stablished"
        return 1
    fi
}

parse_hostname() {
    # convert ip:port to (ip port)
    echo $1 | sed 's/:/ /'
}

save_packets() {
    local src_ip=$1
    local src_port=$2
    local dst_ip=$3
    local dst_port=$4

    local pcap_path="/tmp/${src_ip}.${src_port}_${dst_ip}.${dst_port}.pcap"

    # create .pcap files for root instead of tcpdump
    timeout $TCPDUMP_TIMEOUT \
        tcpdump -i $INTERFACE -w $pcap_path -Z root \
        "(src host $src_ip && src port $src_port) && (dst host $dst_ip && dst port $dst_port)" &> /dev/null
}

check_call() {
    for ((i = 0; i < ${#user_hosts[@]}; i += 2)); do
        log "INFO" "${switch_hosts[$i]} ${switch_hosts[$i + 1]} > ${user_hosts[$i]} ${user_hosts[$i + 1]}"
        verify_host_connection \
            ${switch_hosts[$i]} ${switch_hosts[$i + 1]} \
            ${user_hosts[$i]} ${user_hosts[$i + 1]}
        save_packets \
            ${switch_hosts[$i]} ${switch_hosts[$i + 1]} \
            ${user_hosts[$i]} ${user_hosts[$i + 1]}

        log "INFO" "${switch_hosts[$i]} ${switch_hosts[$i + 1]} < ${user_hosts[$i]} ${user_hosts[$i + 1]}"
        verify_host_connection \
            ${user_hosts[$i]} ${user_hosts[$i + 1]} \
            ${switch_hosts[$i]} ${switch_hosts[$i + 1]}
        save_packets \
            ${user_hosts[$i]} ${user_hosts[$i + 1]} \
            ${switch_hosts[$i]} ${switch_hosts[$i + 1]}
    done
}

main() {
    switch_hosts=($(parse_hostname $1) $(parse_hostname $2))
    user_hosts=($(parse_hostname $3) $(parse_hostname $4))

    check_permission
    check_network

    install_package $PACKAGE_NAME

    check_call
}

if [[ $# != 4 ]]; then
    print_usage
    exit 1
fi

main $1 $2 $3 $4
