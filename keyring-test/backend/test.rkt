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

(require racket/match
         keyring/interface)

(struct test-keyring (service-name username secret-value)
  #:methods
  gen:keyring
  [(define (get-password-proc kr service-name username)
     (match kr
       [(test-keyring (== service-name) (== username) secret) secret]
       [_ #f]))

   (define set-password-proc! void)
   (define delete-password-proc! void)]
  #:transparent)

(define (make-keyring #:service  service-name
                      #:username username
                      #:password password)
  (test-keyring service-name username (string->bytes/utf-8 password)))
