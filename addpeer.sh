#!/bin/bash

if [[ -x "$(command -v "readlink")" ]]; then
    basepath=$(dirname $(readlink -f $0 2>/dev/null) 2>/dev/null)
else
    # this is just a fallback if readlink is not available
    # because it cannot deal with symlinks correctly
    basepath=$( cd -- "$( dirname -- "$0" )" &> /dev/null && pwd )
fi

if [[ -z "$basepath" ]]; then
    echo "Could not determine script base path" 1>&2
    exit 1
fi

basename=$(basename $0)

if [[ -z "$1" || $1 == "-h" || $1 == "--help" || ( $# -ne 2 && $# -ne 3 ) ]]; then
    echo "$basename <wg0> <name> [profile]" 1>&2
    echo 1>&2
    echo "If profile is not supplied, the script will look for local.profile" 1>&2
    echo "If this is not found, it will use default.profile" 1>&2
    exit
fi

wg=$1
name=$2
profile=$3

wg show $wg &>/dev/null
if [[ $? -ne 0 ]]; then
    echo "Unknown wireguard interface $wg" 1>&2
    exit 1
fi

if [[ $# -eq 2 ]]; then
    if [[ -f "${basepath}/profiles/local.profile" ]]; then
        profile='local'
    else
        profile='default'
    fi
fi

if [[ ! -f "${basepath}/profiles/${profile}.profile" ]]; then
    echo "Could not find profile $profile" 1>&2
    exit 1
fi

echo "Using profile $profile"
profile="${basepath}/profiles/${profile}.profile"

# https://stackoverflow.com/a/43196141
nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

lastIp=$(wg show $wg allowed-ips | tail -1 | grep -oP "\d+\.\d+\.\d+\.\d+")
export ip=$(nextip $lastIp)
export dns=$(ip address show dev $wg | grep inet | grep -oP "\d+\.\d+\.\d+\.\d+")

export key=$(wg genkey)
export pub=$(wg pubkey <<< "$key")
export psk=$(wg genpsk)


export hostSrv=$(cat /etc/hostname)
export portSrv=$(wg show $wg listen-port)
export pubSrv=$(wg show $wg public-key)

wg set $wg peer $pub preshared-key <(printf "%s" "$psk") allowed-ips ${ip}/32

envsubst < "$profile" > "./${name}.conf"

if [[ -f "/etc/wg-dnsmasq/peers.${wg}" ]]; then
    echo -e "${ip}\t${name}" >> "/etc/wg-dnsmasq/peers.${wg}"
    systemctl reload dnsmasq@${wg}.service
fi

if [[ ! -x "$(command -v "qrencode")" ]]; then
    exit
fi

qrencode -t ansiutf8 < "./${name}.conf"
