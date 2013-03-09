NiJS: An internal DSL for Nix in JavaScript
===========================================
Many programming language environments provide their own language specific
package manager, implementing features that are already well supported by
generic ones. This package is a response to that phenomenon.

This package contains a library and command-line utility providing an internal
DSL for the [Nix package manager](http://nixos.org/nix) in JavaScript. Nix is a
generic package manager that borrows concepts from purely functional programming
languages to make deployment reliable, reproducible and efficient. It serves as
the basis of the [NixOS](http://nixos.org/nixos) Linux distribution, but it can
also be used seperately on regular Linux distributions, FreeBSD, Mac OS X and
Windows (through Cygwin).

The internal JavaScript DSL makes it possible for developers to convienently
perform deployment operations, such as building, upgrading and installing
packages with the Nix package manager from JavaScript programs. Moreover,
it offers a number of additional features.

Prerequisites
=============
* In order to use the components in this package, a [Node.js](http://nodejs.org) installation is required.
* To use the `nijs-build` command-line utility, we require the [optparse](https://github.com/jfd/optparse-js) library to be installed either through Nix or NPM
* Of course, since this package provides a feature for Nix, we require the [Nix package manager](http://nixos.org/nix) to be installed

Installation
============
To install this package, either the NPM package manager or the Nix package
manager can be used.

In order to be able to use the `nijsFunProxy` function from Nix expressions, it
would be useful to add the following value to the `NIX_PATH` environment variable
in your shell's profile, e.g. `~/.profile`:

    $ export NIX_PATH=$NIX_PATH:nijs=/path/to/nijs/lib

Usage
=====
This package offers a number of interesting features.

Calling a Nix function from JavaScript
--------------------------------------
The most important use case of this package is to be able to call Nix functions
from JavaScript. To call a Nix function, we must create a simple proxy that
translates the JavaScript function call to a string with a Nix function call.
The `nixToJS()` function is very useful for this purpose -- it takes a
JavaScript object and translates these to Nix expression language objects.

The following code fragment demonstrates a JavaScript function proxy that
proxies a call to the `stdenv.mkDerivation` function in Nix:

    var nijs = require('nijs');

    function mkDerivation(args) {
        return new nijs.NixExpression("pkgs.stdenv.mkDerivation "+nijs.jsToNix(args));
    }

As can be observed, a function proxy has a very simple structure. It always
returns an object instance of the `NixExpression` prototype with a value
representing a string that contains a generated Nix expression. To generate a
function call, we have to provide the function name and the arguments. The
arguments can be generated automatically by converting the arguments of the
JavaScript function (which are JavaScript objects) to Nix language objects by
using the `jsToNix()` function.

Specifying packages
-------------------
The `stdenv.mkDerivation` is a very important function in Nix. It's directly and
indirectly used by nearly every package specification to perform a build from
source code. In the `tests/` folder, we have defined a packages repository:
`pkgs.js` that provides a proxy to this function.

By using this proxy we can also describe our own package specifications in
JavaScript, instead of the Nix expression language. Every package build recipe
can be written as a CommonJS module, that may look as follows:

    var nijs = require('nijs');

    exports.pkg = function(args) {
      return args.stdenv().mkDerivation ({
        name : "hello-2.8",
    
        src : args.fetchurl({
          url : new nijs.NixURL("mirror://gnu/hello/hello-2.8.tar.gz"),
          sha256 : "0wqd8sjmxfskrflaxywc7gqw7sfawrfvdxd9skxawzfgyy0pzdz6"
        }),
  
        doCheck : true,

        meta : {
          description : "A program that produces a familiar, friendly greeting",
          homepage : new nijs.NixURL("http://www.gnu.org/software/hello/manual"),
          license : "GPLv3+"
        }
      });
    };

A package module exports the `pkg` property, which refers to a function
definition taking the build-time dependencies of the package as argument object.
In the body of the function, we return the result of an invocation to the
`mkDerivation()` function that builds a package from source code. To this
function we pass essential build parameters, such as the URL from which the
source code can be obtained.

Nix has special types for URLs and files to check whether they are in the valid
format and that they are automatically imported into the Nix store for purity.
As they are not in the JavaScript language, we can artificially create them
through objects that are instances of the `NixFile` and `NixURL` prototypes.


Composing packages
------------------
As with ordinary Nix expressions, we cannot use this CommonJS module to build a
package directly. We have to *compose* it by calling it with its required
function arguments. Composition is done in the composition module: `pkgs.js` in
the `tests/` folder. The structure of this file is as follows:

    var pkgs = {

      stdenv : function() {
        return require('./pkgs/stdenv.js').pkg;
      },

      fetchurl : function(args) {
        return require('./pkgs/fetchurl.js').pkg(args);
      },

      hello : function() {
        return require('./pkgs/hello.js').pkg({
          stdenv : pkgs.stdenv,
          fetchurl : pkgs.fetchurl
        });
      },
  
      ...
    };

    exports.pkgs = pkgs;

The above module exports the `pkgs` property that refers to an object in which
each member refers to a function definition. These functions call the package
modules with its required parameters. By evaluating these functions, a Nix
expression gets generated that can be built by the Nix package manager.

Building packages programmatically
----------------------------------
The `callNixBuild()` function can be used to build a generated Nix expression:

    var nijs = require('nijs');
    var pkgs = require('pkgs.js').pkgs;

    nijs.callNixBuild({
      nixObject : pkgs.hello(),
      params : [],
      onSuccess : function(result) {
        process.stdout.write(result + "\n");
      },
      onFailure : function(code) {
        process.exit(code);
      }
    });

In the code fragment above we call the `callNixBuild` function, in which we
evaluate the hello package that gets built asynchronously by Nix. The
`onSuccess()` callback function is called when the build succeeds with the
resulting Nix store path as function parameter. The store path is printed on the
standard output. If the build fails, the `onFailure()` callback function is
called with the non-zero exit status code as parameter.

Building packages through a command-line utility
------------------------------------------------
As the previous code example is so common, there is also a command-line utility
that can do the same. The following instruction builds the hello package from the
composition module (`pkgs.js`):

    $ nijs-build pkgs.js -A hello

It may also be useful to see what kind of Nix expression is generated for
debugging or testing purposes. The `--eval-only` option prints the generated
Nix expression on the standard output:

    $ nijs-build pkgs.js -A hello --eval-only

Calling JavaScript functions from Nix expressions
-------------------------------------------------
Another use case of NiJS is to call JavaScript functions from Nix expressions.
This can be done by using the `nijsFunProxy` Nix function. The following code
fragment shows a Nix expression using the `sum()` JavaScript function to add two
integers and writes the result to a text file in the Nix store:

    {stdenv, nodejs}:

    let
      nijsFunProxy = import <nijs/funProxy.nix> {
        inherit stdenv nodejs;
      };
    
      sum = a: b: nijsFunProxy {
        function = ''
          function sum(a, b) {
            return a + b;
          }
        '';
        args = [ a b ];
      };
    in
    stdenv.mkDerivation {
      name = "sum";
  
      buildCommand = ''
        echo ${toString (sum 1 2)} > $out
      '';
    }

As can be observed, the `nijsFunProxy` is a very thin layer that propagates the
Nix function parameters to the JavaScript function (Nix objects are converted to
JavaScript object) and the resulting JavaScript object is translated back to a
Nix expression.

JavaScript function calls have a number of caveats that a developer should take
in mind:

* We cannot use variables outside the scope of the function, e.g. global variables.
* We must always return something. If nothing is returned, we will have an undefined object, which cannot be converted.
* Functions with a variable number of positional arguments are not supported, as Nix functions don't support this.

Using CommonJS modules in embedded JavaScript functions
-------------------------------------------------------
It may be very annoying to only use self contained JavaScript code fragments, as
we cannot access anything outside the function's scope. Fortunately, the
`nijsFunProxy` can also take Node packages through Nix as parameters and make
them available to that function. The following code fragment uses the [Underscore](http://underscorejs.org)
library to convert a list of integers to a list of strings:

    {stdenv, nodejs, underscore}:

    let
      nijsFunProxy = import <nijs/funProxy.nix> {
        inherit stdenv nodejs;
      };
      
      underscoreTestFun = numbers: nijsFunProxy {
        function = ''
          function underscoreTestFun(numbers) {
            var words = [ "one", "two", "three", "four", "five" ];
            var result = [];
          
            _.each(numbers, function(elem) {
              result.push(words[elem - 1]);
            });
        
            return result;
          }
        '';
        args = [ numbers ];
        modules = [ underscore ];
        requires = [
          { var = "_"; module = "underscore"; }
        ];
      };
    in
    stdenv.mkDerivation {
      name = "underscoreTest";
  
      buildCommand = ''
        echo ${toString (underscoreTestFun [ 5 4 3 2 1 ])} > $out
      '';
    }

The `modules` parameter is a list of Node.JS packages (provided through Nixpkgs)
and the `require` parameter is a list taking var and module pairs. The latter
parameter is used to automatically generate a collection of require statements.
In this case, it adds the following line before the function definition:

    var _ = require('underscore');

Calling asynchronous JavaScript functions from Nix expressions
--------------------------------------------------------------
In Node.js, most of the standard utility functions are *asynchronous*, which
will return immediately, and invoke a callback function when the task is done.
To allow these functions to be used inside a Nix expression, we must set the
`async` parameter to true in the `nijsFunProxy`. Furthermore, instead of
returning an object, we must call the `nijsCallbacks.onSuccess()` function in
case of success or the `nijsCallbacks.onFailure()` function in case of a failure.

The following example uses a timer that calls the success callback function
after three seconds, with a standard greeting message:

    {stdenv, nodejs}:
    
    let
      nijsFunProxy = import <nijs/funProxy.nix> {
        inherit stdenv nodejs;
      };
      
      timerTest = message: nijsFunProxy {
        function = ''
          function timerTest(message) {
            setTimeout(function() {
              nijsCallbacks.onSuccess(message);
            }, 3000);
          }
        '';
        args = [ message ];
        async = true;
      };
    in
    stdenv.mkDerivation {
      name = "timerTest";
  
      buildCommand = ''
        echo ${timerTest "Hello world! The timer test works!"} > $out
      '';
    }

Writing inline JavaScript code in Nix expressions
-------------------------------------------------
All the examples so far use generic building procedures or refer to JavaScript
functions that expose themselves as Nix functions. Sometimes it may also be
required to implement a custom build procedure for a package. Nix uses the Bash
shell as its default builder, hence it requires developers to implement custom
build steps as shell code embedded in strings.

It may also be desired to implement custom build procedure steps as embedded
JavaScript code, instead of embedded shell code. The `nijsInlineProxy` function
allows a developer to write inline JavaScript code inside a Nix expression:

    {stdenv}:

    let
      nijsInlineProxy = import <nijs/inlineProxy.nix> {
        inherit stdenv writeTextFile nodejs;
      };
    in
    stdenv.mkDerivation {
      name = "createFileWithMessage";
      buildCommand = nijsInlineProxy {
        requires = [
          { var = "fs"; module = "fs"; }
          { var = "path"; module = "path"; }
        ];
        code = ''
          fs.mkdirSync(process.env['out']);
          var message = "Hello world written through inline JavaScript!";
          fs.writeFileSync(path.join(process.env['out'], "message.txt"), message);
        '';
      };
    }

The above example Nix expression implements a custom build procedure that
creates a Nix component containing a file named `message.txt` with a standard
greeting message. As you may see, instead of providing a custom `buildCommand`
that contains shell code we invoke the `nijsInlineProxy` that uses two CommonJS
modules. The code implements our custom build procedure in JavaScript.

As with ordinary Nix expressions, the parameters passed to `stdenv.mkDerivation`
and its generic properties are accessible as environment variables inside the
builder. In our example, `process.env['out']` is an environment variable
containing the Nix store output path of our package.

The `nijsInlineProxy` has the same limitations as the `nijsFunProxy`, such as the
fact that global variables cannot be accessed. Moreover, like the `nijsFunProxy`
it can also take the `modules` parameter allowing one to utilise external node.js
packages.

Writing inline JavaScript code in a NiJS package specification
--------------------------------------------------------------
When implementing a custom build procedure in a NiJS package module, we may also
run into the same inconvenience of having to embed custom build steps as shell
code embedded in strings. We can also use the `nijsInlineProxy` from a NiJS
package module, by creating an object that is an instance of the `NixInlineJS`
prototype:

    var nijs = require('nijs');

    exports.pkg = function(args) {
      return args.stdenv().mkDerivation ({
        name : "createFileWithMessageTest",
        buildCommand : new nijs.NixInlineJS({
          requires : [
            { "var" : "fs", "module" : "fs" },
            { "var" : "path", "module" : "path" }
          ],
          code : function() {
            fs.mkdirSync(process.env['out']);
            var message = "Hello world written through inline JavaScript!";
            fs.writeFileSync(path.join(process.env['out'], "message.txt"), message);
          }
        })
      });
    };

The above NiJS package module shows the NiJS equivalent of our first Nix
expression example containing inline JavaScript code.

The `buildCommand` parameter is bound to an instance of the `NixInlineJS`
prototype. The `code` parameter can be either a JavaScript function (that takes
no parameters) or a string that contains embedded JavaScript code. The
former case (the function approach) has the advantage that its syntax can be
checked or visualised by an editor, interpreter or compiler.

Examples
========
The `tests/` directory contains a number of interesting example cases:

* `pkgs.js` is a composition module containing a collection of NiJS packages
* `proxytests.nix` is a composition Nix expression containing a collection of JavaScript function invocations from Nix expressions

API documentation
=================
This package includes API documentation, which can be generated with
[JSDuck](https://github.com/senchalabs/jsduck). The Makefile in this package
contains a `duck` target to generate it and produces the HTML files in `build/`:

    $ make duck

License
=======
The contents of this package is available under the [MIT license](http://opensource.org/licenses/MIT)
