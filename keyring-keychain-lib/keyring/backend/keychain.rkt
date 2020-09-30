#lang racket/base

(provide make-keyring)

(require keyring/interface
         keyring/backend/private/keychain)

(struct keychain-keyring [kc]
  #:methods gen:keyring
  [])

(define (make-keyring #:path [path #f])
  (define kc
    (if path
        (sec-keychain-open path)
        (sec-keychain-copy-default)))
  (keychain-keyring kc))

