# Getting started

## Cumulocity IoT

### Pre-requisites

Before starting the project please install the following dependencies:

* [go-c8y-cli](https://goc8ycli.netlify.app/), and setup the `set-session` shell helper
* Install the go-c8y-cli extension for thin-edge.io

    ```sh
    c8y extension install thin-edge/c8y-tedge
    ```

After you have installed these, then you will also need to setup a go-c8y-cli session.

### Setup

1. Download the docker compose file from the repository

    ```sh
    curl -LSs https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/tedge-containermgmt/docker-compose.yaml > docker-compose.yaml
    ```

    Or alternatively you can download it using `wget`

    ```sh
    wget https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/tedge-containermgmt/docker-compose.yaml
    ```

2. Start the docker-compose project (in the background)

    ```sh
    docker compose up -d
    ```

3. Open a new console, and activate your go-c8y-cli session which points to the Cumulocity IoT Instance you wish to connect the device to

    ```
    set-session
    ```

4. Bootstrap the device

    ```sh
    c8y tedge bootstrap-container bootstrap example001
    ```

    Or you want to use a randomized device name:

    ```sh
    c8y tedge bootstrap-container bootstrap
    ```

5. Explore thin-edge.io from the Cumulocity IoT device management application


### Shutdown and retain volumes

If you want to retain the certificate the data stored in volumes, then run the following:

```sh
docker compose down
```

### Shutdown and delete volumes

If you want to shutdown all of the containers and remove all of the persisted data (including the device certificates), then run the following:

```sh
docker compose down -v
```
