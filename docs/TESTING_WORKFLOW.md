# Testing GitHub workflow

The GitHub workflow can be tested locally with the help of [act](https://github.com/nektos/act).

```sh
act workflow_dispatch --input VERSION=1.0.0 -s GITHUB_TOKEN=$(gh auth token)
```

Or if you are having problems detecting the correct platform, you can manually specify the platform architecture:

```sh
act workflow_dispatch --input VERSION=1.0.0 -s GITHUB_TOKEN=$(gh auth token) --container-architecture linux/arm64
```

## Push

```
act push -s GITHUB_TOKEN=$(gh auth token)
```

## Tests

The test workflow needs to be run using `linux/amd64` containers as the `setup-python` action only supports the amd64 platform.

```sh
act push -j test -s GITHUB_TOKEN=$(gh auth token) --container-architecture linux/amd64 --secret-file .env --artifact-server-path ./tmp
```

## FAQ

### Error: Is the docker daemon running?

If you are using colima on MacOS, then you might need to set the `DOCKER_HOST` environment variable before running the workflow.

```sh
export DOCKER_HOST=unix://$HOME/.colima/default/docker.sock
```
