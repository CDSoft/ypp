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
* `ypp.output_file`: name of the output file.
* `ypp.find_file(filename)`: return the full path name of `filename` that can be in the current input file directory or in the current directory.
* `ypp.read_file(filename)`: return the content of the file `filename` and adds this file to the dependency file.
* `ypp.macro(c)`: use the character `c` to start Lua expressions instead of `"@"` (and `cc` instead of `"@@"`).
@@@]]

local F = require "F"
local fs = require "fs"
local term = require "term"

-- preload some LuaX modules
_G.F = F
_G.crypt = require "crypt"
_G.fs = fs
_G.sh = require "sh"
_G.sys = require "sys"

local default_local_configuration = {
    expr = "@",     esc_expr = "@",
    stat = "@@",    esc_stat = "@@",
}

local lconf = setmetatable({}, {      -- stack of local configurations
    __index = {
        top = function(self) return self[#self] end,
    },
    __call = function(self, f, ...)
        self[#self+1] = F.clone(default_local_configuration)
        local val = f(...)
        self[#self] = nil
        return val
    end,
})

local ypp_mt = {
    __index={
        lconf = lconf,
    },
}
local ypp = {}
local known_input_files = F{}
local output_contents = F{}
local input_files = F{fs.join(fs.getcwd(), "-")} -- stack of input files (current branch from the root to the deepest included document)
local output_file = "-"

local red  = term.isatty(io.stderr) and term.color.red  or F.id
local cyan = term.isatty(io.stderr) and term.color.cyan or F.id

local function print_frame(source, source_name, line)
    local context = 5
    io.stderr:write("\n", cyan(source_name..":"..line..":"), "\n")
    source = source or ""
    source : lines() : foreachi(function(i, l)
        if math.abs(i - line) > context then return end
        if i == line then
            io.stderr:write(red(("%4d => %s"):format(i, l)), "\n")
        else
            io.stderr:write(("%4d |  %s"):format(i, l), "\n")
        end
    end)
end

local function print_traceback()
    for level = 1, math.huge do
        local info = debug.getinfo(level)   if not info then break end
                                            if info.short_src:head() == "$" then goto next_frame end
                                            if info.short_src == "[C]"      then goto next_frame end
        local source = info.source:head()=="@" and fs.read(info.source:tail()) or info.source
        print_frame(source, info.short_src, info.currentline)
    ::next_frame::
    end
end

local function parse_error(msg, ...)
    msg = msg : format(...)
    local filename, err_line, err = msg : match "^(.-):(%d+):%s*(.*)$"
    return filename, tonumber(err_line), err or msg
end

local function print_error(filename, err_line, msg)
    if err_line then
        io.stderr:write(cyan(filename..":"..err_line..":"), " ", red"error:", " ", msg, "\n")
    else
        io.stderr:write(red"error:", " ", msg, "\n")
    end
end

function ypp_mt.__index.error(msg, ...)
    local filename, err_line, err = parse_error(msg, ...)
    print_error(filename, err_line, err)
    print_traceback()
    os.exit(1)
end

function ypp_mt.__index.error_in(source, msg, ...)
    local filename, err_line, err = parse_error(msg, ...)
    print_error(filename, err_line, err)
    print_frame(source, filename, err_line)
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
    output_contents[#output_contents+1] = lconf(ypp, content)
end

local function read_file(filename)
    local content
    if filename == "-" then
        content = io.stdin:read "a"
    else
        content = fs.read(filename)
        if not content then ypp.error("%s: can not read file", filename) end
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
    } : find(fs.is_file)
    if not full_filepath then ypp.error("%s: file not found", filename) end
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

function ypp.output_file()
    return output_file
end

local escaped_macro_char = {
    ["^"] = "%^",
    ["$"] = "%$",
    ["%"] = "%%",
    ["."] = "%.",
    ["*"] = "%*",
    ["+"] = "%+",
    ["-"] = "%-",
    ["?"] = "%?",
}

local forbidden_macro_char = {
    ["("] = true, [")"] = true,
    ["["] = true, ["]"] = true,
    ["{"] = true, ["}"] = true,
}

local function update_macro_char(funcname, conf, char)
    if type(char) ~= "string" or #char ~= 1 then
        ypp.error("%s expects a single character", funcname)
    end
    if forbidden_macro_char[char] then
        ypp.error("%q: invalid macro character", char)
    end
    conf.expr = char
    conf.stat = char..char
    local esc_char = escaped_macro_char[char] or char
    conf.esc_expr = esc_char
    conf.esc_stat = esc_char..esc_char
end

local function set_macro_char(funcname, char)
    update_macro_char(funcname, lconf:top(), char)
end

function ypp.macro(char)
    set_macro_char("ypp.macro", char)
    return ""
end

function ypp_mt.__call(_, content)
    if type(content) == "table" then return F.map(ypp, content) end
    local parser = require "parser"
    return parser(content, lconf:top())
end

local function write_outputs(args)
    local content = output_contents:str()
    if not args.output or args.output == "-" then
        io.stdout:write(content)
    else
        fs.mkdirs(fs.dirname(args.output))
        fs.write(args.output, content)
    end
    local file = require "file"
    file.files:foreach(function(f) f:flush() end)
end

local function write_dep_file(args)
    if not (args.gendep or args.depfile or #args.targets>0) then return end
    local name = args.depfile or (args.output and fs.splitext(args.output)..".d")
    if not name then ypp.error("the dependency file name is unknown, use --MF or -o") end
    local function mklist(...)
        return F{...}:flatten():nub()
            :filter(function(p) return p ~= "-" end)
            :map(function(p) return p:gsub("^%."..fs.sep, "") end)
            :unwords()
    end
    local scripts = F.values(package.modpath)
    local file = require "file"
    local deps = mklist(args.targets, args.output or {}, file.outputs).." : "..mklist(known_input_files, scripts)
    fs.mkdirs(fs.dirname(name))
    fs.write(name, deps.."\n")
end

local function parse_args()
    local parser = require "argparse"()
        : name "ypp"
        : description(("ypp %s\nYet a PreProcessor"):format(_YPP_VERSION))
        : epilog "For more information, see https://github.com/CDSoft/ypp"

    parser : flag "-v"
        : description "Show ypp version"
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
            output_file = path
            require"image".output(output)
        end)

    parser : option "-t"
        : description "Set the default format of generated images"
        : target "image_format"
        : choices { "svg", "pdf", "png" }
        : action(function(_, _, fmt, _) require"image".format(fmt) end)

    parser : option "--MT"
        : description "Add `name` to the target list (implies `--MD`)"
        : target "targets"
        : argname "target"
        : count "*"

    parser : option "--MF"
        : description "Set the dependency file name (implies `--MD`)"
        : target "depfile"
        : argname "name"

    parser : flag "--MD"
        : description "Generate a dependency file"
        : target "gendep"

    parser : option "-m"
        : description("Set the default macro character (default: '"..default_local_configuration.expr.."')")
        : target "macro_char"
        : argname "char"
        : action(function(_, _, c, _)
            update_macro_char("-m", default_local_configuration, c)
        end)

    parser : argument "input"
        : description "Input file"
        : args "*"
        : action(function(_, _, names, _)
            if #names == 0 then names = {"-"} end
            F.foreach(names, process_file)
        end)

    return F.patch(parser:parse(), {output=output})
end

_ENV.ypp = setmetatable(ypp, ypp_mt)
local args = parse_args()
require "atexit".run()
write_dep_file(args)
write_outputs(args)
