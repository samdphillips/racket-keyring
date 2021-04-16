#lang racket/base

(require racket/cmdline
         keyring)

(provide keyring-get-cmd)

(define (get-current-user)
  (getenv "USER"))

(define (keyring-get-cmd cmd-name arguments)
  (define keyring #f)
  (define-values (service-name user-name)
    (command-line
     #:program cmd-name
     #:argv arguments
     #:once-each
     [("-k" "--keyring")
      keyring-spec "keyring url to use"
      ;; XXX: better message when cannot load keyring
      (set! keyring (make-keyring-from-string keyring-spec))]
     #:args (service-name [user-name #f])
     (values service-name
             (or user-name
                 (get-current-user)))))

  ;; XXX: better message when no keyring specified
  (parameterize ([default-keyring (or keyring (default-keyring))])
    (define secret
      (get-password service-name user-name))
    (when secret
      (void (write-bytes secret))
      (newline))))

(module* main #f
  (require raco/command-name)
  (keyring-get-cmd (short-program+command-name)
                   (current-command-line-arguments)))

