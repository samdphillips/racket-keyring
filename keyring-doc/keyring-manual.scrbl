#lang scribble/manual

@(require (for-label
            racket
            (only-in keyring
                     keyring?
                     default-keyring)))

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

@defproc[(make-keyring-from-string [keyring-spec string?]) keyring?]

@defparam[default-keyring keyring (or/c #f keyring?)]

@defstruct*[(exn:fail:keyring exn:fail) ()]
@defstruct*[(exn:fail:keyring:backend exn:fail:keyring) ()]
@defstruct*[(exn:fail:keyring:backend:load exn:fail:keyring:backend) ()]

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
  @defmethod[(get-password     [service-name string?] [username string?]) (or/c #f bytes?)]
  @defmethod[(set-password!    [service-name string?] [username string?] [password bytes?]) void?]
  @defmethod[(remove-password! [service-name string?] [username string?]) void?]
}
