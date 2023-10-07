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

help.name "ypp"
help.description "$name"

var "builddir" ".build"
clean "$builddir"

---------------------------------------------------------------------
section "Compilation"
---------------------------------------------------------------------

local sources = {
    ls "src/*.lua",
    "$builddir/src/_YPP_VERSION.lua",
}

rule "luax" { command = "luax -q $args -o $out $in" }

local compile = {
    build "$builddir/ypp"           { "luax", sources },
    build "$builddir/ypp-luax"      { "luax", sources, args="-t luax" },
    build "$builddir/ypp-lua"       { "luax", sources, args="-t lua" },
    build "$builddir/ypp-pandoc"    { "luax", sources, args="-t pandoc" },
}

build "$builddir/src/_YPP_VERSION.lua" {
    command = [=[echo "return [[$$(git describe --tags)]] --@LOAD" > $out]=],
    implicit_in = { ".git/refs/tags", ".git/index" },
}

---------------------------------------------------------------------
section "Documentation"
---------------------------------------------------------------------

build "README.md" {
    command = "pandoc --to gfm $in -o $out",

    build "$builddir/doc/README.md" { "doc/ypp.md",
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

rule "diff" { command = "diff $in > $out || (cat $out && false)" }

local tests = {
    build "$builddir/test/test.md" { "test/test.md",
        command = {
            "export BUILD=$builddir;",
            "export YPP_IMG=[$builddir/test/]ypp_images;",
            "$builddir/ypp-pandoc",
                "-t svg",
                "--MD",
                "-p", "test",
                "-l", "test.lua",
                "$in",
                "-o $out",
        },
        depfile = "$builddir/test/test.d",
        implicit_in = {
            "$builddir/ypp-pandoc",
        },
        implicit_out = {
            "$builddir/test/test.d",
        },
        validations = {
            build "$builddir/test/test.diff"   { "diff", "$builddir/test/test.md", "test/test_ref.md" },
            build "$builddir/test/test.d.diff" { "diff", "$builddir/test/test.d",  "test/test_ref.d" },
        },
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

help "doc" "Generate README.md"
phony "doc" { "README.md" }

help "test" "Run $name tests"
phony "test" (tests)

default "compile"
