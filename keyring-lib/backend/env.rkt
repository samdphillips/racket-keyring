#lang racket/base

#|
   Copyright 2020-2021 Sam Phillips <samdphillips@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
|#

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
           rackunit)
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
