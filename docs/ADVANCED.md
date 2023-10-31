# Advanced examples

## Single process containers

An additional single-process container are also provided to show how thin-edge.io can operate in a pure container environment.

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
