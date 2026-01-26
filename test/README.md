This directory contains both scripts used in the testing of reference architectures along with a Go Module that has helper functions useful for terratest based test functions.

Adding the test helper library is done like:

```
require (
	github.com/digitalocean/scale-with-simplicity/test v0.0.0
	github.com/gruntwork-io/terratest v0.49.0
	github.com/stretchr/testify v1.10.0
)

replace github.com/digitalocean/scale-with-simplicity/test => ../../../test
```

Where the directory used in the `replace` directive is a relative path between the `test` directory in the Reference Architecture directory and the `test` directory in the repo root.

## Container

The Dockerfile is used to build the container used by the GitHub actions pipeline to run tests. Building and pushing this container is done manually.

The build requires a `GITHUB_TOKEN` with `repo` scope to download the [deepsix](https://github.com/DO-Solutions/deepsix) binary from a private release.

```shell
# ensure you are using a token for the SWS team
$ doctl account get
User Email                  Team                          Droplet Limit    Email Verified    User UUID                               Status
example@digitalocean.com    scale-with-simplicity-test    100              true              34f56ebe-3fa6-4ff3-883e-000000000000    active
# login to push the container
$ doctl registry login
Logging Docker in to registry.digitalocean.com
Notice: Login valid for 30 days. Use the --expiry-seconds flag to set a shorter expiration or --never-expire for no expiration.
# Build using latest tag (GITHUB_TOKEN must have repo scope for DO-Solutions/deepsix)
$ docker build --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
    -t registry.digitalocean.com/scale-with-simplicity-test/terraform-test:latest .
# push container
$ docker push registry.digitalocean.com/scale-with-simplicity-test/terraform-test:latest
```

### Recreating the DOCR Registry

The DOCR registry `scale-with-simplicity-test` is protected from deletion by deepsix via `.deepsix.yaml`. If you ever need to recreate it manually:

```shell
doctl registry create scale-with-simplicity-test
```
