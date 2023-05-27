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

--@LOAD

--[[@@@
* `include(filename, [opts])`: include the file `filename`.

    - `opts.pattern` is the Lua pattern used to identify the part of the file to include. If the pattern is not given, the whole file is included.
    - `opts.from` is the format of the input file (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.to` is the destination format (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.shift` is the offset applied to the header levels. The default offset is `0`.

* `include.raw(filename, [opts])`: like `include` but the content of the file is not preprocessed with `ypp`.
@@@]]

local function include(filename, opts, prepro)
    opts = opts or {}
    local content = ypp.with_inputfile(filename, function(full_filepath)
        local s = ypp.read_file(full_filepath)
        if opts.pattern then
            s = s:match(opts.pattern)
        end
        return prepro(s)
    end)
    if opts.from or opts.to or opts.shift then
        content = convert(content, opts)
    end
    return content
end

return setmetatable({
    raw = function(filename, opts) return include(filename, opts, F.id) end,
}, {
    __call = function(_, filename, opts) return include(filename, opts, ypp) end,
})
