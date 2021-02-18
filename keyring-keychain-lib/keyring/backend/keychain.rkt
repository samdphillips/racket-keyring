#lang racket/base

(provide make-keyring)

(require keyring/interface
         keyring/backend/private/keychain)

(struct keychain-keyring [kc]
  #:methods gen:keyring
  [(define (get-password kr service-name username)
     (define kc (keychain-keyring-kc kr))
     (define password
       (sec-keychain-find-generic-password kc service-name username))
     (cond
       [(bytes? password) password]
       [else
         (log-keyring-warning "backend=~a, action=~a, status=~a" 'keychain 'get-password password)
         #f]))

   (define (set-password! kr service-name username password)
     (define kc (keychain-keyring-kc kr))
     (define status (sec-keychain-add-generic-password kc service-name username password))
     (unless (eq? 'ok status)
       (raise-backend-error 'set-password!
                            "error setting password"
                            'keychain
                            (list (cons 'error-code status)))))


     ])

(define (make-keyring #:path [path #f])
  (define kc
    (if path
        (sec-keychain-open path)
        (sec-keychain-copy-default)))
  (log-keyring-debug "making keyring backend=~a keyring-path=~a result=~a"
                     'keyring path kc)
  (keychain-keyring kc))

