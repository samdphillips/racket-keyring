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
         keyring/backend/private/keychain)

(module test racket/base)

(struct keychain-keyring [kc]
  #:methods gen:keyring
  [(define (get-password kr service-name username)
     (define kc (keychain-keyring-kc kr))
     (define password
       (sec-keychain-find-generic-password kc service-name username))
     (cond
       [(bytes? password) password]
       [else
        (log-keyring-warning "backend=~a, action=~a, status=~a"
                             'keychain 'get-password password)
        #f]))

   (define (set-password! kr service-name username password)
     (define kc (keychain-keyring-kc kr))
     (define-values (status method)
       (match (sec-keychain-find-generic-item kc service-name username)
         [(? sec-keychain-item? item)
          (values (sec-keychain-item-modify-attributes-and-data item password)
                  'modify)]
         ['item-not-found
          (values (sec-keychain-add-generic-password kc service-name
                                                     username password)
                  'add)]
         [status (values status #f)]))
     (unless (eq? 'ok status)
       (raise-backend-error 'set-password!
                            "error setting password"
                            'keychain
                            (append (list (cons 'error-code status))
                                    (if method
                                        (list (cons 'method method))
                                        null)))))

   (define (remove-password! kr service-name username)
     (define kc (keychain-keyring-kc kr))
     (define status
       (match (sec-keychain-find-generic-item kc service-name username)
         [(? sec-keychain-item? item) (sec-keychain-item-delete item)]
         [status status]))
     (unless (or (eq? 'ok status) (eq? 'item-not-found status))
       (raise-backend-error 'remove-password!
                            "error removing password"
                            'keychain
                            (list (cons 'error-code status)))))])

(define (make-keyring #:path [path #f])
  (define kc
    (if path
        (sec-keychain-open path)
        (sec-keychain-copy-default)))
  (keychain-keyring kc))

