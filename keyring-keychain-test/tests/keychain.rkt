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

;; Use of the `keychain-test` submodule instead of the standard `test`
;; submodule is to subvert the package server from running this module.  The
;; package server runs Linux and this will always fail there.
;; Also the package server considers the keychain-test submodule a run-time
;; module and will warn about a missing package dependency on rackunit-lib.
(module test racket/base
  (require rackunit)
  (provide (all-from-out rackunit)))

(module keychain-test racket/base
  (require (submod ".." test)
           keyring/backend/private/keychain
           (submod keyring/backend/private/keychain for-test))

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

