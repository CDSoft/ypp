--@LOAD

--[[@@@
* `include(filename, [opts])`: include the file `filename`.

    - `opts.pattern` is the Lua pattern used to identify the part of the file to include. If the pattern is not given, the whole file is included.
    - `opts.from` is the format of the input file (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.to` is the destination format (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.shift` is the offset applied to the header levels. The default offset is `0`.
@@@]]

local function raw(filename, opts)
    opts = opts or {}
    local content = ypp.with_inputfile(filename, function(full_filepath)
        local s = ypp.read_file(full_filepath)
        if opts.pattern then
            s = s:match(opts.pattern)
        end
        return s
    end)
    return content
end

local function include(filename, opts)
    opts = opts or {}
    local content = ypp.with_inputfile(filename, function(full_filepath)
        local s = ypp.read_file(full_filepath)
        if opts.pattern then
            s = s:match(opts.pattern)
        end
        return ypp(s)
    end)
    if opts.from or opts.to or opts.shift then
        content = convert(content, opts.from, opts.to, opts.shift)
    end
    return content
end

return setmetatable({
    include = include,
    raw = raw,
}, {
    __call = function(_, ...) return include(...) end,
})
