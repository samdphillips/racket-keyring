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

(provide keyring<%>
         prop:keyring
         gen:keyring

         keyring-funcs
         (rename-out [-keyring? keyring?]))

(require keyring/private/error
         racket/class
         racket/format
         racket/generic)


;;
;; struct property based interface for low-level struct hackers

(define (keyring-property-guard v info)
  (define who 'prop:keyring)
  (define (guard-property-slot field i arity)
    (let ([p (vector-ref v i)])
      (cond
        [(not p)
         (λ (kr . args)
           (raise-unimplemented field
                                "keyring interface unimplemented"
                                kr))]
        [(and (procedure? p)
              (procedure-arity-includes? p arity))
         p]
        [(exact-nonnegative-integer? p)
         (define init-count (list-ref info 1))
         (unless (< p init-count)
           (raise-arguments-error
            who
            "field index >= initialized-field count for structure type"
            "field index" p
            "initialized-field count" init-count))
         (define ref (list-ref info 3))
         (λ (kr . args) (apply (ref kr p) kr args))]
        [else
         (raise-arguments-error
          who
          (format "(or/c (procedure-arity-includes/c ~a) exact-nonnegative-integer? #f)" arity)
          "prop-field" field
          "prop-field-value" p)])))
  (unless (and (vector? v) (= 3 (vector-length v)))
    (raise-argument-error
     who
     "(vector/c (or/c procedure? exact-nonnegative-integer? #f) (or/c procedure? exact-nonnegative-integer? #f) (or/c procedure? exact-nonnegative-integer? #f))"
     v))
  (vector (guard-property-slot 'get-password     0 3)
          (guard-property-slot 'set-password!    1 4)
          (guard-property-slot 'delete-password! 2 3)))

(define-values (prop:keyring prop:keyring? keyring-funcs)
  (make-struct-type-property 'keyring keyring-property-guard))

(define -keyring? (procedure-rename prop:keyring? 'keyring?))

;;
;; class based keyring interface
(define keyring<%>
  (interface*
   ()
   ([prop:keyring
     (vector (λ (kr service username)
               (send kr get-password service username))
             (λ (kr service username password)
               (send kr set-password! service username password))
             (λ (kr service username)
               (send kr delete-password! service username)))])
   get-password
   set-password!
   delete-password!))


;;
;; struct generics
(define-generics keyring
  [get-password     keyring service username]
  [set-password!    keyring service username password]
  [delete-password! keyring service username]
  #:derive-property
  prop:keyring
  (vector (λ (kr service username)
            (get-password kr service username))
          (λ (kr service username password)
            (set-password! kr service username password))
          (λ (kr service username)
            (delete-password! kr service username))))
