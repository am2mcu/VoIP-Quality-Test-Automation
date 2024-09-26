#!/bin/bash

LOG_LEVEL="INFO"

log() {
    declare -A log_levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [CRIT]=4)
    local log_priority=$1
    local log_msg=$2

    [[ ${log_levels[$log_priority]} ]] || return 1
    ((${log_levels[$log_priority]} < ${log_levels[$LOG_LEVEL]})) && return 2

    echo -e "[${log_priority}] ${log_msg}"
}

print_usage() {
    echo "Usage: calculate_mos [file]"
}

calculate_rtt() {
    local rtt_list=$(
        echo "$pcap_output" |
            awk '{print $1}' | xargs -I _ date -d "1970-01-01 _ Z" '+%s%3N'
    )
    local rtt_sum=$(echo "$rtt_list" | paste -sd+ | bc)
    local rtt_num=$(echo "$rtt_list" | wc -l)

    echo $((rtt_sum / rtt_num))
}

calculate_jitter() {
    local jitter_list=$(
        echo "$pcap_output" |
            awk '{print $1}' | xargs -I _ date -d "1970-01-01 _ Z" '+%s%3N' |
            xargs -I _ echo "(_ - $rtt) * (_ - $rtt)" | bc
    )
    local jitter_sum=$(echo "$jitter_list" | paste -sd+ | bc)
    local jitter_num=$(echo "$jitter_list" | wc -l)


    echo "sqrt($jitter_sum / $jitter_num)" | bc
}

calculate_loss() {
    echo
}

calculate_mos() {
    rtt=$(calculate_rtt)
    jitter=$(calculate_jitter)
    loss=$(calculate_loss)

    local effective_rtt=$((rtt + jitter * 2 + 10))
    local r_factor
    if [[ $effective_rtt < 160 ]]; then
        r_factor=$((93.2 - effective_rtt / 40))
    else
        r_factor=$((93.2 - (effective_rtt - 120) / 10))
    fi
    r_factor=$((r_factor - (loss * 2.5)))

    local mos=$((1 + (r_factor * 0.035) + r_factor * (r_factor - 60) * (100 - r_factor) * 0.000007))
    echo $mos
}

read_pcap() {
    pcap_output=$(tcpdump -r "$pcap_path" src port 21134 -ttt --print)
}

main() {
    pcap_path="$1"
    if [[ -z $pcap_path ]]; then
        print_usage
        exit 1
    elif [[ ! -f $pcap_path ]]; then
        log "ERROR" "File not found"
        exit 1
    fi

    read_pcap
    calculate_mos
}

main "$1"
