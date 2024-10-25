|Latest|Release|
|---|---|
|[![Build and Deploy Docker Images](https://github.com/shuricksumy/docker-wgdashboard/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/shuricksumy/docker-wgdashboard/actions/workflows/build.yml)|[![Build and Deploy Docker Images](https://github.com/shuricksumy/docker-wgdashboard/actions/workflows/build.yml/badge.svg?event=release)](https://github.com/shuricksumy/docker-wgdashboard/actions/workflows/build.yml)|
| Vulnerability Report is inside the Job | Vulnerability Report is inside the Job |

# Docker-WGDashboard

##  This is a docker builder for the project [**WGDashboard**](https://github.com/donaldzou/WGDashboard)

> [!TIP]
> #### SCRIPTS
> Wireguard can run scripts for each interface base on next events:
> - PreUp - put script into ./scripts/ folder with template name **<font style="color:orange">[interface_name]_pre_up.sh</font>**
> - PostUp - put script into ./scripts/ folder with template name **<font style="color:orange">[interface_name]_post_up.sh</font>**
> - PreDown - put script into ./scripts/ folder with template name **<font style="color:orange">[interface_name]_pre_down.sh</font>**
> - PostDown - put script into ./scripts/ folder with template name **<font style="color:orange">[interface_name]_post_down.sh</font>**
> 
> When docker starts, ./scripts/ folders will be scanned automatically and corresponding config will be updated

> [!TIP]
> #### Example of scriptd (IPTABLES rules)
> - wg0 rules [ ./scripts/wg0_*.sh ] - trafik is allowded beetween peers and outside the docker
> - wg1 rules [ ./scripts/wg1_*.sh ] - trafik is blocked beetween peers but allowed outside the docker
> - wg2 rules [ ./scripts/wg2_*.sh ] - trafik is allowded beetween peers but blocked outside the docker

## Env vars
| Var name | Example of usage | Description                                                                                                                                                                                                                     |
|---|----|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| TZ | TZ=Europe/Dublin | Time zone of server                                                                                                                                                                                                             |
| APP_PREFIX| APP_PREFIX=/wgdashboard | The prefix of the web base URL is usually used when accessing a host with a custom path or using reverse proxy based on Nginx or Traefik. Additionally, need to add /static path as well. URL: http(s)://domain_name/app_prefix |
| GLOBAL_DNS | GLOBAL_DNS=8.8.8.8 | IP of DNS server used in config files                                                                                                                                                                                           |
| ENABLE | ENABLE=wg0,wg1,wg2 | The interface names that will start automatically after docker starts                                                                                                                                                           |
| PUBLIC_IP | PUBLIC_IP=192.168.88.88 | The public IP address of server which clients use to connect                                                                                                                                                                    |


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

