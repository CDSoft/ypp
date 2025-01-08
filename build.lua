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
http://cdelord.fr/ypp
]]

local F = require "F"
local sys = require "sys"

help.name "ypp"
help.description "$name"

local target, args = target(arg)
if #args > 0 then
    F.error_without_stack_trace(args:unwords()..": unexpected arguments")
end

var "builddir" (".build"/(target and target.name))
clean "$builddir"

---------------------------------------------------------------------
section "Compilation"
---------------------------------------------------------------------

local sources = {
    ls "src/*.lua",
    build "$builddir/_YPP_VERSION" {
        description = "VERSION $out",
        command = "git describe --tags > $out",
        implicit_in = { ".git/refs/tags", ".git/index" },
    },
}

build.luax.add_global "flags" "-q"

local binaries = {
    build.luax[target and target.name or "native"]("$builddir/ypp"..(target or sys).exe) { sources },
    build.luax.lua    "$builddir/ypp.lua"        { sources },
    build.luax.pandoc "$builddir/ypp-pandoc.lua" { sources },
}

local ypp_luax = build.luax.luax "$builddir/ypp.luax" { sources }

require "build-release" {
    name = "ypp",
    sources = sources,
}

---------------------------------------------------------------------
section "Documentation"
---------------------------------------------------------------------

build "README.md" {
    description = "PANDOC $out",
    command = "pandoc --to gfm $in -o $out",

    build "$builddir/doc/README.md" { "doc/ypp.md",
        description = "YPP $in",
        command = {
            "export BUILD=$builddir;",
            "export YPP_IMG=doc/img;",
            "$builddir/ypp",
                "-t svg",
                "--MF $depfile",
                "$in",
                "-o $out",
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
                "--MF $out.d",
                "-p", "test",
                "-l", "test.lua",
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

if target then

    help "all" "Compile $name"
    phony "all" { "compile" }

else

    help "doc" "Generate README.md"
    phony "doc" { "README.md" }

    help "test" "Run $name tests"
    phony "test" (tests)

    help "all" "Compile $name, run test and generate doc"
    phony "all" { "compile", "test", "doc" }

end

install "bin" (binaries)
