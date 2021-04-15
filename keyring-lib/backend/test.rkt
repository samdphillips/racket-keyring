#lang racket/base

(provide make-keyring)

(require racket/match
         keyring/interface)

(struct test-keyring (service-name username secret-value)
  #:methods
  gen:keyring
  [(define (get-password kr service-name username)
     (match kr
       [(test-keyring (== service-name) (== username) secret) secret]
       [_ #f]))

   (define set-password! void)
   (define delete-password! void)]
  #:transparent)

(define (make-keyring #:service  service-name
                      #:username username
                      #:password password)
  (test-keyring service-name username (string->bytes/utf-8 password)))

