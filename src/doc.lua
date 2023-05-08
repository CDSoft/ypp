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
