# tedge-demo-container
thin-edge.io demo container setup to showcase thin-edge.io and all its features

🚧 Work in progress 🚧

## Pre-requisites

The following pre-requisites are required before you can get started:

* docker
* docker compose v2 (e.g. not the python one ;))

## Getting started locally

First you may need to install [just](https://just.systems/man/en/chapter_1.html) as it is used as the task runner.

1. Create the `.env` template file

    ```sh
    just create-env
    ```

    Fill in the values for each of the environment variables in the [.env](./.env) file.

2. Start the docker compose project

    ```sh
    just up
    ```

3. Bootstrap the main device (don't worry you only have to do this once)

    ```sh
    just bootstrap
    ```

    You will be prompted for the required details. You can hit `<enter>` to accept the default values.

4. Click on the device link shown on your console

5. That's it 🚀

## What is included?

The following features are covered by the demo.

**Main device**

* [x] mqtt-logger (to better understand what messages are going in and out)
* [ ] Alarms?
* [x] Events
    * [x] On boot-up service: sends an event on startup
* [x] Measurements (via collectd)
* [ ] Services
    * [x] tedge services
    * [ ] Monit?
* [ ] Software management
    * [x] apt
    * [ ] container (docker, docker-compose)
* [x] Shell
* [x] Remote Access
    * [x] SSH
* [x] Log management
    * [x] log files
* [x] Configuration management
* [x] Telemetry
    * [x] Collectd

**Child device**

* [x] Firmware management
    * [x] Sending events before and after the operation transition are being delayed and sent at once
* [x] Configuration management
* [x] Measurements
* [x] Services

## TODO

* Support restart command (this may require systemd-shutdown). 
