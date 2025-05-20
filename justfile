
set positional-arguments
set dotenv-load

RELEASE_VERSION := env_var_or_default("RELEASE_VERSION", `date +'%Y%m%d.%H%M'`)

# Control which demo setup to use
# IMAGE := "alpine-s6"
IMAGE := env_var_or_default("IMAGE", "debian-systemd")
TEDGE_CHANNEL := env_var_or_default("TEDGE_CHANNEL", "release")

REGISTRY := "ghcr.io"
REPO_OWNER := "thin-edge"

DEV_ENV := ".env"

# Enabling running cross platform tools when building container images
build-setup:
    docker run --privileged --rm tonistiigi/binfmt --install all

# Build the docker images
build *ARGS: build-setup
  just -f {{justfile()}} build-main-systemd {{ARGS}}
  just -f {{justfile()}} build-child-container {{ARGS}}
  just -f {{justfile()}} build-child-systemd {{ARGS}}
  just -f {{justfile()}} build-tedge {{ARGS}}
  just -f {{justfile()}} build-tedge-containermgmt {{ARGS}}
  just -f {{justfile()}} build-mosquitto {{ARGS}}

# Build the main systemd image
build-main-systemd OUTPUT_TYPE='oci,dest=tedge-demo-main.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-main-systemd:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-main-systemd:latest -f images/debian-systemd/debian-systemd.dockerfile --output=type={{OUTPUT_TYPE}} images

# Build the child device container image
build-child-container OUTPUT_TYPE='oci,dest=tedge-demo-child-container.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child-container:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child-container:latest -f images/child-device-container/child.dockerfile --output=type={{OUTPUT_TYPE}} images

# Build the child device systemd image
build-child-systemd OUTPUT_TYPE='oci,dest=tedge-demo-child-systemd.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child-systemd:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child-systemd:latest -f images/child-device-systemd/child.dockerfile --output=type={{OUTPUT_TYPE}} images

# Build the single process container image
build-tedge OUTPUT_TYPE='oci,dest=tedge-demo.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo:latest -f images/tedge/Dockerfile --output=type={{OUTPUT_TYPE}} images/tedge

# Build the single process container image with container management plugin
build-tedge-containermgmt OUTPUT_TYPE='oci,dest=tedge-demo-containermgmt.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-containermgmt:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-containermgmt:latest -f images/tedge-containermgmt/Dockerfile --output=type={{OUTPUT_TYPE}} images/tedge-containermgmt

# Build the mosquitto image (used with the alpine s6 image)
build-mosquitto OUTPUT_TYPE='oci,dest=tedge-mosquitto.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-mosquitto:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-mosquitto:latest -f images/alpine-s6/mosquitto/mosquitto.dockerfile --output=type={{OUTPUT_TYPE}} images/alpine-s6

# Show the device in Cumulocity IoT
show-device:
    c8y identity get --name "$DEVICE_ID" | c8y applications open --application devicemanagement --page device-info

# Create .env file from the template
create-env:
    test -f {{DEV_ENV}} || cp env.template {{DEV_ENV}}

# Prepare up but don't start any containers
prepare-up *args='':
    docker compose --env-file {{DEV_ENV}} -f images/{{IMAGE}}/docker-compose.yaml build --build-arg TEDGE_CHANNEL={{TEDGE_CHANNEL}} {{args}}

# Start the demo
up *args='':
    docker compose --env-file {{DEV_ENV}} -f images/{{IMAGE}}/docker-compose.yaml up -d --build {{args}}

# Start the demo and build without caching
up-no-cache *args='':
    docker compose --env-file {{DEV_ENV}} -f images/{{IMAGE}}/docker-compose.yaml build --build-arg TEDGE_CHANNEL={{TEDGE_CHANNEL}} --no-cache {{args}}
    just -f {{justfile()}} DEV_ENV={{DEV_ENV}} IMAGE={{IMAGE}} up {{args}}

# Stop the demo (but keep the data)
down:
    docker compose --env-file {{DEV_ENV}} -f images/{{IMAGE}}/docker-compose.yaml down

# Collect logs files then stop and destroy the demo and all of its data
down-all:
    just -f {{justfile()}} DEV_ENV={{DEV_ENV}} IMAGE={{IMAGE}} collect-logs ||:
    docker compose --env-file {{DEV_ENV}} -f images/{{IMAGE}}/docker-compose.yaml down -v

# Configure and register the device to the cloud
bootstrap *ARGS:
    @docker compose --env-file {{DEV_ENV}} -f images/{{IMAGE}}/docker-compose.yaml exec tedge env C8Y_USER=${C8Y_USER:-} C8Y_PASSWORD=${C8Y_PASSWORD:-} DEVICE_ID=${DEVICE_ID:-} bootstrap.sh {{ARGS}}

# Configure and register the device to the cloud using go-c8y- c8y-tedge extension
bootstrap-c8y *ARGS:
    cd "images/{{IMAGE}}" && c8y tedge bootstrap-container tedge {{ARGS}}

# Bootstrap container using the go-c8y-cli c8y-tedge extension
bootstrap-container *ARGS="":
    cd "images/{{IMAGE}}" && c8y tedge bootstrap-container bootstrap {{ARGS}}

# Start a shell on the main device
shell *args='zsh':
    docker compose -f images/{{IMAGE}}/docker-compose.yaml exec tedge {{args}}

# Start a shell on the child device
shell-child *args='bash':
    docker compose -f images/{{IMAGE}}/docker-compose.yaml exec child01 {{args}}

# Show logs of the main device
logs *args='':
    docker compose -f images/{{IMAGE}}/docker-compose.yaml exec tedge journalctl -f -u "c8y-*" -u "tedge-*" {{args}}

# Show child device logs
logs-child child='child01' *args='':
    docker compose -f images/{{IMAGE}}/docker-compose.yaml logs {{child}} -f {{args}}

# Install python virtual environment
venv:
  [ -d .venv ] || python3 -m venv .venv
  ./.venv/bin/pip3 install -r tests/requirements.txt

# Run tests
test *ARGS='':
  ./.venv/bin/python3 -m robot.run --outputdir output {{ARGS}} tests/{{IMAGE}}

# Cleanup device and all it's dependencies
cleanup DEVICE_ID $CI="true":
    echo "Removing device and child devices (including certificates)"
    c8y devicemanagement certificates list -n --tenant "$(c8y currenttenant get --select name --output csv)" --filter "name eq {{DEVICE_ID}}" --pageSize 2000 | c8y devicemanagement certificates delete --tenant "$(c8y currenttenant get --select name --output csv)"
    c8y inventory find -n --owner "device_{{DEVICE_ID}}" -p 100 | c8y inventory delete
    c8y users delete -n --id "device_{{DEVICE_ID}}" --tenant "$(c8y currenttenant get --select name --output csv)" --silentStatusCodes 404 --silentExit

# Trigger a release (by creating a tag)
release:
    git tag -a "{{RELEASE_VERSION}}" -m "{{RELEASE_VERSION}}"
    git push origin "{{RELEASE_VERSION}}"
    @echo
    @echo "Created release (tag): {{RELEASE_VERSION}}"
    @echo

# Collect logs
collect-logs output="output/logs":
    COMPOSE_FILE="images/{{IMAGE}}/docker-compose.yaml" ./scripts/collect-logs.sh
