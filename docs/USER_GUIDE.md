# User guide

## Common actions

This section contains commonly used commands used to interact with the demo.

**Preface**

All `docker compose` commands should be run from the folder where the `docker-compose.yaml` file is located. Otherwise you will need to use the `-f path/to/my/docker-compose.yaml` argument to all of the documented `docker compose` commands.

### Updating the containers to the latest version

If you are using the default `latest` tag inside the docker compose project, then you can update to the latest version using:

```sh
docker compose up -d
```

### Stopping the demo

The demo can be stopped by using:

```sh
docker compose down
```

### Removing everything

Once you are done with the demo, you can clean up all the resources (including the volumes) using:

```sh
docker compose down -v
```

### Get logs

**Main device**

Since the main device is running the services under systemd, you will need to execute a command inside the container.

```sh
docker compose exec tedge journalctl -f -u "c8y-*" -u "tedge-*" -n 100
```

Or you can get a single service using:

```sh
docker compose exec tedge journalctl -f -u "tedge-mapper-c8y" -n 100
```

**Child devices**

The child devices are single process containers so you can use the standard `docker compose logs` command.

```sh
docker compose logs child01 -f --tail 100
docker compose logs child02 -f --tail 100
```
