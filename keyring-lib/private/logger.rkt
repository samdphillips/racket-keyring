#lang racket/base

(provide
 keyring-logger
 log-keyring-fatal
 log-keyring-error
 log-keyring-warning
 log-keyring-info
 log-keyring-debug)

(define-logger keyring)

;; XXX: logging wrappers that backends can use to have more consistent messages
