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

help.name "ypp"
help.description "$name"

var "builddir" ".build"
clean "$builddir"

---------------------------------------------------------------------
section "Compilation"
---------------------------------------------------------------------

local targets = F(require "sys".targets):map(F.partial(F.nth, "name"))
local target, ext = nil, ""
F(arg) : foreach(function(a)
    if targets:elem(a) then
        if target then F.error_without_stack_trace("multiple target definition", 2) end
        target = a
        if target:match"windows" then ext = ".exe" end
    else
        F.error_without_stack_trace(a..": unknown argument")
    end
end)

local sources = {
    ls "src/*.lua",
    "$builddir/src/_YPP_VERSION.lua",
}

rule "luax" {
    description = "LUAX $out",
    command = "luax -q $args -o $out $in" ,
}

rule "luaxc" {
    description = "LUAXC $out",
    command = "luaxc $arg -q -o $out $in",
}

local compile = {
    build("$builddir/ypp"..ext) {
        "luaxc",
        sources,
        arg = target and {"-t", target},
    },
    build "$builddir/ypp.lua"         { "luax", sources, args="-t lua" },
    build "$builddir/ypp-pandoc.lua"  { "luax", sources, args="-t pandoc" },
}

build "$builddir/src/_YPP_VERSION.lua" {
    description = "VERSION $out",
    command = [=[echo "return [[$$(git describe --tags)]] --@LOAD" > $out]=],
    implicit_in = { ".git/refs/tags", ".git/index" },
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
                "--MD",
                "-p", "test",
                "-l", "test.lua",
                "$in",
                "-o $out",
        },
        depfile = "$builddir/test/test.d",
        implicit_in = {
            "$builddir/ypp-pandoc.lua",
        },
        implicit_out = {
            "$builddir/test/test.d",
            "$builddir/test/ypp_images/hello.svg.meta",
        },
        validations = F{
            { "$builddir/test/test.md", "test/test_ref.md" },
            { "$builddir/test/test.d", "test/test_ref.d" },
            { "$builddir/test/ypp_images/hello.svg.meta", "test/hello.svg.meta" },
        } : map(function(files)
            return build(files[1]..".diff") { "diff", files }
        end)
    },
}

---------------------------------------------------------------------
section "Shortcuts"
---------------------------------------------------------------------

help "compile" "Compile $name"
phony "compile" (compile)

help "all" "Compile $name"
phony "all" { "compile" }

help "install" "Install $name"
install "bin" (compile)

if not target then
help "doc" "Generate README.md"
phony "doc" { "README.md" }

help "test" "Run $name tests"
phony "test" (tests)
end

default "compile"
