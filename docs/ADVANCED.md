# Advanced examples

## Single process containers

An additional single-process container are also provided to show how thin-edge.io can operate in a pure container environment.

It must be noted that running in a container has a different purpose than the systemd example as single process containers are meant to be more restrictive and in general "read-only". Therefore some of the features offered by the systemd demo are not applicable for the single process container as they true to solve different use-cases.

The following features are covered by the demo.

**main/child device**

* [x] Configuration management
* [x] Device reboot
* [ ] Events
    * [ ] On boot-up service: sends an event on startup
* [x] Log management
    * [x] log files
* [ ] Measurements
* [ ] Remote Access
    * [ ] SSH
* [x] Services
    * [x] tedge services
* [x] Shell
* [x] Software management
    * [x] apk (Only supports software list unless if the container is run as "root")
    * [ ] container (docker, docker-compose)

**Child devices**

* [x] Configuration management
* [x] Device reboot
* [ ] Events
    * [ ] On boot-up service: sends an event on startup
* [x] Log management
    * [x] log files
* [ ] Measurements
* [ ] Remote Access
    * [ ] SSH
* [x] Services
    * [x] tedge services
* [ ] Shell
* [x] Software management
    * [x] apk (Only supports software list unless if the container is run as "root")
    * [ ] container (docker, docker-compose)

### Start

1. Start up the alpine-s6 image

    ```
    just IMAGE=alpine-s6 up
    ```

    If you are having problems with the build then you can build without using any caching with the following command:

    ```
    just IMAGE=alpine-s6 up-no-cache
    ```

2. Bootstrap the device

    ```
    just IMAGE=alpine-s6 bootstrap
    ```

3. Follow the instructions printed on the console to go to your device in Cumulocity IoT

### Stop

The setup can be stopped by running the following command:

```
just IMAGE=alpine-s6 down
```

Or if you want to remove everything including the device certificate, then run the following command instead:

```
just IMAGE=alpine-s6 down-all
```
