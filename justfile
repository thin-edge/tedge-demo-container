
# Build the docker images
[private]
build:
  docker build -t "tedge-demo-container" -f images/debian-systemd/debian-systemd.dockerfile images

# Create .env file from the template
create-env:
    test -f .env || cp env.template .env

# Start the demo
up args='':
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
