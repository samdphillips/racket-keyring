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

(require keyring/interface
         rackunit)

(define (test-keyring name make specific?)
  (define kr (make))
  (test-case name
    (check-pred specific? kr "keyring is not the specific type")
    (check-pred keyring? kr "keyring is not a keyring?")

    (check-false (get-password kr "testservice" "testuser1")
                 "testservice/testuser1 are in use")
    (set-password! kr "testservice" "testuser1" #"secret1")
    (check-equal? #"secret1"
                  (get-password kr "testservice" "testuser1")
                  "testservice/testuser1 secret incorrect")

    (check-false (get-password kr "testservice" "testuser2")
                 "testservice/testuser2 are in use")
    (set-password! kr "testservice" "testuser2" #"secret2")
    (check-equal? #"secret1"
                  (get-password kr "testservice" "testuser1")
                  "testservice/testuser1 secret incorrect")
    (check-equal? #"secret2"
                  (get-password kr "testservice" "testuser2")
                  "testservice/testuser2 secret incorrect")

    (delete-password! kr "testservice" "testuser1")
    (check-false (get-password kr "testservice" "testuser1")
                 "testservice/testuser1 user not removed")
    (check-equal? #"secret2"
                  (get-password kr "testservice" "testuser2")
                  "testservice/testuser2 secret incorrect")))

(module* test #f
  (require racket/class)

  (struct st:keyring (store)
    #:property
    prop:keyring
    (vector (λ (kr service username)
              (hash-ref (st:keyring-store kr) (cons service username) #f))
            (λ (kr service username password)
              (hash-set! (st:keyring-store kr) (cons service username) password))
            (λ (kr service username)
              (hash-remove! (st:keyring-store kr) (cons service username)))))

  (define (make-st:keyring) (st:keyring (make-hash)))

  (test-keyring "struct property keyring" make-st:keyring st:keyring?)

  (struct g:keyring (store)
    #:methods
    gen:keyring
    [(define (get-password kr service username)
       (hash-ref (g:keyring-store kr) (cons service username) #f))
     (define (set-password! kr service username password)
       (hash-set! (g:keyring-store kr) (cons service username) password))
     (define (delete-password! kr service username)
       (hash-remove! (g:keyring-store kr) (cons service username)))])

  (define (make-g:keyring) (g:keyring (make-hash)))

  (test-keyring "generics keyring" make-g:keyring g:keyring?)

  (define keyring%
    (class* object% (keyring<%>)
      (field [store (make-hash)])

      (define/public (set-password! service username password)
        (hash-set! store (cons service username) password))

      (define/public (delete-password! service username)
        (hash-remove! store (cons service username)))

      (define/public (get-password service username)
        (hash-ref store (cons service username) #f))

      (super-new)))

  (test-keyring "keyring<%> interface"
                (λ () (new keyring%))
                (λ (v) (and (is-a? v keyring%)
                            (is-a? v keyring<%>)))))
