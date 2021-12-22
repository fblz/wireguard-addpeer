[Interface]
Address = ${ip}/24
PrivateKey = ${key}
DNS = ${dns}

[Peer]
PublicKey = ${pubSrv}
PresharedKey = ${psk}
AllowedIPs = 0.0.0.0/0
Endpoint = ${hostSrv}:${portSrv}
