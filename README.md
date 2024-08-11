# Docker-WGDashboard

##  This is a docker builder for perspective project [**WGDashboard**](https://github.com/donaldzou/WGDashboard/tree/v4) v4

Note: After the very first run need to restart docker to replace all env vars !

```
networks:
    default:
        driver: bridge
    npm_proxy:
        name: npm_proxy
        driver: bridge
        ipam:
            config:
                - subnet: 172.50.0.0/24

services:
  wireguard-dashboard:
    image: shuricksumy/wgdasboard:latest
    # build:
    #   context: .
    #   dockerfile: Dockerfile
    restart: unless-stopped
    container_name: wire-dash
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.forwarding=1
      - net.ipv4.conf.all.src_valid_mark=1
    environment:
      - TZ=Europe/Dublin
      - GLOBAL_DNS=8.8.8.8
      - ENABLE=wg0,wg1,wg2
      - PUBLIC_IP=192.168.88.88
      # SCRIPTS
      - WG0_POST_UP=iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE; iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE; iptables -I INPUT 1 -i wg0 -j ACCEPT; iptables -I FORWARD 1 -i eth+ -o wg0 -j ACCEPT; iptables -I FORWARD 1 -i wg0 -o eth+ -j ACCEPT
      - WG0_POST_DOWN=iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE; iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE; iptables -D INPUT -i wg0 -j ACCEPT; iptables -D FORWARD -i eth+ -o wg0 -j ACCEPT; iptables -D FORWARD -i wg0 -o eth+ -j ACCEPT
      - WG1_POST_UP=iptables -t nat -A POSTROUTING -o wg1 -j MASQUERADE; iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE; iptables -I INPUT 1 -i wg1 -j ACCEPT; iptables -I FORWARD 1 -i eth+ -o wg1 -j ACCEPT; iptables -I FORWARD 1 -i wg1 -o eth+ -j ACCEPT
      - WG1_POST_DOWN=iptables -t nat -D POSTROUTING -o wg1 -j MASQUERADE; iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE; iptables -D INPUT -i wg1 -j ACCEPT; iptables -D FORWARD -i eth+ -o wg1 -j ACCEPT; iptables -D FORWARD -i wg1 -o eth+ -j ACCEPT
      - WG2_POST_UP=iptables -t nat -A POSTROUTING -o wg2 -j MASQUERADE; iptables -t nat -A POSTROUTING -o eth+ -j MASQUERADE; iptables -I INPUT 1 -i wg2 -j ACCEPT; iptables -I FORWARD 1 -i eth+ -o wg2 -j ACCEPT; iptables -I FORWARD 1 -i wg2 -o eth+ -j ACCEPT
      - WG2_POST_DOWN=iptables -t nat -D POSTROUTING -o wg2 -j MASQUERADE; iptables -t nat -D POSTROUTING -o eth+ -j MASQUERADE; iptables -D INPUT -i wg2 -j ACCEPT; iptables -D FORWARD -i eth+ -o wg2 -j ACCEPT; iptables -D FORWARD -i wg2 -o eth+ -j ACCEPT
    networks:
          npm_proxy:
              ipv4_address: 172.50.0.10
    ports:
      - 10086:10086/tcp
      - 51820-51830:51820-51830/udp
    volumes:
      - ./conf:/etc/wireguard
      - ./log:/opt/wireguarddashboard/app/src/log
      - ./db:/opt/wireguarddashboard/app/src/db
      # touch ./ini/wg-dashboard.ini
      - ./ini/wg-dashboard.ini:/opt/wireguarddashboard/app/src/wg-dashboard.ini
    cap_add:
      - NET_ADMIN
```

