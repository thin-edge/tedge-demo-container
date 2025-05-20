# tedge-demo-container

thin-edge.io demo container setup to showcase thin-edge.io and all its features

## Pre-requisites

The following pre-requisites are required before you can get started:

* docker
* docker compose v2 (not the python one)

Check out the list of [known working setups](./docs/USER_GUIDE.md#known-working-environments) to see what software you can use for your Operating Systemd to meet the pre-requisites.

## Starting a demo container using go-c8y-cli

If you're a Cumulocity user, then you can use the [Cumulocity CLI tool, go-c8y-cli](https://goc8ycli.netlify.app/) and the thin-edge.io extension for it ([c8y-tedge](https://github.com/thin-edge/c8y-tedge)), to quickly launch demo containers without having to checkout this project.

First, you'll need to install go-c8y-cli (in addition to having docker and docker compose already installed):

* [Install go-c8y-cli](https://goc8ycli.netlify.app/docs/installation/)

Then, install the [c8y-tedge](https://github.com/thin-edge/c8y-tedge) extension:

```sh
c8y extensions install thin-edge/c8y-tedge

# or update it to the latest version
c8y extensions update tedge
```

Launch a new container demo using (note: this will also open your web browser to the device after it is onboarded):

```sh
c8y tedge demo start mydemo01
```

Like most cli commands, you can view extra options by looking at the help, using the `--help` flag on any given command.

```sh
c8y tedge demo start --help
```

Afterwards, you can stop the demo and delete the related devices in the cloud using:

```sh
c8y tedge demo stop
```

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
    docker compose exec tedge bootstrap.sh
    ```

4. Click on the link to your tedge device which is shown on the console


Check out the [USER GUIDE](./docs/USER_GUIDE.md) for more details on other commands that can be run.

**Note**

The tedge container has the following default SSH user which can be used with the SSH protocol of the Cumulocity IoT Cloud Remote Access (CRA) feature.

|Property|Value|
|--------|-----|
|SSH User|iotadmin|
|SSH Password|iotadmin|

## Building the project yourself

The project also includes another docker-compose file to build the project locally. This allows you to manually tweak any of the container images to add/remove things as you see fit.

After you have cloned the project you still need to install, [just](https://github.com/casey/just). `just` is used as the project's task runner to simplify the commands required during development. Check out their [installation instructions](https://just.systems/man/en/chapter_1.html) to see how to install it on your machine.

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

    Alternatively, if you're a [go-c8y-cli](https://goc8ycli.netlify.app/) user, and have the [c8y-tedge](https://github.com/thin-edge/c8y-tedge) extension installed, then you can bootstrap the device using:

    ```sh
    just bootstrap-c8y
    ```

4. Click on the device link shown on your console

5. That's it 🚀

## Running Tests

Integration tests are included in the demo to ensure that everything is working as it should. The tests can be run using the following steps:

1. Edit the `.env` file and add the following environment variables

    ```sh
    DEVICE_ID=tedge_unique_name_abcdef
    C8Y_BASEURL=example.tenant.c8y.io
    C8Y_USER=myuser@example.com
    C8Y_PASSWORD="your_password"
    ```

2. Start the demo and bootstrap it

    ```sh
    just up
    just bootstrap --no-prompt
    ```

3. Run the tests

    ```sh
    just test
    ```

## What is included?

The following features are covered by the demo.

**Main device**

* [x] Availability Monitoring
* [x] Configuration management
* [x] mqtt-logger (to better understand what messages are going in and out)
* [x] Device reboot
* [x] Device Profile
* [x] Firmware Update (simulated)
* [x] Log management
    * [x] log files
* [x] Remote Access
    * [x] SSH
* [x] Services
    * [x] tedge services
* [x] Shell
* [x] Software management
    * [x] apt
    * [x] container (docker, docker-compose)
* [x] Telemetry
    * [x] Measurements (via collectd)
    * [x] Events
        * [x] On boot-up service: sends an event on startup

**Child devices**

* [x] Availability Monitoring
* [x] Configuration management
* [x] Device reboot
* [x] Device Profile
* [x] Firmware Update (simulated)
* [x] Log management
    * [x] log files
* [x] Services
    * [x] tedge services
* [x] Shell
* [x] Software management
    * [x] apk (Alpine based image)
    * [x] apt (Debian based image)

## Known issues

There are currently no known issues.
