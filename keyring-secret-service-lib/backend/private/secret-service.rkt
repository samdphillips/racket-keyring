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

(require racket/class
         racket/format
         racket/list
         racket/match
         dbus
         (rename-in dbus/interface
                    [dbus-properties<%> dbus-properties-mixin])
         keyring/interface)

(provide secret-service-keyring%)

(define secret-service-dbus-endpoint "org.freedesktop.secrets")

(define secret-dbus-object%
  (class dbus-object%
    (init-field service)
    (inherit-field connection)

    (define/public-final (make-secret-object % path)
      (new %
           [service    service]
           [path       path]
           [connection connection]))

    (define/public-final (make-item path)
      (make-secret-object secret-item% path))

    (super-new
     [endpoint secret-service-dbus-endpoint])))

(define-dbus-interface
  secret-service-mixin "org.freedesktop.Secret.Service"
  [OpenSession      "sv"]
  [CreateCollection "a{sv}s"]
  [SearchItems      "a{ss}"]
  [Unlock           "ao"]
  [Lock             "ao"]
  [GetSecrets       "aoo"])

(define secret-service%
  (class (secret-service-mixin secret-dbus-object%)
    (inherit-field connection)
    (super-new [service this]
               [path "/org/freedesktop/secrets"])

    (field [bus (dbus-manager connection)]
           [session #f])
    (send bus Hello)

    (inherit OpenSession
             make-secret-object
             make-item)

    (define/public (get-session)
      (unless session
        (define-values (session-out session-path) (OpenSession "plain" (cons "s" "")))
        (set! session (make-secret-object secret-session% session-path)))
      session)

    (define/public (disconnect)
      (when session
        (send session Close)
        (set! session #f)))

    (define/override (SearchItems attrs)
      (define-values (unlocked locked) (super SearchItems attrs))
      (values (for/list ([path (in-list unlocked)]) (make-item path))
              (for/list ([path (in-list locked)]) (make-item path))))

    (define/override (Unlock items)
      (define-values (unlocked prompt-path)
        (super Unlock (map (lambda (i) (get-field path i)) items)))
      (values (for/list ([path (in-list unlocked)]) (make-item path))
              (if (string=? prompt-path "/")
                  #f
                  (make-secret-object secret-prompt% prompt-path))))

    (define/override (CreateCollection props alias)
      (define-values (collection-path prompt-path) (super CreateCollection props alias))
      (define (wait-for-prompt)
        (match (send (make-secret-object secret-prompt% prompt-path) wait)
          [(cons "o" path) (make-collection-proxy path)]
          [x x]))
      (define (make-collection-proxy path)
        (make-secret-object secret-collection% path))
      (cond
        [(string=? collection-path "/") (wait-for-prompt)]
        [else (make-collection-proxy collection-path)]))
    ))

(define-dbus-interface
  secret-collection-mixin "org.freedesktop.Secret.Collection"
  [SearchItems "a{ss}"]
  [CreateItem  "a{sv}(oayays)b"]
  [Delete      ""])

(define secret-collection%
  (class (secret-collection-mixin secret-dbus-object%)
    (inherit make-secret-object
             make-item)

    (define/override (SearchItems attrs)
      (define items
        (for/list ([path (super SearchItems attrs)])
          (make-item path)))
      (partition (lambda (item) (send item unlocked?)) items))

    (define/override (CreateItem props secret replace?)
      (define-values (item-path prompt-path) (super CreateItem props secret replace?))
      (define (wait-for-prompt)
        (match (send (make-secret-object secret-prompt% prompt-path) wait)
          [(cons "o" path) (make-item path)]
          [x x]))
      (cond
        [(string=? item-path "/") (wait-for-prompt)]
        [else (make-item item-path)]))

    (define/override (Delete)
      (make-secret-object secret-prompt% (super Delete)))

    (super-new)))

(define-dbus-interface
  secret-item-mixin "org.freedesktop.Secret.Item"
  [GetSecret "o"])

(define secret-item%
  (class (secret-item-mixin (dbus-properties-mixin secret-dbus-object%))
    (inherit Get)
    (inherit-field service)

    (define/public (locked?)
      (Get "org.freedesktop.Secret.Item" "Locked"))

    (define/public (unlocked?)
      (not (locked?)))

    (define/override (GetSecret)
      (match-define
        (list session params secret-bytes-list content-type)
        (super GetSecret (get-field path (send service get-session))))
      (list->bytes secret-bytes-list))

    (super-new)))

(define-dbus-interface
  secret-session-mixin "org.freedesktop.Secret.Session"
  [Close ""])

(define secret-session%
  (secret-session-mixin secret-dbus-object%))

(define-dbus-interface
  secret-prompt-mixin "org.freedesktop.Secret.Prompt"
  [Prompt "s"]
  [Dismiss ""])

(define secret-prompt%
  (class (secret-prompt-mixin secret-dbus-object%)
    (super-new)
    (inherit Prompt)
    (inherit-field service path connection)

    (define/public (wait)
      (unless (string=? "/" path)
        (define prompt-completed-rule
          (~a "type='signal',"
              "interface='org.freedesktop.Secret.Prompt',"
              "member='Completed',"
              "path='" path "'"))
        (define (wait-for-prompt)
          (sync (handle-evt
                 (dbus-listen-evt connection)
                 (lambda (v)
                   (match v
                     [(list (== path)
                            "org.freedesktop.Secret.Prompt"
                            "Completed"
                            (list 'signal dismissed? result))
                      (remove-match)
                      (if dismissed? #f result)]
                     [_ (wait-for-prompt)])))))
        (define (remove-match)
          (send (get-field bus service) RemoveMatch prompt-completed-rule))
        (send (get-field bus service) AddMatch prompt-completed-rule)
        (Prompt "racket-keyring")
        (wait-for-prompt)))))

(define secret-service-keyring%
  (class* object% (keyring<%>)
    (init-field [connection
                 (or (current-dbus-connection)
                     (dbus-connect-session-bus))])

    (init [secret-collection-path
           "/org/freedesktop/secrets/collection/login"])

    (define secret-service
      (new secret-service%
           [connection connection]))

    (define secret-collection
      (new secret-collection%
           [service    secret-service]
           [connection connection]
           [path       secret-collection-path]))

    (define (find-item service username)
      (define-values (unlocked-items locked-items)
        (send secret-collection SearchItems
              (list (cons "service" service)
                    (cons "username" username))))
      (match* (unlocked-items locked-items)
        [((list) (list)) #f]
        [((cons item _) _) item]
        [((list) (cons item _)) (unlock-item item)]))

    (define (unlock-item item)
      (define-values (unlocked-items a-prompt)
        (send secret-service Unlock (list item)))
      (cond
        [(null? unlocked-items) (and (send a-prompt wait) item)]
        [else item]))

    (define/public (disconnect)
      (send secret-service disconnect))

    (define/public (get-password service username)
      (define item (find-item service username))
      (and item (send item GetSecret)))

    (define/public (set-password! service username password)
      (define attrs
        `(["username" . ,username]
          ["service"  . ,service]))
      (define props
        `(["org.freedesktop.Secret.Item.Label"      . ("s"     . ,(~a service " - " username))]
          ["org.freedesktop.Secret.Item.Attributes" . ("a{ss}" . ,attrs)]))
      (define secret
        (list (get-field path (send secret-service get-session))
              null
              (bytes->list password)
              "text/plain; charset=utf8"))
      (unless (send secret-collection CreateItem props secret #t)
        (error 'set-password
               "failed to set password for service: ~a, username: ~a"
               service username)))

    ;; TODO: implement this
    (define/public (delete-password! service username)
      (error 'delete-password! "unimplemented"))

    (super-new)))

(module* test #f
  (require rackunit)

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
        (set-password! kr "test1" "test1-user" #"test1-secret")
        (check-equal? (get-password kr "test1" "test1-user") #"test1-secret")))

    ;; remove testing collection
    (parameterize ([current-dbus-connection (dbus-connect-session-bus)])
      (define svc (new secret-service%))
      (define test-collection
        (new secret-collection%
             [service svc]
             [path test-collection-path]))
      (send (send test-collection Delete) wait))))


