--[[
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
--]]

--@MAIN

--[[@@@
* `ypp(s)`: apply the `ypp` preprocessor to a string.
* `ypp.input_file()`: return the name of the current input file.
* `ypp.input_path()`: return the path of the current input file.
* `ypp.input_file(n)`: return the name of the nth input file in the current *include* stack.
* `ypp.input_path(n)`: return the path of the nth input file in the current *include* stack.
@@@]]

-- preload some LuaX modules
F = require "F"
crypt = require "crypt"
fs = require "fs"
sh = require "sh"
sys = require "sys"

local F = require "F"
local fs = require "fs"

local ypp_mt = {__index={}}
local ypp = setmetatable({}, ypp_mt)
local known_input_files = F{}
local output_contents = F{}
local input_files = F{fs.join(fs.getcwd(), "-")} -- stack of input files (current branch from the root to the deepest included document)

local function die(msg, ...)
    io.stderr:write("ypp: ", msg:format(...), "\n")
    os.exit(1)
end

local function load_script(filename)
    local modname = filename:gsub("%.lua$", "")
    _G[modname] = require(modname)
end

local function eval_expr(expr)
    assert(load(expr, expr, "t"))()
end

local function add_path(paths)
    if not paths then return end
    local dir_sep, template_sep, template, _ = F(package.config):lines():unpack()
    package.path = F.concat {
        paths:split(template_sep):map(function(path) return path..dir_sep..template..".lua" end),
        { package.path }
    } : str(template_sep)
end

local function process(content)
    output_contents[#output_contents+1] = ypp(content)
end

local function read_file(filename)
    local content
    if filename == "-" then
        content = io.stdin:read "a"
    else
        content = assert(fs.read(filename))
        known_input_files[#known_input_files+1] = filename:gsub("^"..fs.getcwd()..fs.sep, "")
    end
    return content
end

ypp.read_file = read_file

local function find_file(filename)
    local current_input_file = input_files:last()
    local input_path = fs.dirname(current_input_file)
    local full_filepath = F{
        fs.join(input_path, filename),
        filename,
    } : filter(fs.is_file) : head()
    assert(full_filepath, filename..": file not found")
    return full_filepath
end

ypp.find_file = find_file

local function with_inputfile(filename, func)
    if filename == "-" then return func(filename) end
    local full_filepath = find_file(filename)
    input_files[#input_files+1] = full_filepath
    local res = {func(full_filepath)}
    input_files[#input_files] = nil
    return F.unpack(res)
end

ypp.with_inputfile = with_inputfile

local function process_file(filename)
    return with_inputfile(filename, function(full_filepath)
        return process(read_file(full_filepath))
    end)
end

function ypp.input_file(level)
    return input_files[#input_files-(level or 0)]
end

function ypp.input_path(level)
    return fs.dirname(input_files[#input_files-(level or 0)])
end

function ypp_mt.__call(_, content)
    if type(content) == "table" then return F.map(ypp, content) end
    local parser = require "parser"
    return parser(content)
end

local function write_outputs(args)
    local content = output_contents:unlines()
    if not args.output or args.output == "-" then
        io.stdout:write(content)
    else
        fs.write(args.output, content)
    end
end

local function write_dep_file(args)
    if not args.gendep then return end
    local name = args.depfile or (args.output and fs.splitext(args.output)..".d")
    if not name then die("The dependency file name is unknown, use --MF or -o") end
    local function mklist(...)
        return F{...}:flatten():from_set(F.const(true)):keys()
            :filter(function(p) return p ~= "-" end)
            :map(function(p) return p:gsub("^%."..fs.sep, "") end)
            :sort()
            :unwords()
    end
    local scripts = F.keys(package.loaded)
        : map(function(modname) return package.searchpath(modname, package.path) or false end)
        : filter(function(path) return path end)
    local deps = mklist(args.targets, args.output or {}).." : "..mklist(known_input_files, scripts)
    fs.write(name, deps.."\n")
end

local function parse_args()
    local parser = require "argparse"()
        : name "ypp"
        : description(("ypp %s\nYet a PreProcessor"):format(_YPP_VERSION))
        : epilog "For more information, see https://github.com/CDSoft/ypp"

    parser : flag "-v"
        : description "Show yyp version"
        : action(function(_, _, _, _) print(_YPP_VERSION); os.exit() end)

    parser : option "-l"
        : description "Execute a Lua script"
        : argname "script"
        : count "*"
        : action(function(_, _, name, _) load_script(name) end)

    parser : option "-e"
        : description "Execute a Lua expression"
        : argname "expression"
        : count "*"
        : action(function(_, _, expr, _) eval_expr(expr) end)

    parser : option "-p"
        : description "Add a path to package.path"
        : argname "path"
        : count "*"
        : action(function(_, _, path, _) add_path(path) end)

    local output = nil
    parser : option "-o"
        : description "Redirect the output to 'file'"
        : target "output"
        : argname "file"
        : action(function(_, _, path, _)
            output = path
            require"image".output(output)
        end)

    parser : option "-t"
        : description "Set the default format of generated images"
        : target "image_format"
        : choices { "svg", "pdf", "png" }
        : action(function(_, _, fmt, _) require"image".format(fmt) end)

    parser : option "--MT"
        : description "Add `name` to the target list (see `--MD`)"
        : target "targets"
        : argname "target"
        : count "*"

    parser : option "--MF"
        : description "Set the dependency file name"
        : target "depfile"
        : argname "name"

    parser : flag "--MD"
        : description "Generate a dependency file"
        : target "gendep"

    parser : argument "input"
        : description "Input file"
        : args "*"
        : action(function(_, _, names, _)
            if #names == 0 then names = {"-"} end
            F.map(process_file, names)
        end)

    return F.patch(parser:parse(), {output=output})
end

_ENV.ypp = ypp
local args = parse_args()
require "atexit".run()
write_dep_file(args)
write_outputs(args)
