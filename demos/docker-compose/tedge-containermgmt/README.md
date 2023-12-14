## Getting started

:warning: Don't try these instructions just yet as they use an unreleased go-c8y-cli plugin.

1. Download the docker compose file from the repository

    ```sh
    curl -LSs https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/tedge-containermgmt/docker-compose.yaml > docker-compose.yaml
    ```

    Or alternatively you can download it using `wget`

    ```sh
    wget https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/tedge-containermgmt/docker-compose.yaml
    ```

2. Set the environment variables

    This is most can be done using the [go-c8y-cli](https://goc8ycli.netlify.app/), via the `set-session` command which sets the required environment variables.

    Or you can set a `.env` file at the same level as the docker-compose.yaml file you're using:

    **file: .env**

    ```sh
    C8Y_DOMAIN=example.eu-latest.cumulocity.com
    ```

3. Start the docker-compose project (in the background)

    ```sh
    docker compose up -d
    ```

4. In a new console, set the same c8y session, then bootstrap the device

    ```sh
    c8y tedge bootstrap $(docker compose ps --format "{{.Name}}") example002
    ```

    Or you can use the bootstrapping container's name which is printed in the console in the previous step if you having problems running the command above.

    For example, if the container's name started by the docker compose is `alpine-bootstrap-1`, and you want to use the device-id `example001`, the command would be:

    ```sh
    c8y tedge bootstrap alpine-bootstrap-1 example001
    ```

5. Start the remaining services

    ```sh
    docker compose up -d
    ```

## Shutdown and retain volumes

If you want to retain the certificate the data stored in volumes, then run the following:

```sh
docker compose down
```

## Shutdown and delete volumes

If you want to shutdown all of the containers and remove all of the persisted data (including the device certificates), then run the following:

```sh
docker compose down -v
```
