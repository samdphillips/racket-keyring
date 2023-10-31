# keyring: a library for uniformly accessing secrets

The keyring library is a library to access various password stores in a uniform
way.  It is based loosely on the [Python keyring
library](https://github.com/jaraco/keyring)

## Documentation
- [Release Documentation](https://docs.racket-lang.org/keyring/index.html)
- [Development Documentation](https://samdphillips.github.io/racket-keyring)

## keyring-keychain-lib
### Testing
To test the Mac backend with a different keychain than your default login
keychain follow these instructions.

1. Open the Keychain Access application and in the "File" menu choose "New Keychain...".
   Name the new keychain `test.keychain` and place it in your home directory.
2. Run the following to run the test suite.
   ```
   MACOSX_TEST_KEYCHAIN=$HOME/test.keychain raco test -s keychain-test -p keyring-keychain-lib
   ```

# Changelog
## 0.11.0

Release date: 2023/10/31

* Move tests into separate packages.

* Reorganize the backends around `prop:keyring`

* Clean up error message formatting.

* Log errors from raise procedures.

* Add `null` backend as default when the `KEYRING` environment variable
  is not set.

## 0.10.1

Release date: 2022/11/09

* Add license metadata to packages.

* Regular Github Actions testing setup.

* Logging changes.

## 0.10.0

Release date: 2021/04/18

* Code cleanups.

* Logging improvements.

## 0.9.0

Release date: 2021/02/26

* A raco command for accessing the keyrings.

* A backend system that works with classes, generics, or plain structs.

* Implemented Backends

  * Mac OSX Keychain backend

  * Secret Service backend

  * environment variable backend

  * get-pass backend

* Environment based configuration
