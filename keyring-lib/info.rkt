#lang info

(define name "keyring-lib")
(define collection "keyring")
(define version "0.10")
(define deps '("base"))
(define build-deps '("base" "rackunit-lib"))
(define pkg-authors '(samdphillips@gmail.com))
(define license 'Apache-2.0)

(define raco-commands
  '(["keyring" (submod keyring/cli main) "access keyring at the command line" 5]))
