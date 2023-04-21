# tedge-demo-container

thin-edge.io demo container setup to showcase thin-edge.io and all its features

🚧 Work in progress 🚧

## Pre-requisites

The following pre-requisites are required before you can get started:

* docker
* docker compose v2 (not the python one)

## Getting started

1. Download the docker compose file from the repository

    ```sh
    curl -LSs https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/device/docker-compose.yaml > docker-compose.yaml
    ```

    Or alternatively you can download it using `wget`

    ```sh
    wget https://raw.githubusercontent.com/thin-edge/tedge-demo-container/main/demos/docker-compose/device/docker-compose.yaml
    ```

2. Start the docker-compose project (in the background)

    ```sh
    docker compose up -d
    ```

3. Bootstrap the device

    ```sh
    docker compose exec tedge ./bootstrap.sh
    ```

4. Click on the link to your tedge device which is shown on the console


## Building the project yourself

The project also includes another docker-compose file to build the project locally. This allows you to manually tweak any of the container images to add/remove things as you see fit.

After you have cloned the project you still need to install, [just](https://github.com/casey/just). `just` is used as the project's task runner to simplify the commands required during development. Checkout their [installation instructions](https://just.systems/man/en/chapter_1.html) to see how to install it on your machine.

Once you have [just](https://github.com/casey/just) installed, you can proceed with the following instructions:

1. Create the `.env` template file

    ```sh
    just create-env
    ```

    Fill in the values for each of the environment variables in the [.env](./.env) file. Whilst the settings in the `.env` file are not mandatory, it does allow you to set sensible defaults for your setup so that you don't have to enter your username or Cumulocity URL multiple times during the bootstrapping phase.

2. Start the docker compose project (this will also build the containers)

    ```sh
    just up
    ```

3. Bootstrap the main device (don't worry you only have to do this once)

    ```sh
    just bootstrap
    ```

    You will be prompted for the required details. You can hit `<enter>` to accept the default values. The default values are provided via the `.env` file from the first step.

4. Click on the device link shown on your console

5. That's it 🚀

## What is included?

The following features are covered by the demo.

**Main device**

* [x] Configuration management
* [x] mqtt-logger (to better understand what messages are going in and out)
* [x] Device reboot
* [x] Events
    * [x] On boot-up service: sends an event on startup
* [x] Log management
    * [x] log files
* [x] Measurements (via collectd)
* [x] Remote Access
    * [x] SSH
* [ ] Services
    * [x] tedge services
* [x] Shell
* [x] Software management
    * [x] apt
    * [x] container (docker, docker-compose)
* [x] Telemetry
    * [x] Collectd

**Child devices**

* [x] Configuration management
* [x] Firmware management
    * [x] Sending events before and after the operation transition are being delayed and sent at once
* [x] Measurements
* [x] Services
