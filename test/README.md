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
