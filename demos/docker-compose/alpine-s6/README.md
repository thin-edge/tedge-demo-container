## Getting started

1. Download the docker compose file from the repository

    ```sh
    curl -LSs https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/alpine-s6/docker-compose.yaml > docker-compose.yaml
    ```

    Or alternatively you can download it using `wget`

    ```sh
    wget https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/alpine-s6/docker-compose.yaml
    ```

2. Set the environment variables

    This is most can be done using the [go-c8y-cli](https://goc8ycli.netlify.app/), via the `set-session` command which sets the required environment variables.

    Or you can set a `.env` file at the same level as the docker-compose.yaml file you're using:

    **file: .env**

    ```sh
    DEVICE_ID=tedge_s6_demo
    C8Y_DOMAIN=example.eu-latest.cumulocity.com
    ```

3. Start the docker-compose project (in the background)

    ```sh
    docker compose up -d
    ```

4. Upload the certificate (from the mosquitto container)

    ```sh
    docker compose exec tedge bootstrap.sh
    ```
