# Docker-WGDashboard

##  This is a docker builder for perspective project [**WGDashboard**](https://github.com/donaldzou/WGDashboard/tree/v4) v4

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
    #   context: .                  # The directory containing the Dockerfile
    #   dockerfile: Dockerfile
    restart: unless-stopped
    container_name: wire-dash
    # sysctls:
    #  - net.ipv4.ip_forward=1
    environment:
      - tz=Europe/Dublin          
      - global_dns=8.8.8.8
      - enable=wg0,wg1,wg2
      - public_ip=192.168.88.88
      # SCRIPTS
      - WG0_POST_UP=iptables -t nat -I POSTROUTING 1 -s 11.0.0.1/24 -o eth0 -j MASQUERADE
      - WG0_POST_DOWN=iptables -t nat -D POSTROUTING 1
      - WG1_POST_UP=iptables -t nat -I POSTROUTING 1 -s 12.0.0.2/24 -o eth1 -j MASQUERADE
      - WG1_POST_DOWN=iptables -t nat -D POSTROUTING 1
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

