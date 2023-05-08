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
* `convert(s, [from, to, shift])`: convert the string `s` from the format `from` to the format `to` and shifts the header levels by `shift`.

This function requires a Pandoc Lua interpreter. The conversion is made by [Pandoc] itself.

The parameters `from`, `to` and `shift` are optional. By default Pandoc converts documents from and to Markdown and the header level is not modified (as if `shift` were `0`).
@@@]]

return function(content, from, to, shift)
    assert(pandoc, "The convert macro requires a Pandoc Lua interpreter")
    local doc = pandoc.read(content, from)
    local div = pandoc.Div(doc.blocks)
    if shift then
        div = pandoc.walk_block(div, {
            Header = function(h)
                h = h:clone()
                h.level = h.level + shift
                return h
            end,
        })
    end
    return pandoc.write(pandoc.Pandoc(div.content), to)
end
