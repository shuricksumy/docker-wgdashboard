ver="4.0.2"
git clone https://github.com/donaldzou/WGDashboard.git

DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile -t shuricksumy/wgdasboard:${ver} . --push --no-cache
DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile -t shuricksumy/wgdasboard:latest . --push