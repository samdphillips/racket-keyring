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
         keyring/interface
         get-pass)

(define (make-key s u)
  (cons (string->immutable-string s)
        (string->immutable-string u)))

(define (coerce-boolean val)
  (match val
    [(or #t "true" "1") #t]
    [_ #f]))

;; the intent of the semaphore is so only one thread at a time
;; is messing with the console.
(define get-pass-semaphore (make-semaphore 1))

(struct get-pass-keyring (cache)
  #:methods gen:keyring
  [(define (get-password kr service username)
     ; XXX: requests for the same service/username in separate threads will
     ; prompt twice if called at the same time.  The second invocation
     ; overwrites the first.
     (define (request-password)
       (define prompt-string
         (format "~a/~a password: " service username))
       (define password
         (call-with-semaphore
          get-pass-semaphore
          (lambda () (get-pass prompt-string))))
       (string->bytes/utf-8 password))
     (cond
       [(not (get-pass-keyring-cache kr))
        (request-password)]
       [else
        (hash-ref! (get-pass-keyring-cache kr)
                   (make-key service username)
                   request-password)]))

   (define (set-password kr service username password)
     (when (get-pass-keyring-cache kr)
       (hash-set! (get-pass-keyring-cache kr)
                  (make-key service username)
                  password)))

   (define (delete-password! kr service username)
     (when (get-pass-keyring-cache kr)
       (hash-remove! (get-pass-keyring-cache kr)
                     (make-key service username))))])

(define (make-keyring #:cache [cache? #t])
  (let* ([cache? (coerce-boolean cache?)]
         [cache  (and cache? (make-hash))])
    (get-pass-keyring cache)))

