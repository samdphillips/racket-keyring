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

(module test racket/base
  (require dbus
           keyring
           racket/class
           rackunit
           (submod keyring/backend/private/secret-service for-test))

  (define test-secret-service-keyring?
    (and (getenv "DBUS_SESSION_BUS_ADDRESS") #t))

  (define-syntax-rule (with-service svc body ...)
    (dynamic-wind void (lambda () body ...) (lambda () (send svc disconnect))))

  (when test-secret-service-keyring?
    ;; set up collection for testing
    (define test-collection-path
      (parameterize ([current-dbus-connection (dbus-connect-session-bus)])
        (define svc (new secret-service%))
        (with-service svc
          (define test-collection
            (send svc CreateCollection
                  '(["org.freedesktop.Secret.Collection.Label" . ("s" . "rkt_keyring_secretservice_test")]) ""))
          (and test-collection (get-field path test-collection)))))

    (test-case "simple set and get password"
      (define kr (new secret-service-keyring% [secret-collection-path test-collection-path]))
      (with-service kr
        (parameterize ([default-keyring kr])
          (set-password! "test1" "test1-user" #"test1-secret")
          (check-equal? (get-password "test1" "test1-user") #"test1-secret"))))

    ;; remove testing collection
    (parameterize ([current-dbus-connection (dbus-connect-session-bus)])
      (define svc (new secret-service%))
      (define test-collection
        (new secret-collection%
             [service svc]
             [path test-collection-path]))
      (send (send test-collection Delete) wait))))
