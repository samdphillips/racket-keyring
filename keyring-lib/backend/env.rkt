#lang racket/base

(provide make-keyring)

(require keyring/interface)

(define (build-env-key keyring service-name username)
  (define-syntax-rule (keypart s)
    (if (zero? (string-length s)) "" (string-append "_" s)))
  (define key
    (string->bytes/utf-8
      (string-append
        (env-keyring-base-key keyring)
        (keypart service-name)
        (keypart username))))
  (log-keyring-debug "using env key ~s to lookup secret" key)
  key)

(define (env-get-password keyring service-name username)
  (environment-variables-ref
    (current-environment-variables)
    (build-env-key keyring service-name username)))

(define (env-set-password! keyring service-name username password)
  (environment-variables-set!
    (current-environment-variables)
    (build-env-key keyring service-name username)
    password))

(define (env-delete-password! keyring service-name username)
  (environment-variables-set!
    (current-environment-variables)
    (build-env-key keyring service-name username)
    #f))

(struct env-keyring [base-key]
  #:methods
  gen:keyring
  [(define get-password env-get-password)
   (define set-password! env-set-password!)
   (define delete-password! env-delete-password!)])

(define (make-keyring #:prefix base-env-key)
  (env-keyring base-env-key))

(module test racket/base
  (require keyring
           rackunit
           syntax/parse/define)
  (define-simple-macro (with-keyring s:str body ...+)
    (parameterize ([default-keyring (make-keyring-from-string s)])
      body ...))

  (parameterize ([current-environment-variables
                   (make-environment-variables
                     #"SECRET_foo_bar1" #"baz1"
                     #"SECRET_foo_bar2" #"baz2"
                     #"SECRET_bar" #"baz")])
    (with-keyring "env://?prefix=SECRET"
      (check-equal? (get-password "foo" "bar1") #"baz1")
      (check-false  (get-password "foo" "oops"))

      (check-equal? (get-password "" "bar") #"baz")

      (set-password! "foo" "bar3" #"baz3")
      (check-equal? (get-password "foo" "bar3") #"baz3")

      (delete-password! "foo" "bar3")
      (check-false  (get-password "foo" "bar3")))))
