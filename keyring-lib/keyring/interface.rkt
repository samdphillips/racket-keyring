#lang racket/base

(require racket/contract
         "private/interface.rkt")

(provide
  keyring<%>
  prop:keyring
  gen:keyring

  keyring?
  (contract-out
    [get-password    (-> keyring? string? string? bytes?)]
    [set-password    (-> keyring? string? string? bytes? any)]
    [delete-password (-> keyring? string? string? any)]))

