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

local F = require "F"
local flex = require "flex"
local convert = require "convert"

--[[@@@
* `doc(filename, [opts])`: extract documentation fragments from the file `filename` (all fragments are concatenated).

    - `opts.pattern` is the Lua pattern used to identify the documentation fragments. The default pattern is `@("@".."@@(.-)@@".."@")`.
    - `opts.from` is the format of the documentation fragments (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.to` is the destination format of the documentation (e.g. `"markdown"`, `"rst"`, ...). The default format is Markdown.
    - `opts.shift` is the offset applied to the header levels. The default offset is `0`.

?(false)
The `doc` macro can also be called as a curried function (arguments can be swapped). E.g.:

    @doc "file.c" {pattern="///(.-)///"}

?(true)
@@@]]

local default_pattern = ("@"):rep(3).."(.-)"..("@"):rep(3)

return flex.str(function(filename, opts)
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
    content = convert.if_required(content, opts)
    return content
end)
