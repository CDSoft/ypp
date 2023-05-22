# Yet a PreProcessor

[ypp]: http://cdelord.fr/ypp "Yet another PreProcessor"
[UPP]: http://cdelord.fr/upp "Universal PreProcessor"
[Panda]: http://cdelord.fr/panda "Pandoc add-ons (Lua filters for Pandoc)"
[Pandoc]: https://pandoc.org "A universal document converter"
[Typst]: https://typst.app/ "Compose papers faster"
[Lua]: http://www.lua.org/
[GitHub]: https://github.com/CDSoft/ypp
[cdelord.fr]: http://cdelord.fr
[GraphViz]: http://graphviz.org/
[PlantUML]: http://plantuml.sourceforge.net/
[ditaa]: http://ditaa.sourceforge.net/
[blockdiag]: http://blockdiag.com/
[Asymptote]: http://asymptote.sourceforge.net/
[mermaid]: https://mermaidjs.github.io/
[Pandoc Lua filter]: http://pandoc.org/lua-filters.html
[Python]: https://www.python.org/
[Lua]: http://www.lua.org/
[gnuplot]: http://www.gnuplot.info/
[lsvg]: http://cdelord.fr/lsvg/
[LuaX]: http://cdelord.fr/luax "Lua eXtended interpretor"
[LuaX documentation]: http://cdelord.fr/luax/luax.lua.html
[Octave]: https://octave.org/

`ypp` is yet another preprocessor. It's an attempt to merge [UPP] and [Panda].
It acts as a generic text preprocessor as [UPP] and comes with macros
reimplementing most of the [Panda] functionalities (i.e. [Panda] facilities not
restricted to [Pandoc] but also available to softwares like [Typst]).

Ypp is a minimalist and generic text preprocessor using Lua macros.

It provides several interesting features:

- full [Lua]/[LuaX] interpreter
- variable expansion (minimalistic templating)
- conditional blocks
- file inclusion (e.g. for source code examples)
- script execution (e.g. to include the result of a command)
- diagrams ([Graphviz], [PlantUML], [Asymptote], [blockdiag], [mermaid], [Octave], [lsvg], ...)
- documentation extraction (e.g. from comments in source files)

# Open source

[ypp] is an Open source software.
Anybody can contribute on [GitHub] to:

- suggest or add new features
- report or fix bugs
- improve the documentation
- add some nicer examples
- find new usages
- ...

# Installation

[ypp] requires [LuaX].

``` sh
$ git clone https://github.com/CDSoft/luax.git && make -C luax install
...

# install ypp in ~/.local/bin
$ git clone https://github.com/CDSoft/ypp.git && make -C ypp install
```

`make install` installs `ypp` in `~/.local/bin`.
The `PREFIX` variable can be defined to install `ypp` to a different directory
(e.g. `make install PREFIX=/usr` to install `ypp` in `/usr/bin`).

# Test

``` sh
$ make test
```

# Usage

```
@[[script.sh(os.getenv"BUILD".."/ypp -h") : gsub("ypp %d+.%d+[0-9a-g.-]*", "ypp")]]
```

# Documentation

?(false)

Lua expressions and chunks are embedded in the document to process.
Expressions are introduced by `@` and chunks by `@@`.
Several syntaxes are provided.

The first syntax is more generic and can execute any kind of Lua expression or chunk:

- `@(Lua expression)` or `@[===[ Lua expression ]===]`
- `@@(Lua chunk)` or `@@[===[ Lua chunk ]===]`

The second one can be used to read a variable or execute a Lua function:

- `@ident`: get the value of `ident` (which can be a field of a table. e.g. `@math.pi`)
- `@func(...)`, `@func{...}`, `@@func(...)`, `@@func{...}`
- `@func[===[ ... ]===]` or `@@func[===[ ... ]===]`
- `@func(...)[===[ ... ]===]` or `@@func(...)[===[ ... ]===]`
- `@func{...}[===[ ... ]===]` or `@@func{...}[===[ ... ]===]`

Note: the number or equal signs in long strings is variable, as in Lua long strings

The Lua code can be delimited with parentheses or long brackets.
The code delimited with parentheses shall only contain well-balanced parentheses.
The long bracket delimiters shall have the same number of equal signs (which can be null),
similarly to Lua literal strings

A macro is just a Lua function. Some macros are predefined by `ypp`. New macros
can be defined by loading Lua scripts (options `-l` and `-e`) or embedded as
Lua chunks.

Expression and chunks can return values. These values are formatted according
to their types:

- `__tostring` method from a custom metatable: if the value has a `__tostring`
  metamethod, it is used to format the value
- arrays (with no `__tostring` metamethod): items are concatenated (one line per item)
- other types are formatted by the default `tostring` function.

For documentation purpose, ypp macros can be enable/disabled with the special `?` macro:

?(true)
@@(function q(cond) return ("?(%s)"):format(cond) end)
- `@q(false)`: disable ypp
- `@q(true)`: enable ypp
?(false)

## Examples

### Lua expression

```
The user's home is @(os.getenv "HOME").

$\sum_{i=0}^100 = @(F.range(100):sum())$
```

### Lua chunk

```
@@[[
    local sum = 0
    for i = 1, 100 do
        sum = sum + i
    end
    return sum
]]

$\sum_{i=0}^100 = @sum$
```

?(true)

## Builtin ypp functions

@@[[
    function module(modname)
        return {
            "### `"..modname.."`",
            "",
            doc(fs.join("src", modname..".lua")),
        }
    end
]]

@(module "ypp")

## Builtin ypp modules

@(module "atexit")
@(module "convert")
@(module "doc")
@(module "image")
@(module "include")
@(module "script")
@(module "when")

## LuaX modules

ypp is written in [Lua] and [LuaX].
All Lua and LuaX libraries are available to ypp.

[LuaX] is a Lua interpretor and REPL based on Lua 5.4, augmented with some useful packages.

LuaX comes with a standard Lua interpretor and provides some libraries (embedded
in a single executable, no external dependency required).
Here are some LuaX modules that can be useful in ypp documents:

@@[===[
    luaxdoc = F.curry(function(name, descr)
        return ("[%s](https://github.com/CDSoft/luax/blob/master/doc/%s.md): %s"):format(name, name, descr)
    end)
]===]

- @[[luaxdoc "F"       "functional programming inspired functions"]]
- @[[luaxdoc "L"       "`pandoc.List` module from the Pandoc Lua interpreter"]]
- @[[luaxdoc "fs"      "file system management"]]
- @[[luaxdoc "sh"      "shell command execution"]]
- @[[luaxdoc "mathx"   "complete math library for Lua"]]
- @[[luaxdoc "imath"   "arbitrary precision integer and rational arithmetic library"]]
- @[[luaxdoc "qmath"   "rational number library"]]
- @[[luaxdoc "complex" "math library for complex numbers based on C99"]]
- @[[luaxdoc "crypt"   "cryptography module"]]
- @[[luaxdoc "lpeg"    "Parsing Expression Grammars For Lua"]]
- @[[luaxdoc "inspect" "Human-readable representation of Lua tables"]]
- @[[luaxdoc "serpent" "Lua serializer and pretty printer"]]

More information here: <http://cdelord.fr/luax>

# License

    Ypp is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ypp is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ypp.  If not, see <https://www.gnu.org/licenses/>.

    For further information about ypp you can visit
    http://cdelord.fr/ypp

Feedback
========

Your feedback and contributions are welcome.
You can contact me at [cdelord.fr].
