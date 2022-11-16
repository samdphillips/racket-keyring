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

(require racket/contract
         "private/error.rkt"
         "private/interface.rkt")

(provide keyring<%>
         prop:keyring
         gen:keyring

         keyring?
         keyring-error?
         keyring-backend-error?
         keyring-backend-load-error?
         (contract-out
          [get-password (-> keyring? string? string? (or/c #f bytes?))]
          [set-password! (-> keyring? string? string? bytes? any)]
          [delete-password! (-> keyring? string? string? any)]
          [raise-backend-error
           (->* (symbol?  string?)
               (
               (or/c #f string?)
               (listof (cons/c symbol? any/c)))
               any)]
          [raise-backend-load-error
           (->* (symbol?
               string?)
               ((or/c #f string?)
               (listof (cons/c symbol? any/c)))
               any)]
          [keyring-backend-error-name
           (-> keyring-backend-error? (or/c #f string?))]
          [keyring-backend-load-error-name
           (-> keyring-backend-load-error? (or/c #f string?))])

         keyring-logger
         log-keyring-fatal
         log-keyring-error
         log-keyring-warning
         log-keyring-info
         log-keyring-debug)

(define-logger keyring)

;; XXX: logging wrappers that backends can use to have more consistent messages