--@LOAD

--[[@@@
* `doc(filename, [opts])`: extract documentation fragments from the file `filename` (all fragments are concatenated).

    - `opts.pattern` is the Lua pattern used to identify the documentation fragments. The default pattern is `@("@".."@@(.-)@@".."@")`.
    - `opts.from` is the format of the documentation fragments (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.to` is the destination format of the documentation (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.shift` is the offset applied to the header levels. The default offset is `0`.
@@@]]

local F = require "F"

local default_pattern = ("@"):rep(3).."(.-)"..("@"):rep(3)

return function(filename, opts)
    opts = opts or {}
    local pattern = opts.pattern or default_pattern
    local content = ypp.with_inputfile(filename, function(full_filepath)
        local s = ypp.read_file(full_filepath)
        local output = F{}
        s:gsub(pattern, function(doc)
            output[#output+1] = ypp(doc)
        end)
        return output:unlines()
    end)
    if opts.from or opts.to or opts.shift then
        content = convert(content, opts.from, opts.to, opts.shift)
    end
    return content
end
