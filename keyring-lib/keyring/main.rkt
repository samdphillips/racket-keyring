#lang racket/base

(provide keyring?
         get-password
         set-password
         delete-password
         make-keyring-from-string
         default-keyring

         exn:fail:keyring?
         exn:fail:keyring:backend?
         exn:fail:keyring:backend:load?)

(require racket/exn

         keyring/interface
         (rename-in keyring/interface
                    [get-password $get-password]
                    [set-password $set-password]
                    [delete-password $delete-password])
         keyring/private/error
         keyring/private/backends)

(define (maybe-initialize-default-keyring)
  (define keyring-spec (getenv "KEYRING"))
  (and keyring-spec
       (with-handlers ([exn:fail?
                         (lambda (e)
                           (log-keyring-error "error initializing keyring from environment")
                           (log-keyring-error "keyring spec: ~s" keyring-spec)
                           (log-keyring-error (exn->string e))
                           #f)])
         (make-keyring-from-string keyring-spec))))

(define default-keyring
  (make-parameter (maybe-initialize-default-keyring)))

(define (check-keyring who keyring)
  (unless (keyring? keyring)
    (raise
      (exn:fail:keyring
        (format "~a: not a keyring: ~a"
                who keyring)
        (current-continuation-marks)))))

(define (get-password service-name
                      username
                      #:keyring [keyring (default-keyring)])
  (check-keyring 'get-password keyring)
  ($get-password keyring service-name username))

(define (set-password service-name
                      username
                      password
                      #:keyring [keyring (default-keyring)])
  (check-keyring 'set-password keyring)
  ($set-password keyring service-name username password))

(define (delete-password service-name
                         username
                         #:keyring [keyring (default-keyring)])
  (check-keyring 'delete-password keyring)
  ($delete-password keyring service-name username))

