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

;; cribbed from https://github.com/jaraco/keyring/blob/master/keyring/backends/_OS_X_API.py

(provide sec-keychain-copy-default
         sec-keychain-open
         sec-keychain-find-generic-password
         sec-keychain-add-generic-password
         sec-keychain-find-generic-item
         sec-keychain-item-modify-attributes-and-data
         sec-keychain-item-delete
         sec-keychain-item?)

(require racket/dict
         ffi/unsafe
         ffi/unsafe/alloc
         ffi/unsafe/define
         ffi/unsafe/define/conventions)

;; Use of the `keychain-test` submodule instead of the standard `test`
;; submodule is to subvert the package server from running this module.  The
;; package server runs Linux and this will always fail there.
;; Also the package server considers the keychain-test submodule a run-time
;; module and will warn about a missing package dependency on rackunit-lib.
(module test racket/base
  (require rackunit)
  (provide (all-from-out rackunit)))
(module+ keychain-test
  (require (submod ".." test)))

(define core-lib
  (ffi-lib "/System/Library/Frameworks/CoreServices.framework/CoreServices"))

(define cf-release
  ((releaser) (get-ffi-obj "CFRelease" core-lib (_fun _pointer -> _void))))

(define security-lib
  (ffi-lib "/System/Library/Frameworks/Security.framework/Security"))

(define-ffi-definer define-security-ffi security-lib
  #:make-c-id convention:hyphen->camelcase)

(define sec-keychain-status-codes
  '([0      . ok]
    [-25300 . item-not-found]
    [-128   . keychain-denied]
    [-25293 . sec_auth_failed]))

(define (status-or-value status value)
  (if (zero? status)
      value
      (dict-ref sec-keychain-status-codes status status)))

(define-cpointer-type _sec-keychain)
(define-cpointer-type _sec-keychain-item)

(define allocate-wrapper
  (let ([register-release ((allocator cf-release) values)])
    (lambda (inner)
      (lambda args
        (define val (apply inner args))
        (cond
          [(or (symbol? val) (integer? val)) val]
          [else (register-release val)])))))

(define-security-ffi sec-keychain-copy-default
  (_fun [keychain : (_ptr o _sec-keychain)]
        -> [status : _int32]
        -> (status-or-value status keychain))
  #:wrap allocate-wrapper)

(define-security-ffi sec-keychain-open
  (_fun _file
        [keychain : (_ptr o _sec-keychain)]
        -> [status : _int32]
        -> (status-or-value status keychain))
  #:wrap allocate-wrapper)

(define-security-ffi sec-keychain-item-free-content
  (_fun [_pointer = #f] _pointer -> _int32))

(define-security-ffi sec-keychain-find-generic-password
  (_fun _sec-keychain
        [_uint32 = (bytes-length service-name)]
        [service-name : _bytes]
        [_uint32 = (bytes-length username)]
        [username : _bytes]
        [password-size : (_ptr o _uint32)]
        [raw-password : (_ptr o _pointer)]
        [_pointer = #f]
        -> [status : _int32]
        -> (cond
             [(zero? status)
              (define password (make-bytes password-size))
              (memcpy password raw-password password-size)
              (sec-keychain-item-free-content raw-password)
              password]
             [else
              (dict-ref sec-keychain-status-codes status status)]))
  #:wrap
  (lambda (inner)
    (lambda (kc service-name username)
      (define service-name-bytes (string->bytes/utf-8 service-name))
      (define username-bytes (string->bytes/utf-8 username))
      (inner kc service-name-bytes username-bytes))))

(define-security-ffi sec-keychain-find-generic-item
  (_fun _sec-keychain
        [_uint32 = (bytes-length service-name)]
        [service-name : _bytes]
        [_uint32 = (bytes-length username)]
        [username : _bytes]
        [_pointer = #f]
        [_pointer = #f]
        [item : (_ptr o _sec-keychain-item)]
        -> [status : _int32]
        -> (status-or-value status item))
  #:c-id SecKeychainFindGenericPassword
  #:wrap
  (lambda (inner)
    (define (wrap kc service-name username)
      (define service-name-bytes (string->bytes/utf-8 service-name))
      (define username-bytes (string->bytes/utf-8 username))
      (inner kc service-name-bytes username-bytes))
    (allocate-wrapper wrap)))

(define-security-ffi sec-keychain-item-modify-attributes-and-data
  (_fun _sec-keychain-item
        [_pointer = #f]
        [_uint32 = (bytes-length password)]
        [password : _bytes]
        -> [status : _int32]
        -> (status-or-value status 'ok))
  #:c-id SecKeychainItemModifyAttributesAndData)

(define-security-ffi sec-keychain-add-generic-password
  (_fun _sec-keychain
        [_uint32 = (bytes-length service-name)]
        [service-name : _bytes]
        [_uint32 = (bytes-length username)]
        [username : _bytes]
        [_uint32 = (bytes-length password)]
        [password : _bytes]
        [_pointer = #f]
        -> [status : _int32]
        -> (status-or-value status 'ok))
  #:wrap
  (lambda (inner)
    (lambda (kc service-name username password)
      (define service-name-bytes (string->bytes/utf-8 service-name))
      (define username-bytes (string->bytes/utf-8 username))
      (inner kc service-name-bytes username-bytes password))))

(define-security-ffi sec-keychain-item-delete
  (_fun _sec-keychain-item
        -> [status : _int32]
        -> (dict-ref sec-keychain-status-codes status status)))

(module+ keychain-test
  (define get-keychain
    (let ([path (getenv "MACOSX_TEST_KEYCHAIN")])
      (if path
          (let ([path (path->complete-path path)])
            (lambda ()
              (define kc (sec-keychain-open path))
              (check-pred sec-keychain? kc)
              kc))
          (lambda ()
            (define kc (sec-keychain-copy-default))
            (check-pred sec-keychain? kc)
            kc))))

  (test-case "sec-keychain-add-generic-password"
    (define kc (get-keychain))
    (check-equal? (sec-keychain-add-generic-password kc "test1" "test" #"abc123")
                  'ok)
    (check-equal? (sec-keychain-find-generic-password kc "test1" "test")
                  #"abc123"))

  (test-case "sec-keychain-item-modify-attributes-and-data"
    (define kc (get-keychain))
    (define item (sec-keychain-find-generic-item kc "test1" "test"))
    (check-equal?
     (sec-keychain-item-modify-attributes-and-data item #"xyz123") 'ok)
    (check-equal? (sec-keychain-find-generic-password kc "test1" "test")
                  #"xyz123"))

  (let ()
    (define kc (get-keychain))
    (check-equal? (sec-keychain-item-delete
                   (sec-keychain-find-generic-item kc "test1" "test"))
                  'ok)))
