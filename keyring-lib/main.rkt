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

(provide keyring?
         get-password
         set-password!
         delete-password!
         make-keyring-from-string
         default-keyring
         with-keyring

         keyring-error?
         keyring-error-message
         keyring-backend-error?
         keyring-backend-error-name
         keyring-backend-load-error?
         keyring-backend-load-error-name)

(require racket/exn
         (for-syntax racket/base)
         syntax/parse/define

         keyring/interface
         (rename-in keyring/interface
                    [get-password     $get-password]
                    [set-password!    $set-password!]
                    [delete-password! $delete-password!])
         (only-in keyring/private/error
                  keyring-error
                  keyring-error-message)
         keyring/private/backends)

(define (maybe-initialize-default-keyring)
  (define keyring-spec (getenv "KEYRING"))
  (cond
    [keyring-spec
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (log-keyring-error
                         "error initializing keyring from environment")
                        (log-keyring-error
                         "keyring spec: ~s" keyring-spec)
                        (log-keyring-error (exn->string e))
                        #f)])
       (make-keyring-from-string keyring-spec))]
    [else
     (log-keyring-warning
      (string-append "KEYRING environment variable not set. "
                     "No default-keyring will be set up."))
     #f]))

(define default-keyring
  (make-parameter (maybe-initialize-default-keyring)))

(define-syntax-parser with-keyring
  [(_ s:str body ...+)
   #'(parameterize ([default-keyring (make-keyring-from-string s)])
       body ...)]
  [(_ e body ...+)
   #:declare e (expr/c #'keyring?)
   #'(parameterize ([default-keyring e.c]) body ...)])

(define-syntax-rule (log-trace who service-name username)
  (log-keyring-debug "~a: service=~a user=~a" who service-name username))

(define (check-keyring who keyring)
  (unless (keyring? keyring)
    (define msg
      (format "~a: not a keyring: ~a" who keyring))
    (log-keyring-error msg)
    (unless keyring
      (log-keyring-error
       (string-append
        "default-keyring may not have been initialized. "
        "Set KEYRING environment variable before loading the "
        "keyring library or initialize a keyring with "
        "make-keyring-from-string")))
    (raise (keyring-error msg (current-continuation-marks)))))

(define (get-password service-name
                      username
                      #:keyring [keyring (default-keyring)])
  (log-trace 'get-password service-name username)
  (check-keyring 'get-password keyring)
  (define secret ($get-password keyring service-name username))
  (unless secret
    (log-keyring-warning "password not found\n  service-name: ~a\n  username: ~a"
                         service-name username))
  secret)

(define (set-password! service-name
                       username
                       password
                       #:keyring [keyring (default-keyring)])
  (log-trace 'set-password! service-name username)
  (check-keyring 'set-password! keyring)
  ($set-password! keyring service-name username password))

(define (delete-password! service-name
                          username
                          #:keyring [keyring (default-keyring)])
  (log-trace 'delete-password! service-name username)
  (check-keyring 'delete-password! keyring)
  ($delete-password! keyring service-name username))

