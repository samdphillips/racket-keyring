#lang scribble/manual

@(require (for-label
            racket
            (except-in keyring
              get-password
              set-password!
              delete-password!)))

@title{keyring - a library for uniformly accessing secrets}

@section{Front End Interface}

@defmodule[keyring]

@defproc[(keyring? [v any/c]) boolean?]

@defproc[(get-password [service-name string?]
                       [username string?]
                       [#:keyring keyring keyring? (default-keyring)])
         (or/c #f bytes?)]

@defproc[(set-password! [service-name string?]
                        [username string?]
                        [password bytes?]
                        [#:keyring keyring keyring? (default-keyring)])
         void?]

@defproc[(remove-password! [service-name string?]
                           [username string?]
                           [#:keyring keyring keyring? (default-keyring)])
         void?]

@defproc[(make-keyring-from-string [keyring-spec string?]) keyring?]{
  Constructs a keyring using the backend specified by the url string
  @racket[keyring-spec].  This procedure will raise an exception that
  passes @racket[keyring-backend-load-error?] if @racket[keyring-spec]
  is not a valid url or if the backend cannot be loaded.
}

@defparam[default-keyring keyring (or/c #f keyring?)]

@subsection{Exceptions}

@defproc[(keyring-error? [v any/c]) boolean?]

@defproc[(keyring-backend-error? [v any/c]) boolean?]

@defproc[(keyring-backend-error-name [e keyring-backend-error?])
         (or/c #f string?)]

@defproc[(keyring-backend-load-error? [v any/c]) boolean?]

@defproc[(keyring-backend-load-error-name [e keyring-backend-load-error?])
         (or/c #f string?)]

@section{Back End Interface}

@defmodule[keyring/interface]

@subsection{Back End Keyring Methods}

@defproc[(get-password [keyring keyring?]
                       [service-name string?]
                       [username string?])
         (or/c #f bytes?)]

@defproc[(set-password! [keyring keyring?]
                        [service-name string?]
                        [username string?]
                        [password bytes?])
         void?]

@defproc[(remove-password! [keyring keyring?]
                           [service-name string?]
                           [username string?])
         void?]

@subsection{Generic Keyring Interface}

@defidform[gen:keyring]

@defthing[prop:keyring struct-type-property?]

@definterface[keyring<%> ()]{
  @defmethod[(get-password
               [service-name string?]
               [username string?])
             (or/c #f bytes?)]
  @defmethod[(set-password!
               [service-name string?]
               [username string?]
               [password bytes?])
             void?]
  @defmethod[(remove-password!
               [service-name string?]
               [username string?])
             void?]
}
