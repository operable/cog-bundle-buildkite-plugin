# cog-bundle-buildkite-plugin
Buildkite plugin for testing Cog Bundles in a Cog Server

[![Build status](https://badge.buildkite.com/be17ba01fa3d366cea89f2f28bce33901ed8220d93943bb8a4.svg?branch=master)](https://buildkite.com/operable/cog-bundle-buildkite-plugin)

**NOTE: This plugin is a work-in-progress. We use it internally at Operable to test our bundles. However, it may still blow up your systems; use at your own discretion!**

This plugin provides the following actions:
* `build`: Build a Docker image based on a bundle's `config.yaml` file
* `test`: Install the bundle in a real Cog server and perform integration tests against it.

Note that this plugin currently supports testing of Docker-packaged bundles only; "native" command bundles are not supported.

Usage examples are given below, but also see this plugin's [pipeline configuration](.buildkite/pipeline.sh) for other examples.

# `build`
Build a Docker image for the bundle, optionally pushing it to your previously-configured Docker repository. When successful, the image tag is added to the pipeline's meta-data under the key `"operable-bundle-testing-image"` and can be retrieved later via

```sh
buildkite-agent meta-data get "operable-bundle-testing-image")
```

## Keys
* `build`: the name of the bundle configuration file to use.
  Typically this will be `config.yaml`. At the moment, this *must* be provided; sorry about that!

  If a `tag` key (see below) is not provided, the generated image will be tagged according to the values provided in the configuration file.

* `dockerfile`: The path to the Dockerfile used to generate the bundle. This is optional, and defaults to   `"Dockerfile"` if not provided by the user.

  The directory the file is in will serve as the build context.

* `tag`: The full image tag you wish to use for the image. If not provided, the value will be generated from the configuration file specified for `build` (see above).

* `push`: Should the image be pushed to its repository? Defaults to true.

## Examples

```yaml
- steps:
  - label: Build a Cog Bundle image
    plugins:
      - operable/cog-bundle:
          build: config.yaml

  - label: Build a Cog Bundle image with a custom Dockerfile
     plugins:
       - operable/cog-bundle:
           build: config.yaml
           dockerfile: Dockerfile.cog

  - label: Build a Cog Bundle Image with custom tag
    plugins:
      - operable/cog-bundle:
          build: config.yaml
          tag: mycompany/my-bundle:1.0.0-${BUILDKITE_BUILD_NUMBER}-${BUILDKITE_COMMIT}

  - label: Build image, but don't push
    plugins:
      - operable/cog-bundle:
          build: config.yaml
          push: "false" # TODO: Shouldn't need to be quoted
```

# `test`

Load the bundle into a live Cog server and run integration tests. Tests are specified declaratively in a YAML file.

## Keys
* `test`: the path to the integration test specification YAML file. Must be provided.

* `cog-version`: The Git SHA, branch, or tag for the [Cog repository](https://github.com/operable/cog) from which the base `docker-compose` files will be downloaded. These define the Cog system that is set up for the tests. Defaults to `"master"`, if not provided.

* `config`: The path to the bundle configuration file. This is the same value as provided for the `build` key above, but here, we can default to `config.yaml`. The plugin generates a new version of this configuration file, substituting the Docker image generated by the `build` action.

## Examples

```yaml
- steps:

  - label: Test against Cog
    plugins:
      - operable/cog-bundle#${BUILDKITE_COMMIT}:
          test: integration.yaml
          cog-version: "v1.0.0-beta.1"
          config: config.yaml
```

Note: by dynamically generating your pipeline definitions, you can loop over a list of several different Cog versions, thereby testing your bundle against each of them.

## Integration Test specification

To test bundle commands, we read a YAML file that specifies the test scenarios. Internally, this is used to dynamically generate and run an RSpec suite. Note that bundles do not need to be build with [cog-rb](https://github.com/operable/cog-rb), or even written in Ruby, in order to use this plugin for testing.

Currently the integration test format works for bundles with no permissions, and without any dynamic configuration. Support for these scenarios will be added soon.

An example will illustrate the format:

```yaml
"format:list":
  - desc: can extract fields
    pipeline: format:list name
    input:
      - name: geddy
      - name: neil
      - name: alex
    output:
      - body: alex, geddy, neil
"format:fields":
  - desc: returns the fields of an object
    pipeline: format:fields
    input:
      x: 1
      y: 2
      z: 3
    output:
      - fields: [ x, y, z ]
```

The overall structure is that of a map, whose keys name overall test suites, and whose values describe lists of test cases. Generally the name of the suite can just be the name of the command being tested, but it can be more descriptive if you choose.

Each test case has four fields:

* `desc`: A description of the test case
* `pipeline`: The chat command to actually be executed
* `input`: any input provided to the pipeline. This should be a map
* `output`: the expected output of the pipeline

Internally, each test case creates a Cog trigger for the pipeline in question and then executes that trigger to carry out the test. The tests do not interact with a chat provider during execution. The output is the raw pipeline output; no templating of results is performed at all.

## Environment Variables

* `INTERFACE`: Specify a particular network interface to use to obtain an IP address for the Cog server. Defaults to `eth0`.
