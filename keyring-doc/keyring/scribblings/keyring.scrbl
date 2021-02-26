#lang scribble/manual

@(require racket/format
          (for-label
            racket
            (except-in keyring
              get-password
              set-password!
              delete-password!)))

@(define (pkglink pkg-name)
   (link #:style "RktSym"
         (~a "https://pkgd.racket-lang.org/pkgn/package/" pkg-name)
         pkg-name))

@title{keyring - a library for uniformly accessing secrets}
@author[(author+email "Sam Phillips" "samdphillips@gmail.com")]

The @racket[keyring] library is a library to access various password
stores in a uniform way.  It is based loosely on the
@link["https://github.com/jaraco/keyring"]{Python keyring library}.

The base library contains a basic environment variable based backend.
Additionally there are other backends that interface with other secret
stores which can be installed.
@itemlist[
  @item{@pkglink{keyring-secret-service-lib} -
    @link["https://specifications.freedesktop.org/secret-service/latest/"]{
      Freedesktop Secret Service
    }, used on Linux desktop}

  @item{@pkglink{keyring-keychain-lib} -
    @link["https://en.wikipedia.org/wiki/Keychain_%28software%29"]{Mac OSX Keychain}
  }

  @item{
    @elem[#:style "RktSym"]{keyring-credential-locker-lib} -
    @link["https://docs.microsoft.com/en-us/windows/uwp/security/credential-locker"]{
      Windows Credential Locker} backend (TBD)}

  @item{@pkglink{keyring-get-pass-lib} -
    backend that prompts the user on the console for a password using
    @other-doc['(lib "get-pass/scribblings/get-pass.scrbl")
               #:indirect "get-pass library"].
  }
]


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

@defparam[default-keyring keyring (or/c #f keyring?)]{
  The default keyring to use.  When the @racket[keyring] module is
  loaded it reads the @envvar{KEYRING} environment variable and
  applies @racket[make-keyring-from-string] to the value and sets
  @racket[default-keyring] to the result.
}

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
