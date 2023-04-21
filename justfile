
set positional-arguments

REGISTRY := "ghcr.io"
REPO_OWNER := "thin-edge"

# Build the docker images
build *ARGS:
  just -f {{justfile()}} build-main-systemd {{ARGS}}
  just -f {{justfile()}} build-child {{ARGS}}

build-main-systemd OUTPUT_TYPE='oci,dest=tedge-demo-main.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-main:{{VERSION}}-systemd -f images/debian-systemd/debian-systemd.dockerfile --output=type={{OUTPUT_TYPE}} images

build-child OUTPUT_TYPE='oci,dest=tedge-demo-child.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child:{{VERSION}} -f images/child-device/child.dockerfile --output=type={{OUTPUT_TYPE}} images/child-device

# Create .env file from the template
create-env:
    test -f .env || cp env.template .env

# Start the demo
up *args='':
    docker compose -f images/debian-systemd/docker-compose.yaml up -d --build {{args}}

# Stop the demo (but keep the data)
down:
    docker compose -f images/debian-systemd/docker-compose.yaml down

# Stop the demo and destroy the data
down-all:
    docker compose -f images/debian-systemd/docker-compose.yaml down -v

# Configure and register the device to the cloud
bootstrap:
    docker compose -f images/debian-systemd/docker-compose.yaml exec tedge ./bootstrap.sh

# Start a shell on the main device
shell *args='bash':
    docker compose -f images/debian-systemd/docker-compose.yaml exec tedge {{args}}

# Start a shell on the child device
shell-child *args='bash':
    docker compose -f images/debian-systemd/docker-compose.yaml exec child01 {{args}}
