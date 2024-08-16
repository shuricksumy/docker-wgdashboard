# Docker-WGDashboard

##  This is a docker builder for perspective project [**WGDashboard**](https://github.com/donaldzou/WGDashboard/tree/v4) v4

### IPTABLES rules are testing now
- WG0 rules - trafik is allowded beetween peers and inside/outside the docker
- WG1 rules - trafik is blocked beetween peers but allowed inside/outside the docker
- WG2 rules - trafik is allowded beetween peers but blocked outside/inside the docker

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
      - APP_PREFIX=/wgdashboard
      - TZ=Europe/Dublin
      - GLOBAL_DNS=8.8.8.8
      - ENABLE=wg0,wg1,wg2
      - PUBLIC_IP=192.168.88.88
      # SCRIPTS
      - WG0_POST_UP=/bin/bash /scripts/wg0_post_up.sh
      - WG0_POST_DOWN=/bin/bash /scripts/wg0_post_down.sh
      - WG1_POST_UP=/bin/bash /scripts/wg1_post_up.sh
      - WG1_POST_DOWN=/bin/bash /scripts/wg1_post_down.sh
      - WG2_POST_UP=/bin/bash /scripts/wg2_post_up.sh
      - WG2_POST_DOWN=/bin/bash /scripts/wg2_post_down.sh
    networks:
          npm_proxy:
              ipv4_address: 172.50.0.10
    ports:
      - 10086:10086/tcp
      - 51820-51830:51820-51830/udp
    volumes:
      - ./scripts:/scripts
      - ./conf:/etc/wireguard
      - ./log:/opt/wireguarddashboard/app/src/log
      - ./db:/opt/wireguarddashboard/app/src/db
      # touch ./ini/wg-dashboard.ini
      - ./ini/wg-dashboard.ini:/opt/wireguarddashboard/app/src/wg-dashboard.ini
    cap_add:
      - NET_ADMIN
    # labels:
    #      - "traefik.enable=true"
    #      - "traefik.docker.network=npm_proxy"
    #      - "traefik.http.routers.wireguard-dashboard.rule=Host(`your_host`) && PathPrefix(`/wgdashboard`, `/static`)"
    #      - "traefik.http.routers.wireguard-dashboard.entrypoints=websecure"
    #      - "traefik.http.routers.wireguard-dashboard.tls=true"
    #      - "traefik.http.services.wireguard-dashboard.loadbalancer.server.port=10086"
```

