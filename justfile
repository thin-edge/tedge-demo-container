
set positional-arguments
set dotenv-load

REGISTRY := "ghcr.io"
REPO_OWNER := "thin-edge"

DEV_ENV := ".env"

# Build the docker images
build *ARGS:
  just -f {{justfile()}} build-main-systemd {{ARGS}}
  just -f {{justfile()}} build-child {{ARGS}}

build-main-systemd OUTPUT_TYPE='oci,dest=tedge-demo-main.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-main-systemd:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-main-systemd:latest -f images/debian-systemd/debian-systemd.dockerfile --output=type={{OUTPUT_TYPE}} images

build-child OUTPUT_TYPE='oci,dest=tedge-demo-child.tar' VERSION='latest':
    docker buildx build --platform linux/amd64,linux/arm64 -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child:{{VERSION}} -t {{REGISTRY}}/{{REPO_OWNER}}/tedge-demo-child:latest -f images/child-device/child.dockerfile --output=type={{OUTPUT_TYPE}} images/child-device

# Create .env file from the template
create-env:
    test -f {{DEV_ENV}} || cp env.template {{DEV_ENV}}

# Start the demo
up *args='':
    docker compose --env-file {{DEV_ENV}} -f images/debian-systemd/docker-compose.yaml up -d --build {{args}}

# Start the demo and build without caching
up-no-cache *args='':
    docker compose --env-file {{DEV_ENV}} -f images/debian-systemd/docker-compose.yaml build --no-cache {{args}}
    just -f {{justfile()}} up {{args}}

# Stop the demo (but keep the data)
down:
    docker compose --env-file {{DEV_ENV}} -f images/debian-systemd/docker-compose.yaml down

# Stop the demo and destroy the data
down-all:
    docker compose --env-file {{DEV_ENV}} -f images/debian-systemd/docker-compose.yaml down -v

# Configure and register the device to the cloud
bootstrap *ARGS:
    @docker compose --env-file {{DEV_ENV}} -f images/debian-systemd/docker-compose.yaml exec tedge env C8Y_PASSWORD=${C8Y_PASSWORD:-} DEVICE_ID=${DEVICE_ID:-} ./bootstrap.sh {{ARGS}}

# Start a shell on the main device
shell *args='bash':
    docker compose -f images/debian-systemd/docker-compose.yaml exec tedge {{args}}

# Start a shell on the child device
shell-child *args='bash':
    docker compose -f images/debian-systemd/docker-compose.yaml exec child01 {{args}}

# Show logs of the main device
logs *args='':
    docker compose -f images/debian-systemd/docker-compose.yaml exec tedge journalctl -f -u "c8y-*" -u "tedge-*" {{args}}

# Show child device logs
logs-child child='child01' *args='':
    docker compose -f images/debian-systemd/docker-compose.yaml logs {{child}} -f {{args}}

# Install python virtual environment
venv:
  [ -d .venv ] || python3 -m venv .venv
  ./.venv/bin/pip3 install -r tests/requirements.txt

# Run tests
test *ARGS:
  ./.venv/bin/python3 -m robot.run --outputdir output {{ARGS}} tests

# Cleanup device and all it's dependencies
cleanup DEVICE_ID $CI="true":
    echo "Removing device and child devices (including certificates)"
    c8y devicemanagement certificates list -n --tenant "$(c8y currenttenant get --select name --output csv)" --filter "name eq {{DEVICE_ID}}" --pageSize 2000 | c8y devicemanagement certificates delete --tenant "$(c8y currenttenant get --select name --output csv)"
    c8y inventory find -n --owner "device_{{DEVICE_ID}}" -p 100 | c8y inventory delete
    c8y users delete -n --id "device_{{DEVICE_ID}}" --tenant "$(c8y currenttenant get --select name --output csv)" --silentStatusCodes 404 --silentExit
