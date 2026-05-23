fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac setup

```sh
[bundle exec] fastlane mac setup
```

One-time: register the bundle ID + create the App Store Connect app record

### mac certs

```sh
[bundle exec] fastlane mac certs
```

Create/fetch the Apple Distribution cert and Mac App Store profile

### mac package

```sh
[bundle exec] fastlane mac package
```

Build + sign the .app and produce a signed .pkg for the App Store

### mac upload

```sh
[bundle exec] fastlane mac upload
```

Upload the signed .pkg to App Store Connect

### mac verify

```sh
[bundle exec] fastlane mac verify
```

Validate the signed .pkg against App Store Connect (no upload)

### mac diagnose

```sh
[bundle exec] fastlane mac diagnose
```

Deep server-side diagnostic: app versions, prerelease versions, builds

### mac deliver_metadata

```sh
[bundle exec] fastlane mac deliver_metadata
```

Push App Store listing metadata + screenshots (no build upload)

### mac release

```sh
[bundle exec] fastlane mac release
```

Full release: certs → package → upload

### mac status

```sh
[bundle exec] fastlane mac status
```

Show recent builds + their App Store Connect processing state

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
