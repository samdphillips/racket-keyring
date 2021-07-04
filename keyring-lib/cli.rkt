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

