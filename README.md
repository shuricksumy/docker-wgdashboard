# Docker-WGDashboard

##  This is a docker builder for the project [**WGDashboard**](https://github.com/donaldzou/WGDashboard)

[![Build and Deploy Docker Images](https://github.com/shuricksumy/docker-wgdashboard/actions/workflows/docker-image.yml/badge.svg?branch=main)](https://github.com/shuricksumy/docker-wgdashboard/actions/workflows/docker-image.yml)

> [!TIP]
> - This example will be reachable on http(s)://your_host:10086/wgdashboard
> - Or using traeifk as proxy can be reachable https://your_public_host/wgdashboard

> [!TIP]
> #### Example of IPTABLES rules
> - WG0 rules [ ./scripts/wg0_*.sh ] - trafik is allowded beetween peers and outside the docker
> - WG1 rules [ ./scripts/wg1_*.sh ] - trafik is blocked beetween peers but allowed outside the docker
> - WG2 rules [ ./scripts/wg2_*.sh ] - trafik is allowded beetween peers but blocked outside the docker

## Env vars
| Var name | Example of usage | Description |
|---|----|---|
| TZ | TZ=Europe/Dublin | time zone of server |
| APP_PREFIX| APP_PREFIX=/wgdashboard | The prefix of the web base URL is usually used when accessing a host with a custom path or using reverse proxy based on Nginx or Traefik. Additionally, need to add /static path as well. URL: http(s)://domain_name/app_prefix |
| GLOBAL_DNS | GLOBAL_DNS=8.8.8.8 | IP of DNS server used in config files|
| ENABLE | ENABLE=wg0,wg1,wg2 | The interface names that will start automatically after docker starts|
| PUBLIC_IP | PUBLIC_IP=192.168.88.88 | The public IP address of server which clients use to connect|
| WG0_POST_UP | WG0_POST_UP=iptables -A some rule | Linux command to run after WG0 interface is up, can be WG1_POST_UP, WG2_POST_UP, etc...|
| WG0_POST_DOWN | WG0_POST_UP=iptables -D some rule  | Linux command to run after WG0 interface is down, can be WG1_POST_DOWN, WG2_POST_DOWN, etc...|


`docker-compose.yaml`
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
      # - APP_PREFIX=/wgdashboard
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
    volumes:
      - ./scripts:/scripts
      - ./conf:/etc/wireguard
      - ./app_conf:/opt/wireguarddashboard/app/src/app_conf
      - ./log:/opt/wireguarddashboard/app/src/log
    cap_add:
      - NET_ADMIN
    # labels:
    #      - "traefik.enable=true"
    #      - "traefik.docker.network=npm_proxy"
    #      - "traefik.http.routers.wireguard-dashboard.rule=Host(`your_public_host`) && PathPrefix(`/wgdashboard`, `/static`)"
    #      - "traefik.http.routers.wireguard-dashboard.entrypoints=websecure"
    #      - "traefik.http.routers.wireguard-dashboard.tls=true"
    #      - "traefik.http.services.wireguard-dashboard.loadbalancer.server.port=10086"
```

