--@MAIN

--[[@@@
* `ypp(s)`: apply the `ypp` preprocessor to a string.
* `ypp.input_file()`: return the name of the current input file.
* `ypp.input_path()`: return the path of the current input file.
* `ypp.input_file(n)`: return the name of the nth input file in the current *include* stack.
* `ypp.input_file(n)`: return the path of the nth input file in the current *include* stack.
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
    local config = package.config:gmatch("[^\n]*")
    local dir_sep = config()
    local template_sep = config()
    local template = config()
    paths:split(template_sep):map(function(path)
        local new_path = path..dir_sep..template..".lua"
        package.path = new_path .. template_sep .. package.path
    end)
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
        known_input_files[#known_input_files+1] = filename
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
        if type(x) == "table" then
            return F.map(tostring, x):unlines()
        end
        return tostring(x)
    end
    return (content:gsub("([:@?])(@?)(%b())", function(t, t2, x)
        if (t == "@" and t2 == "") and ypp_enabled then -- x is an expression
            x = x:sub(2, -2)
            local y = (assert(load("return "..x, x, "t")))()
            -- if the expression can be evaluated, process it
            return format_value(y)
        elseif (t == "@" and t2 == "@") and ypp_enabled then -- x is a chunk
            x = x:sub(2, -2)
            local y = (assert(load(x, x, "t")))()
            -- if the chunk returns a value, process it
            -- otherwise leave it blank
            return y ~= nil and format_value(y) or ""
        elseif t == "?" and t2 == "" then -- enable/disable verbatim sections
            x = x:sub(2, -2)
            ypp_enabled = (assert(load("return "..x, x, "t")))()
            return ""
        end
    end))
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
            :unwords()
    end
    local scripts = {}
    for modname, _ in pairs(package.loaded) do
        local path = package.searchpath(modname, package.path)
        if path then scripts[#scripts+1] = path end
    end
    local deps = mklist(args.targets, args.output or {}).." : "..mklist(known_input_files, scripts)
    fs.write(name, deps.."\n")
end

local function parse_args()
    local parser = require "argparse"()
        : name "ypp"
        : description "Yet a PreProcessor"
        : epilog "For more information, see https://github.com/CDSoft/ypp"

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

    parser : option "-o"
        : description "Redirect the output to 'file'"
        : target "output"
        : argname "output"

    parser : option "-t"
        : description "Set the default format of generated images"
        : target "image_format"
        : choices { "svg", "pdf", "png" }
        : action(function(_, _, fmt, _) require"image".set_format(fmt) end)

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

    return parser:parse()
end

_ENV.ypp = ypp
local args = parse_args()
require "atexit".run()
write_dep_file(args)
write_outputs(args)
