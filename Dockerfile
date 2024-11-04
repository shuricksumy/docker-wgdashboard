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
FROM alpine:latest

# Environment variables
ENV TZ="Europe/Dublin"
ENV GLOBAL_DNS="1.1.1.1"
ENV PUBLIC_IP="0.0.0.0"
ENV APP_PREFIX=""
ENV WGDASH=/opt/wireguarddashboard

# Set timezone
RUN ln -sf /usr/share/zoneinfo/${tz} /etc/localtime

# Set timezone
RUN apk add --no-cache tzdata \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && apk update && apk upgrade \
    && apk add --no-cache \
       curl git sudo iproute2 iptables iputils \
       procps python3 py3-pip py3-virtualenv \
       traceroute wireguard-tools \
       gcc python3-dev musl-dev linux-headers \
    && rm -rf /var/cache/apk/*

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
RUN  /bin/bash -c \
  "source ${WGDASH}/app/src/venv/bin/activate \
  && pip3 install --no-cache-dir -r ${WGDASH}/app/src/requirements.txt \
  && chmod +x ${WGDASH}/app/src/wgd.sh \
  && ${WGDASH}/app/src/wgd.sh install"

# # After stage 1 (Frontend Build) copy builded front-end application 
# RUN rm -rf ${WGDASH}/app/src/static/app/dist/*
# COPY --from=frontend-build /app/src/static/app/dist ${WGDASH}/app/src/static/app/dist/

# Set up volume for WireGuard configuration
VOLUME /etc/wireguard
VOLUME ${WGDASH}/app/src/app_conf

# Healthcheck to ensure the container is running correctly
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD sh -c 'pgrep gunicorn > /dev/null && pgrep tail > /dev/null' || exit 1

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
COPY update_wireguard.py /update_wireguard.py

# Expose the default port for WireGuard Dashboard
EXPOSE 10086

# Set the entrypoint for the container
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
