#lang racket/base

(require racket/contract
         "private/interface.rkt")

(provide
  keyring<%>
  prop:keyring
  gen:keyring

  keyring?
  (contract-out
    [get-password     (-> keyring? string? string? (or/c #f bytes?))]
    [set-password!    (-> keyring? string? string? bytes? any)]
    [delete-password! (-> keyring? string? string? any)])

  keyring-logger
  log-keyring-fatal
  log-keyring-error
  log-keyring-warning
  log-keyring-info
  log-keyring-debug)

(define-logger keyring)

