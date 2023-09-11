#lang racket/base

#|
   Copyright 2020-2023 Sam Phillips <samdphillips@gmail.com>

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

(provide
 raise-backend-error
 raise-backend-load-error
 raise-unimplemented

 (struct-out keyring-error)
 (struct-out keyring-unimplemented)
 (struct-out keyring-backend-error)
 (struct-out keyring-backend-load-error))

(require racket/format
         racket/string)

(struct keyring-error              exn:fail      [])
(struct keyring-unimplemented      keyring-error [name])
(struct keyring-backend-error      keyring-error [name])
(struct keyring-backend-load-error keyring-error [name])

;; like `compose-error-message` from unstable-lib with less error checking
(define (compose-error-message name message . fvs)
  (define details
    (let build ([fvs fvs])
      (cond
        [(null? fvs) null]
        [else
         (define field (car fvs))
         (define value (cadr fvs))
         (cons (~.a "  " field ": " value)
               (build (cddr fvs)))])))
  (string-join
   (cons (~.a name ": " message (if (null? fvs) "" ";")) details) "\n"))

;; turns ((k1 . v1) (k2 . v2) ...) into (k1 v1 k2 v2 ...)
(define (flatten-assoc alist)
  (if (null? alist)
      null
      (list* (caar alist)
             (cdar alist)
             (flatten-assoc (cdr alist)))))

(define (raise-unimplemented who msg kr)
  (define message
    (compose-error-message who msg "keyring" kr))
  (raise (keyring-unimplemented message (current-continuation-marks) who)))

(define (raise-backend-error who
                             message
                             [backend #f]
                             [details null]
                             [exc keyring-backend-error])
  (define full-message
    (apply compose-error-message
           who message "backend" backend
           (flatten-assoc details)))
  (raise
   (exc full-message (current-continuation-marks) backend)))

(define (raise-backend-load-error who message [backend #f] [details null])
  (raise-backend-error who message backend details keyring-backend-load-error))
