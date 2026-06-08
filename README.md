# Portable code-server

This repository provides a portable `code-server` setup that keeps the code-server binary, configuration, extensions, user data, cache, temporary files, and projects inside one movable folder.

The goal is to make this folder self-contained, so you can move it to another path or mount it into a Docker container without losing your code-server environment.

## Folder layout

```text
code-server/
├── .gitignore
├── README.md
├── setup-folders.sh
├── install-or-update-code-server.sh
├── run-code-server.sh
├── code-server/          # downloaded automatically; ignored by Git
├── config/
│   └── config.yaml       # generated automatically; ignored by Git
├── data/                 # runtime data; ignored by Git
│   ├── user-data/
│   ├── extensions/
│   ├── xdg-config/
│   ├── xdg-data/
│   ├── xdg-cache/
│   └── tmp/
└── projects/             # default workspace folder; ignored by Git
```

## What each script does

### `setup-folders.sh`

Creates the portable folder structure and generates a default config file at:

```text
config/config.yaml
```

The generated config uses:

```yaml
bind-addr: 127.0.0.1:8080
auth: password
password: my-password
cert: false
```

A random password is generated automatically when the config file is first created.

### `install-or-update-code-server.sh`

Checks whether `code-server/bin/code-server` exists.

If code-server is missing, it:

1. Detects the system architecture.
2. Downloads the latest matching code-server release from GitHub.
3. Extracts it into `code-server/`.
4. Removes the downloaded `.tar.gz` file.

On every run, it also checks whether a newer code-server release is available.

If an update exists, it asks:

```text
Update code-server now? [y/N]
```

Pressing Enter defaults to `no`.

### `run-code-server.sh`

This is the main launcher.

It:

1. Runs `setup-folders.sh`.
2. Runs `install-or-update-code-server.sh`.
3. Sets portable environment variables.
4. Starts code-server with portable user data and extensions folders.

By default, it opens:

```text
projects/
```

## Quick start

From inside the parent directory of `code-server`:

```bash
cd code-server
bash run-code-server.sh
```

Then open code-server in your browser at:

```text
http://localhost:8080
```

If you are running on a remote server, use SSH port forwarding:

```bash
ssh -N -L 8080:127.0.0.1:8080 user@remote-server
```

Then open locally:

```text
http://localhost:8080
```

## Running in Docker

When running inside Docker, code-server must listen on `0.0.0.0:8080` inside the container. The generated config already does this.

Example:

```bash
docker run -it --rm \
  -p 127.0.0.1:8080:8080 \
  -v "$PWD/code-server:/code-server" \
  your-image \
  bash /code-server/run-code-server.sh
```

```bash
bash /code-server/run-code-server.sh --bind-addr 0.0.0.0:8080
```

Then open:

```text
http://localhost:8080
```

For a remote Docker host, SSH forward the host port:

```bash
ssh -N -L 8080:127.0.0.1:8080 user@remote-server
```

## Passing arguments to code-server

Any arguments passed to `run-code-server.sh` are forwarded to code-server.

Open a specific folder:

```bash
bash run-code-server.sh /workspace/my-project
```

## Update behavior

By default, every run checks GitHub for the latest code-server release.

If an update is available, the script asks before updating:

```text
Update code-server now? [y/N]
```

The default is `no`.

Skip the update check:

```bash
CODE_SERVER_SKIP_UPDATE_CHECK=1 bash run-code-server.sh
```

Automatically update without asking:

```bash
CODE_SERVER_AUTO_UPDATE=1 bash run-code-server.sh
```

## Security notes

The generated `config/config.yaml` contains the code-server password, so it should not be committed to Git.

The recommended Docker port mapping is:

```bash
-p 127.0.0.1:8080:8080
```

This exposes code-server only on the Docker host's loopback interface. For remote access, use SSH forwarding instead of exposing the port publicly.

## Troubleshooting

### `docker ps` does not show any ports

If you used `docker run -P` and no ports appear, the image probably does not declare `EXPOSE 8080`.

Use explicit port mapping instead:

```bash
-p 127.0.0.1:8080:8080
```

### SSH shows `channel 3: open failed: connect failed: Connection refused`

This means SSH forwarding reached the remote server, but nothing is listening on the target port.

Check on the remote server:

```bash
docker ps
curl -I http://127.0.0.1:8080
```

Also make sure code-server is bound to `0.0.0.0:8080` inside Docker.

### code-server starts but app ports are not reachable

You usually only need to publish the code-server port. For apps started inside code-server, use code-server's built-in proxy:

```text
http://localhost:8080/proxy/3000/
```

Replace `3000` with the port your app is using.

## Requirements

The installer script expects these commands to be available:

```text
curl
tar
python3
uname
awk
sed
find
mktemp
```

A Debian or Ubuntu based Docker image is recommended for the standalone code-server release.
