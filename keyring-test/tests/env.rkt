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
  (require keyring
           rackunit)

  (parameterize ([current-environment-variables
                  (make-environment-variables
                   #"SECRET_foo_bar1" #"baz1"
                   #"SECRET_foo_bar2" #"baz2"
                   #"SECRET_bar" #"baz")])
    (with-keyring "env://?prefix=SECRET"
      (check-equal? (get-password "foo" "bar1") #"baz1")
      (check-false  (get-password "foo" "oops"))

      (check-equal? (get-password "" "bar") #"baz")

      (set-password! "foo" "bar3" #"baz3")
      (check-equal? (get-password "foo" "bar3") #"baz3")

      (delete-password! "foo" "bar3")
      (check-false (get-password "foo" "bar3")))))
