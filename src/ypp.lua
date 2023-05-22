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

local ypp_enabled = true

function ypp_mt.__call(_, content)
    if type(content) == "table" then return F.map(ypp, content) end

    local function format_value(x)
        local mt = getmetatable(x)
        if mt and mt.__tostring then return tostring(x) end
        if type(x) == "table" then return F.map(tostring, x):unlines() end
        return tostring(x)
    end

    local tokens = {} -- tokenized output with chunks of plain text and macro results

    local function emit_raw(s)
        tokens[#tokens+1] = s
    end

    local function emit_expression(s, x, protected)
        if ypp_enabled then
            if protected then
                local ok_compile, chunk = pcall(load, "return "..x, x, "t")
                if not ok_compile then emit_raw(s); return end
                assert(chunk)
                local ok_eval, y = pcall(chunk)
                if not ok_eval then emit_raw(s); return end
                emit_raw(format_value(y))
            else
                local y = (assert(load("return "..x, x, "t")))()
                emit_raw(format_value(y))
            end
        else
            emit_raw(s)
        end
    end

    local function emit_chunk(s, x)
        if ypp_enabled then
            local y = (assert(load(x, x, "t")))()
            if y ~= nil then
                emit_raw(format_value(y))
            end
        else
            emit_raw(s)
        end
    end

    local emit = { ["@"] = emit_expression, ["@@"] = emit_chunk }

    local i = 1 -- next index to search for a macro
    while i <= #content do

        -- searches for the next pattern among:
        --  ?(...)                          enable/disable ypp              pattern_0
        --  @(...)                          evaluate ...                    pattern_1
        --  @@(...)                         evaluate ...                    pattern_1
        --  @[===[ ... ]===]                evaluate ...                    pattern_2
        --  @@[===[ ... ]===]               evaluate ...                    pattern_2
        --  @var                            evaluate var                    pattern_3
        --  @@var                           evaluate var                    pattern_3 (useless?)
        --  @func(...)                      evaluate func(...)              pattern_3
        --  @@func(...)                     evaluate func(...)              pattern_3
        --  @func{...}                      evaluate func{...}              pattern_3
        --  @@func{...}                     evaluate func{...}              pattern_3
        --  @func[===[ ... ]===]            evaluate func(...)              pattern_3
        --  @@func[===[ ... ]===]           evaluate func(...)              pattern_3
        --  @func(...)[===[ ... ]===]       evaluate func(...)(...)         pattern_3
        --  @@func(...)[===[ ... ]===]      evaluate func(...)(...)         pattern_3
        --  @func{...}[===[ ... ]===]       evaluate func{...}(...)         pattern_3
        --  @@func{...}[===[ ... ]===]      evaluate func{...}(...)         pattern_3
        -- each pattern is recognized by a function that returns the position (start and stop) of the pattern and a function to run to evaluate the macro

        local function pattern_0()
            local i1, x, j1 = content:match("()%?(%b())()", i)
            if i1 then
                return i1, j1, function() ypp_enabled = (assert(load("return "..x, x, "t")))() end
            end
        end

        local function pattern_1()
            local i1, s, t, x, j1 = content:match("()((@@?)(%b()))()", i)
            if i1 then
                return i1, j1, function() emit[t](s, x:sub(2, -2)) end
            end
        end

        local function pattern_2()
            local i1, t, sep, j1 = content:match("()(@@?)%[(=-)%[()", i)
            if i1 then
                local x, j2 = content:match("(.-)%]"..sep.."%]()", j1)
                if j2 then
                    return i1, j2, function() emit[t](content:sub(i1, j2-1), x) end
                end
            end
        end

        local method_pattern = "[_%w][_%w%.:]*"

        local function pattern_3()
            local i1, t, fi, f, j1 = content:match("()(@@?)()("..method_pattern..")()", i)
            if i1 then
                -- @@?f
                local j2p = content:match("^%s*%b()()", j1)
                if j2p then
                    -- @@?f(args_p)
                    local sep, j3 = content:match("^%s*%[(=-)%[()", j2p)
                    if j3 then
                        -- @@?f(args_p)[===[
                        local j4 = content:match("^.-%]"..sep.."%]()", j3)
                        if j4 then
                            -- @@?f(args_p)[===[last_arg]===]
                            return i1, j4, function() emit[t](content:sub(i1, j4-1), content:sub(fi, j4-1)) end
                        else
                            -- unfinished pattern
                            return
                        end
                    else
                        -- @@?f(args_p)
                        return i1, j2p, function() emit[t](content:sub(i1, j2p-1), content:sub(fi, j2p-1)) end
                    end
                end
                local j2b = content:match("^%s*%b{}()", j1)
                if j2b then
                    -- @@?f{args_b}
                    local sep, j3 = content:match("^%s*%[(=-)%[()", j2b)
                    if j3 then
                        -- @@?f{args_b}[===[
                        local j4 = content:match("^.-%]"..sep.."%]()", j3)
                        if j4 then
                            -- @@?f(args_b)[===[last_arg]===]
                            return i1, j4, function() emit[t](content:sub(i1, j4-1), content:sub(fi, j4-1)) end
                        else
                            -- unfinished pattern
                            return
                        end
                    else
                        -- @@?f{args_b}
                        return i1, j2b, function() emit[t](content:sub(i1, j2b-1), content:sub(fi, j2b-1)) end
                    end
                end
                local sep, j2l = content:match("^%s*%[(=-)%[()", j1)
                if j2l then
                    -- @@?f[===[
                    local j3 = content:match("^.-%]"..sep.."%]()", j2l)
                    if j3 then
                        -- @@?f[===[last_arg]===]
                        return i1, j3, function() emit[t](content:sub(i1, j3-1), content:sub(fi, j3-1)) end
                    else
                        -- unfinished pattern
                        return
                    end
                end
                if not f:match ":" then
                    -- @@?f
                    return i1, j1, function() emit[t](content:sub(i1, j1-1), content:sub(fi, j1-1), true) end
                end
            end
        end

        local patterns = {
            pattern_0,
            pattern_1,
            pattern_2,
            pattern_3,
        }

        local i1, j1, pattern1 = #content+1, #content+1, function() end
        for _, find_pattern in ipairs(patterns) do
            local i2, j2, pattern2 = find_pattern()
            if i2 and i2 < i1 then
                i1, j1, pattern1 = i2, j2, pattern2
            end
        end

        if not i1 then
            -- no more patterns
            emit_raw(content:sub(i, #content))
            i = #content+1
        else
            if i1 > i then
                -- emit text before the macro
                emit_raw(content:sub(i, i1-1))
            end
            pattern1()
            i = j1
        end

    end

    return table.concat(tokens)
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
