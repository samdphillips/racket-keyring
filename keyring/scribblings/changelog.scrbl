#lang scribble/manual

@(require (for-label racket racket/generic keyring/interface))

@title{Changelog}

@section{0.11}
Release date: 2023/10/31
@itemlist[
  @item{Move tests into separate packages.}
  @item{Reorganize the backends around @racket[prop:keyring]}
  @item{Clean up error message formatting.}
  @item{Log errors from raise procedures.}
  @item{Add @var{null} backend as default when the @envvar{KEYRING}
        environment variable is not set.}]

@section{0.10.1}
Release date: 2022/11/09
@itemlist[
  @item{Add license metadata to packages.}
  @item{Regular Github Actions testing setup.}
  @item{Logging changes.}]

@section{0.10.0}
Release date: 2021/04/18
@itemlist[
  @item{Code cleanups.}
  @item{Logging improvements.}]

@section{0.9.0}
Release date: 2021/02/26
@itemlist[
  @item{A raco command for accessing the keyrings.}
  @item{
    A backend system that works with @racketlink[class]{classes},
    @racketlink[define-generics]{generics}, or plain
    @racketlink[struct]{structs}.}
  @item{Implemented Backends
    @itemlist[
      @item{Mac OSX Keychain backend}
      @item{Secret Service backend}
      @item{environment variable backend}
      @item{get-pass backend}]}
  @item{Environment based configuration}]
