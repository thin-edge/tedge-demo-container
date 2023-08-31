## Troubleshooting

### Building docker images

#### MacOS using colima

If you are building on a MacOS aarch64 machine (M1/M2 etc.) and using colima, then you may need to configure docker buildx using the following command (as recommended via [colima #764](https://github.com/abiosoft/colima/issues/764))

```sh
docker buildx create \
    --name fixed_builder \
    --driver-opt 'image=moby/buildkit:v0.12.1-rootless' \
    --bootstrap --use
```

Then you can build the container images using:

```sh
just build
```
