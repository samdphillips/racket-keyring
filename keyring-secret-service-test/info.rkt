#lang info

(define name "keyring-secret-service-test")
(define collection "keyring")
(define version "0.11")
(define deps '("base" "keyring-secret-service-lib"))
(define build-deps '("base" "dbus" "rackunit-lib"))
(define pkg-authors '(samdphillips@gmail.com))
(define license 'Apache-2.0)
