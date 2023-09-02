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

(require racket/contract)

(provide
 (contract-out
  [make-keyring-from-string (-> string? (or/c #f keyring?))]))

(require net/url
         racket/format
         racket/match
         racket/string
         keyring/interface
         keyring/private/error)

(define (url-path-as-pathstring a-url)
  (define paths
    (for/list ([pp (in-list (url-path a-url))]) (path/param-path pp)))
  (if (null? paths) #f (string-join #:before-first "/" paths "/")))

(define (url-host-not-empty u)
  (match (url-host u)
    [(or #f "") #f]
    [h h]))

(define url-keyword-mappers
  (list (cons url-user '#:user)
        (cons url-host-not-empty '#:host)
        (cons url-port '#:port)
        (cons url-path-as-pathstring '#:path)))

(module+ for-test (provide parse-backend-connect-string))

(define (parse-backend-connect-string conn-string)
  (define u (string->url conn-string))
  (define base-kwargs
    (for*/list ([acc+kw (in-list url-keyword-mappers)]
                [acc    (in-value (car acc+kw))]
                [kw     (in-value (cdr acc+kw))]
                [v      (in-value (acc u))]
                #:when v)
      (cons kw v)))
  (define query-kwargs
    (for*/list ([kv (in-list (url-query u))]
                [k  (in-value (car kv))]
                [v  (in-value (cdr kv))])
      (cons (string->keyword (symbol->string k)) v)))
  (define kwargs
    (sort (append base-kwargs query-kwargs)
          keyword<?
          #:key car))
  (values (url-scheme u) (map car kwargs) (map cdr kwargs)))

(define (remove-extra-kwargs accepted-kws kws args)
  (cond
    [(or (null? accepted-kws) (null? kws)) (values null null)]
    [else
     (define akw (car accepted-kws))
     (define kw (car kws))
     (cond
       [(equal? akw kw)
        (define-values (rkws rargs)
          (remove-extra-kwargs (cdr accepted-kws) (cdr kws) (cdr args)))
        (values (cons kw rkws) (cons (car args) rargs))]
       [(keyword<? akw kw)
        (remove-extra-kwargs (cdr accepted-kws) kws args)]
       [else
        (remove-extra-kwargs accepted-kws (cdr kws) (cdr args))])]))

(module+ for-test (provide conform-kwargs))

(define (conform-kwargs proc kws args)
  (define-values (_reqd-kws accepted-kws) (procedure-keywords proc))
  (cond
    [(not accepted-kws) (values kws args)]
    [else (remove-extra-kwargs accepted-kws kws args)]))

(define (make-backend-module-path backend-name)
  (string->symbol
   (string-append "keyring/backend/" backend-name)))

(define (missing-backend-module-error who backend-name e)
  (raise-backend-load-error who
                            "failed loading backend"
                            backend-name
                            (list
                             (cons 'orig-exn (exn-message e)))))

(define (invalid-backend-url who url-string error-description e)
  (define msg
    (if error-description
        (~a "invalid backend url, " error-description)
        "invalid backend url"))
  (define details
    (list* (cons 'url url-string)
           (if e
               (list (cons 'orig-exn (exn-message e)))
               null)))
  (raise-backend-load-error who msg #f details))

(define (missing-backend-constructor-error who backend-name)
  (raise-backend-load-error who
                            "backend does not provide a make-keyring procedure"
                            backend-name))

(define (make-keyring-from-string url-string)
  (define-values (backend-name cfg-kws cfg-args)
    (with-handlers ([url-exception?
                     (lambda (e)
                       (invalid-backend-url 'make-keyring-from-string url-string #f e))])
      (parse-backend-connect-string url-string)))
  (unless backend-name
    (invalid-backend-url
     'make-keyring-from-string url-string "no backend specified" #f))

  (define mod (make-backend-module-path backend-name))
  (define/contract make-keyring
    (suggest/c (unconstrained-domain-> (or/c #f keyring?))
               "suggestion"
               (~a backend-name
                   " backend make-keyring"
                   " function failed to produce a keyring?"))
    (with-handlers ([exn:fail:filesystem:missing-module?
                     (lambda (e)
                       (missing-backend-module-error
                        'make-keyring-from-string backend-name e))])
      (dynamic-require mod
                       'make-keyring
                       (lambda ()
                         (missing-backend-constructor-error
                          'make-keyring-from-string backend-name)))))
  (define-values (kws args) (conform-kwargs make-keyring cfg-kws cfg-args))
  (log-keyring-info "making keyring backend=~a args=~s"
                     backend-name (map cons kws args))
  (keyword-apply make-keyring kws args null))
