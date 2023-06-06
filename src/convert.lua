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

local flex = require "flex"

--[[@@@
* `convert(s, [opts])`:
  convert the string `s` from the format `opts.from` to the format `opts.to` and shifts the header levels by `opts.shift`.

This function requires a Pandoc Lua interpreter. The conversion is made by [Pandoc] itself.

The `opts` parameter is optional.
By default Pandoc converts documents from and to Markdown and the header level is not modified.

?(false)
The `convert` macro can also be called as a curried function (arguments can be swapped). E.g.:

    @convert {from="csv"} (script.python [===[
    # python script that produces a CVS document
    ]===])

Notice that `convert` can be implicitely called by `include` or `script` by giving the appropriate options. E.g.:

    @script.python {from="csv"} [===[
    # python script that produces a CVS document
    ]===]

?(true)
@@@]]

local convert = flex.str_opt(function(content, opts)
    assert(pandoc, "The convert macro requires a Pandoc Lua interpreter")
    opts = opts or {}
    local doc = pandoc.read(content, opts.from)
    local div = pandoc.Div(doc.blocks)
    if opts.shift then
        div = pandoc.walk_block(div, {
            Header = function(h)
                h = h:clone()
                h.level = h.level + opts.shift
                return h
            end,
        })
    end
    return pandoc.write(pandoc.Pandoc(div.content), opts.to)
end)

local convert_if_required = flex.str_opt(function(content, opts)
    opts = opts or {}
    if opts.from or opts.to or opts.shift then
        content = convert(content, opts)
    end
    return content
end)

return setmetatable({}, {
    __call = function(_, ...)
        return convert(...) end,
    __index = {
        if_required = convert_if_required
    },
})
