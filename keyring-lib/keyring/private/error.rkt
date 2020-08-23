#lang racket/base

(provide
  (struct-out exn:fail:keyring)
  (struct-out exn:fail:keyring:backend)
  (struct-out exn:fail:keyring:backend:load))

(struct exn:fail:keyring              exn:fail         [])
(struct exn:fail:keyring:backend      exn:fail:keyring [])
(struct exn:fail:keyring:backend:load exn:fail:keyring [])

