# # Stage 1: Frontend Build
# FROM node:18 AS frontend-build

# # Set the working directory inside the container
# WORKDIR /app

# # Copy the repository from the local filesystem into the container
# COPY ./WGDashboard /app

# WORKDIR /app/src/static/app

# # Install Vite globally as a dev dependency
# RUN npm install -g vite@latest

# # Install project dependencies
# RUN npm install

# # Build the app
# RUN npm run build

# Stage 2: Final Build
FROM debian:stable-slim AS final-build

# Environment variables
ENV wg_net="10.0.0.1"
ENV tz="Europe/Dublin"
ENV global_dns="1.1.1.1"
ENV public_ip="0.0.0.0"
ENV WGDASH=/opt/wireguarddashboard

# Set timezone
RUN ln -sf /usr/share/zoneinfo/${tz} /etc/localtime

# Install required packages and clean up
RUN apt-get update && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
     curl git sudo iproute2 iptables iputils-ping \
     openresolv procps python3 python3-pip python3-venv \
     traceroute wireguard wireguard-tools \
  && apt-get remove -y linux-image-* --autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Enable IP forwarding
RUN echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf 

# Copy the WGDashboard repository from the local filesystem into the container
COPY ./WGDashboard ${WGDASH}/app

# Add var CONFIGURATION_PATH to sudo user
ENV CONFIGURATION_PATH=${WGDASH}/app/src/app_conf
# Ensure sudo retains the environment variable
RUN echo 'Defaults env_keep += "CONFIGURATION_PATH"' >> /etc/sudoers

# Set up Python virtual environment
RUN python3 -m venv ${WGDASH}/app/src/venv \
  && mkdir -p ${WGDASH}/app/src/log \
  && mkdir -p ${WGDASH}/app/src/app_conf

# Install Python dependencies
RUN . ${WGDASH}/app/src/venv/bin/activate \
  && pip3 install -r ${WGDASH}/app/src/requirements.txt \
  && chmod +x ${WGDASH}/app/src/wgd.sh \
  && ${WGDASH}/app/src/wgd.sh install

# # After stage 1 (Frontend Build) copy builded front-end application 
# RUN rm -rf ${WGDASH}/app/src/static/app/dist/*
# COPY --from=frontend-build /app/src/static/app/dist ${WGDASH}/app/src/static/app/dist/

# Set up volume for WireGuard configuration
VOLUME /etc/wireguard
VOLUME ${WGDASH}/app/src/app_conf

# Healthcheck to ensure the container is running correctly
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -s -o /dev/null -w "%{http_code}" http://localhost:10086/signin | grep -q "401" && exit 0 || exit 1

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Expose the default port for WireGuard Dashboard
EXPOSE 10086

# Set the entrypoint for the container
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
