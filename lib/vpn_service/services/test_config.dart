const testConfig = '''{
    "dns": {
        "hosts": {
            "domain:googleapis.cn": "googleapis.com"
        },
        "queryStrategy": "UseIPv4",
        "servers": [
            "1.1.1.1",
            {
                "address": "1.1.1.1",
                "domains": [
                ],
                "port": 53
            },
            {
                "address": "8.8.8.8",
                "domains": [
                ],
                "port": 53
            }
        ]
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": 10808,
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": true,
                "userLevel": 8
            },
            "sniffing": {
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "enabled": true
            },
            "tag": "socks"
        },
        {
            "listen": "127.0.0.1",
            "port": 10809,
            "protocol": "http",
            "settings": {
                "userLevel": 8
            },
            "sniffing": {
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "enabled": true
            },
            "tag": "http"
        },
        {
            "listen": "127.0.0.1",
            "port": 11111,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1"
            },
            "tag": "metrics_in"
        }
    ],
    "log": {
        "loglevel": "warning"
    },
    "meta": null,
    "metrics": {
        "tag": "metrics_out"
    },
    "outbounds": [
        {
            "mux": {
                "concurrency": -1,
                "enabled": false,
                "xudpConcurrency": 8,
                "xudpProxyUDP443": ""
            },
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": "89.22.226.178",
                        "port": 8443,
                        "users": [
                            {
                                "encryption": "none",
                                "flow": "xtls-rprx-vision",
                                "id": "ad87aeca-bec5-48b4-bfe2-50d37d15f5e5",
                                "level": 8,
                                "security": "auto"
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "realitySettings": {
                    "allowInsecure": false,
                    "fingerprint": "chrome",
                    "publicKey": "FIwSyEwgTqSgMWMlN0kP9Aw5V6C2_k4-kvNSDa7B9kQ",
                    "serverName": "www.microsoft.com",
                    "shortId": "83cabdf6e9d5aef4",
                    "show": false,
                    "spiderX": "/"
                },
                "security": "reality",
                "tcpSettings": {
                    "header": {
                        "type": "none"
                    }
                }
            },
            "tag": "proxy"
        },
        {
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIP"
            },
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "settings": {
                "response": {
                    "type": "http"
                }
            },
            "tag": "block"
        }
    ],
    "policy": {
        "levels": {
            "0": {
                "statsUserDownlink": true,
                "statsUserUplink": true
            },
            "8": {
                "connIdle": 300,
                "downlinkOnly": 1,
                "handshake": 4,
                "uplinkOnly": 1
            }
        },
        "system": {

            "statsInboundDownlink": true,
            "statsInboundUplink": true,
            "statsOutboundDownlink": true,
            "statsOutboundUplink": true
        }
    },
    "remarks": "RealityVPN",
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "inboundTag": [
                    "metrics_in"
                ],
                "outboundTag": "metrics_out"
            },
            {
                "ip": [
                    "1.1.1.1"
                ],
                "outboundTag": "proxy",
                "port": "53"
            },
            {
                "ip": [
                    "8.8.8.8"
                ],
                "outboundTag": "direct",
                "port": "53"
            }
        ]
    },
    "stats": {
    }
}
''';