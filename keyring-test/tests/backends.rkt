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
  (require rackunit
           keyring/interface
           keyring/private/error
           keyring/private/backends
           (submod keyring/private/backends for-test))

  (test-case "parse-backend-connect-string"
    (define s "fake-backend:///all/passwords?token=cafebabe")
    (define-values (backend kws args) (parse-backend-connect-string s))
    (check-equal? backend "fake-backend")
    (check-equal? kws (list '#:path '#:token))
    (check-equal? args (list "/all/passwords" "cafebabe")))

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
    (check-equal? args null))

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
