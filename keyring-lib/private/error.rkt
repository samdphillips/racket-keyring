#lang racket/base

(provide
  raise-backend-error
  raise-backend-load-error

  (struct-out keyring-error)
  (struct-out keyring-backend-error)
  (struct-out keyring-backend-load-error))

(require racket/format)

(struct keyring-error              exn:fail      [])
(struct keyring-backend-error      keyring-error [name])
(struct keyring-backend-load-error keyring-error [name])

(define (raise-backend-error who msg [backend #f] [details null])
  (define full-message
    (apply ~a #:separator "\n"
      (~.a who ": " msg ";")
      (~.a "  backend: " backend)
      (for/list ([kv (in-list details)])
        (~.a "  " (car kv) ": " (cdr kv)))))
  (raise
    (keyring-backend-error full-message
                           (current-continuation-marks)
                           backend)))

(define (raise-backend-load-error who msg [backend #f] [details null])
  (define full-message
    (~a (~.a who ": " msg ";") "\n"
         (apply ~a #:separator "\n"
                (~.a "  backend: " backend)
                (for/list ([kv (in-list details)])
                  (~.a "  " (car kv) ": " (cdr kv))))))
  (raise
    (keyring-backend-load-error full-message
                                (current-continuation-marks)
                                backend)))

