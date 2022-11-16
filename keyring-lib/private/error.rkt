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

(provide
 raise-backend-error
 raise-backend-load-error

(rename-out [exn-message keyring-error-message])

 (struct-out keyring-error)
 (struct-out keyring-backend-error)
 (struct-out keyring-backend-load-error))

(require racket/format)

(struct keyring-error              exn:fail      [])
(struct keyring-backend-error      keyring-error [name])
(struct keyring-backend-load-error keyring-error [name])

(define (raise-backend-error who msg [backend #f] [details null])
  (define full-message
    (apply ~a #:separator "\n"
           (~.a who ": " msg ";")
           (~.a "  backend: " backend)
           (for/list ([kv (in-list details)])
             (~.a "  " (car kv) ": " (cdr kv)))))
  (raise
   (keyring-backend-error full-message
                          (current-continuation-marks)
                          backend)))

(define (raise-backend-load-error who msg [backend #f] [details null])
  (define full-message
    (~a (~.a who ": " msg ";") "\n"
        (apply ~a #:separator "\n"
               (~.a "  backend: " backend)
               (for/list ([kv (in-list details)])
                 (~.a "  " (car kv) ": " (cdr kv))))))
  (raise
   (keyring-backend-load-error full-message
                               (current-continuation-marks)
                               backend)))

