git clone --branch v4 https://github.com/donaldzou/WGDashboard.git
# DOCKER_BUILDKIT=1 docker build --progress=plain --no-cache -f ./Dockerfile .
DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile -t shuricksumy/wgdasboard:latest . --push --no-cache