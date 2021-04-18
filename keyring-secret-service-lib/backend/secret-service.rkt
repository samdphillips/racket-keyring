#lang racket/base

(provide make-keyring)

(require racket/class
         keyring/backend/private/secret-service)

(define (make-keyring
         #:path [path "/org/freedesktop/secrets/collection/login"])
  (new secret-service-keyring% [secret-collection-path path]))

