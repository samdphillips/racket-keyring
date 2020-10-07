#lang racket/base

(require racket/contract)

(provide
  (contract-out
    [make-keyring-from-string (-> string? (or/c #f keyring?))]))

(require net/url
         racket/format
         racket/match
         racket/string
         "error.rkt"
         "interface.rkt")

(module+ test
  (require rackunit
           keyring/interface))

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

(module+ test
  (test-case "parse-backend-connect-string"
    (define s "fake-backend:///all/passwords?token=cafebabe")
    (define-values (backend kws args) (parse-backend-connect-string s))
    (check-equal? backend "fake-backend")
    (check-equal? kws (list '#:path '#:token))
    (check-equal? args (list "/all/passwords" "cafebabe"))))

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

(define (conform-kwargs proc kws args)
  (define-values (_reqd-kws accepted-kws) (procedure-keywords proc))
  (cond
    [(not accepted-kws) (values kws args)]
    [else (remove-extra-kwargs accepted-kws kws args)]))

(module+ test
  (define (test-kw-proc #:host h #:path p #:token t) #f)

  (test-case "conform-kwargs all present"
    (define-values (kws args)
      (conform-kwargs test-kw-proc
                      (list '#:host '#:path '#:token)
                      (list 1 2 3)))
      (check-equal? kws '(#:host #:path #:token))
      (check-equal? args '(1 2 3)))

  (test-case "conform-kwargs extras a removed" #f)

  (test-case "conform-kwargs any args"
    (define-values (kws args)
      (conform-kwargs (make-keyword-procedure
                        (lambda (kws args) #f))
                      (list '#:host '#:path '#:token)
                      (list 1 2 3)))
      (check-equal? kws '(#:host #:path #:token))
      (check-equal? args '(1 2 3)))

  (test-case "conform-kwargs procedure with no args"
    (define-values (kws args)
      (conform-kwargs (lambda () #f)
                      (list '#:host '#:path '#:token)
                      (list 1 2 3)))
    (check-equal? kws null)
    (check-equal? args null)))

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
  (keyword-apply make-keyring kws args null))

(module+ test
  (test-case "make-keyring-from-string missing backend"
    (check-exn
      (lambda (e)
        (and (keyring-backend-load-error? e)
             (equal? (keyring-backend-load-error-name e) "nosuch")))
      (lambda ()
        (make-keyring-from-string "nosuch:"))))

  (test-case "make-keyring-from-string backend w/o constructor"
    (check-exn
      (lambda (e)
        (and (keyring-backend-load-error? e)
             (regexp-match?
               #px"backend does not provide a make-keyring procedure"
               (exn-message e))
             (equal? (keyring-backend-load-error-name e) "test-no-constr")))
      (lambda ()
        (make-keyring-from-string "test-no-constr:"))))

  (test-case "make-keyring-from-string backend no backend specified"
    (check-exn
      (lambda (e)
        (and (keyring-backend-load-error? e)
             (regexp-match? #px"no backend specified" (exn-message e))
             (equal? (keyring-backend-load-error-name e) #f)))
      (lambda ()
        (make-keyring-from-string "test"))))

  (test-case "make-keyring-from-string backend invalid scheme"
    (check-exn
      (lambda (e)
        (and (keyring-backend-load-error? e)
             (regexp-match? #px"invalid URL string" (exn-message e))
             (equal? (keyring-backend-load-error-name e) #f)))
      (lambda ()
        (make-keyring-from-string "xxx;yyy://test"))))

  (test-case "make-keyring-from-string test backend"
    (define keyring
      (make-keyring-from-string
        "test://?service=test-service&username=userA&password=abc123"))
    (check-equal? (get-password keyring "test-service" "userA") #"abc123")))

