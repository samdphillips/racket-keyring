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

(provide keyring<%>
         prop:keyring
         gen:keyring

         keyring?
         get-password
         set-password!
         delete-password!)

(require racket/class
         racket/function
         racket/generic
         racket/match)


;;
;; class based keyring interface

(define keyring<%>
  (interface ()
    get-password
    set-password!
    delete-password!))

(define (object-keyring? v)
  (is-a? v keyring<%>))

(define (make-object-keyring-shim method-name)
  (define method-generic (make-generic keyring<%> method-name))
  (lambda (keyring . args)
    (send-generic keyring method-generic . args)))

(define get-password/obj     (make-object-keyring-shim 'get-password))
(define set-password!/obj    (make-object-keyring-shim 'set-password!))
(define delete-password!/obj (make-object-keyring-shim 'delete-password!))


;;
;; struct property based interface for low-level struct hackers

(define (keyring-funcs-guard vec stype-info)
  (match-define (list _ _ _ ref _ ...) stype-info)
  (for/vector #:length 3 ([v (in-vector vec)])
    (cond
      [(procedure? v) (const v)]
      [else
       (lambda (o) (ref o v))])))

(define-values (prop:keyring prop:keyring? prop-keyring-funcs)
  (make-struct-type-property 'keyring keyring-funcs-guard))

(define ((make-struct-property-shim slot) obj . args)
  (define desc (prop-keyring-funcs obj))
  (define method ((vector-ref desc slot) obj))
  (apply method obj args))

(define get-password/prop     (make-struct-property-shim 0))
(define set-password!/prop    (make-struct-property-shim 1))
(define delete-password!/prop (make-struct-property-shim 2))


;;
;; struct generics to tie the room together

(define-generics keyring
  [get-password     keyring service username]
  [set-password!    keyring service username password]
  [delete-password! keyring service username]
  #:defaults
  ([object-keyring?
    (define get-password     get-password/obj)
    (define set-password!    set-password!/obj)
    (define delete-password! delete-password!/obj)]
   [prop:keyring?
    (define get-password     get-password/prop)
    (define set-password!    set-password!/prop)
    (define delete-password! delete-password!/prop)]))

