# keyring: a library for uniformly accessing secrets

The keyring library is a library to access various password stores in a uniform
way.  It is based loosely on the [Python keyring
library](https://github.com/jaraco/keyring)

## Documentation
- [Release Documentation](https://docs.racket-lang.org/keyring/index.html)
- [Development Documentation](https://samdphillips.github.io/racket-keyring)

## keyring-keychain-lib
### Testing
1. Open the Keychain Access application and in the "File" menu choose "New Keychain...".
2. Run the following to run the test suite.
   ```
   MACOSX_TEST_KEYCHAIN=$HOME/test.keychain raco test -s keychain-test -p keyring-keychain-lib
   ```

