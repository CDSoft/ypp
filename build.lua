section [[
This file is part of ypp.

ypp is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ypp is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ypp.  If not, see <https://www.gnu.org/licenses/>.

For further information about ypp you can visit
https://codeberg.org/cdsoft/ypp
]]

local F = require "F"

version "1.10.6"

help.name "ypp"
help.description "$name"

clean "$builddir"

---------------------------------------------------------------------
section "Compilation"
---------------------------------------------------------------------

local sources = {
    ls "src/*.lua",
    file "$builddir/_YPP_VERSION" { vars.version },
}

build.luax.add_global "flags" "-q"

local binaries = {
    build.luax.native "$builddir/ypp"            { sources },
    build.luax.lua    "$builddir/ypp.lua"        { sources },
    build.luax.pandoc "$builddir/ypp-pandoc.lua" { sources },
}

local ypp_luax = build.luax.luax "$builddir/ypp.luax" { sources }

phony "release" {
    build.tar "$builddir/release/${version}/ypp-${version}-lua.tar.gz" {
        base = "$builddir/release/.build",
        name = "ypp-${version}-lua",
        build.luax.lua("$builddir/release/.build/ypp-${version}-lua/bin/ypp.lua") { sources },
    },
    require "targets" : map(function(target)
        return build.tar("$builddir/release/${version}/ypp-${version}-"..target.name..".tar.gz") {
            base = "$builddir/release/.build",
            name = "ypp-${version}-"..target.name,
            build.luax[target.name]("$builddir/release/.build/ypp-${version}-"..target.name/"bin/ypp") { sources },
        }
    end),
}

---------------------------------------------------------------------
section "Documentation"
---------------------------------------------------------------------

build "README.md" {
    description = "PANDOC $out",
    command = {
        "pandoc --to gfm $in -o $out",
        "--fail-if-warnings",
        "--lua-filter doc/fix_links.lua",
    },
    implicit_in = "doc/fix_links.lua",

    build "$builddir/doc/README.md" { "doc/ypp.md",
        description = "YPP $in",
        command = {
            "export BUILD=$builddir;",
            "$builddir/ypp",
                "-t svg",
                "--MF $depfile",
                "$in",
                "-o $out",
                "--img [doc/]img",
                "--meta $builddir/doc",
        },
        depfile = "$out.d",
        implicit_in = {
            "$builddir/ypp",
        },
    },
}

---------------------------------------------------------------------
section "Tests"
---------------------------------------------------------------------

rule "diff" {
    description = "DIFF $in",
    command = "diff $in > $out || (cat $out && false)",
}

local tests = {
    build "$builddir/test/test.md" { "test/test.md",
        description = "YPP $in",
        command = {
            "export BUILD=$builddir;",
            "export YPP_IMG=[$builddir/test/]ypp_images;",
            "$builddir/ypp-pandoc.lua",
                "-t svg",
                "--MF $depfile",
                "-p", "test",
                "-l", "test.lua",
                "-l", "mod1",
                "-l", "mymod=mod2",
                "-l", "_=mod3",
                "-e", "'VAR1 = 2 * 3 * 7'",
                "-e", "'VAR2 = [[43]]'",
                "-DVAR3=44",
                "-DVAR4=val4",
                "-DVAR5=",
                "-DVAR6",
                "$in",
                "-o $out",
        },
        depfile = "$out.d",
        implicit_in = {
            "$builddir/ypp-pandoc.lua",
        },
        implicit_out = {
            "$builddir/test/test.md.d",
            "$builddir/test/test-file.txt",
            -- Images meta files are not touched when their contents are not changed
            -- Ninja will consider them as always dirty => "ninja test" may always have something to do
            -- This is for test purpose only. In normal usage, meta files are internal files, not output files.
            "$builddir/test/ypp_images/hello.svg.meta",
        },
        validations = F{
            { "$builddir/test/test.md", "test/test-ref.md" },
            { "$builddir/test/test.md.d", "test/test-ref.d" },
            { "$builddir/test/test-file.txt", "test/test-file.txt" },
            { "$builddir/test/ypp_images/hello.svg.meta", "test/hello.svg.meta" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
    build "$builddir/test/test123-no-separator.md" { "test/test1.md", "test/test2.md", "test/test3.md",
        description = "YPP $in",
        command = {
            "$builddir/ypp",
                "--MF $depfile",
                "$in",
                "-o $out",
        },
        depfile = "$out.d",
        implicit_in = {
            "$builddir/ypp",
        },
        implicit_out = {
            "$builddir/test/test123-no-separator.md.d",
        },
        validations = F{
            { "$builddir/test/test123-no-separator.md", "test/test123-no-separator-ref.md" },
            { "$builddir/test/test123-no-separator.md.d", "test/test123-no-separator-ref.d" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
    build "$builddir/test/test123-separator.md" { "test/test1.md", "test/test2.md", "test/test3.md",
        description = "YPP $in",
        command = {
            "$builddir/ypp",
                "--MF $depfile",
                "$in",
                "-o $out",
                "-s",
        },
        depfile = "$out.d",
        implicit_in = {
            "$builddir/ypp",
        },
        implicit_out = {
            "$builddir/test/test123-separator.md.d",
        },
        validations = F{
            { "$builddir/test/test123-separator.md", "test/test123-separator-ref.md" },
            { "$builddir/test/test123-separator.md.d", "test/test123-separator-ref.d" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
    build "$builddir/test/test-error.err" { "test/test-error.md",
        description = "YPP $in",
        command = {
            "$builddir/ypp.lua",
                "-p", "test",
                "-l", "test.lua",
                "$in",
                "2> $out",
                ";",
            "test $$? -ne 0",
        },
        implicit_in = {
            "$builddir/ypp.lua",
        },
        validations = F{
            { "$builddir/test/test-error.err", "test/test-error-ref.err" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
    build "$builddir/test/test-error-color.err" { "test/test-error.md",
        description = "YPP $in",
        command = {
            "$builddir/ypp.lua",
                "-a",
                "-p", "test",
                "-l", "test.lua",
                "$in",
                "2> $out",
                ";",
            "test $$? -ne 0",
        },
        implicit_in = {
            "$builddir/ypp.lua",
        },
        validations = F{
            { "$builddir/test/test-error-color.err", "test/test-error-color-ref.err" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
    build "$builddir/test/test-syntax-error.err" { "test/test-syntax-error.md",
        description = "YPP $in",
        command = {
            "$builddir/ypp.lua",
                "$in",
                "2> $out",
                ";",
            "test $$? -ne 0",
        },
        implicit_in = {
            "$builddir/ypp.lua",
        },
        validations = F{
            { "$builddir/test/test-syntax-error.err", "test/test-syntax-error-ref.err" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
    build "$builddir/test/test-syntax-error-color.err" { "test/test-syntax-error.md",
        description = "YPP $in",
        command = {
            "$builddir/ypp.lua",
                "-a",
                "$in",
                "2> $out",
                ";",
            "test $$? -ne 0",
        },
        implicit_in = {
            "$builddir/ypp.lua",
        },
        validations = F{
            { "$builddir/test/test-syntax-error-color.err", "test/test-syntax-error-color-ref.err" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end),
    },
}

---------------------------------------------------------------------
section "Shortcuts"
---------------------------------------------------------------------

help "compile" "Compile $name"
phony "compile" { binaries, ypp_luax }
default "compile"

help "doc" "Generate README.md"
phony "doc" { "README.md" }

help "test" "Run $name tests"
phony "test" (tests)

help "all" "Compile $name, run test and generate doc"
phony "all" { "compile", "test", "doc" }

install "bin" (binaries)
