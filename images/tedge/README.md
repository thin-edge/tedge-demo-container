# Bootstrapping

The following options to bootstrap the containers is being considered.

## Option 1: Bootstrapping container at runtime

1. Start containers

    ```sh
    docker compose -f images/alpine/docker-compose.yaml up
    ```

2. On the first startup, you will have to bootstrap the connection to c8y

    ```sh
    c8y tedge bootstrap alpine-bootstrap-1 <device-id>
    ```

**Pros**

* Follows similar bootstrapping process of a real device

**Cons**

* Requires manual interaction before you can create
* Additional dependencies required (e.g. go-c8y-cli)...however this does add a richer user experience


## Option 2: Bootstrapping before starting containers

1. Create certificates (and upload them) using mounted volumes
2. Start containers (reusing the volumes created in step 1)
