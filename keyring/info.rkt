#lang info

(define name "keyring")
(define collection "keyring")
(define version "0.10")
(define deps '("base" "keyring-lib"))
(define implies '("keyring-lib"))
(define build-deps '("base" "keyring-lib" "racket-doc" "scribble-lib"))
(define scribblings '(["scribblings/keyring.scrbl" ()]))
(define pkg-authors '(samdphillips@gmail.com))
(define license 'Apache-2.0)
