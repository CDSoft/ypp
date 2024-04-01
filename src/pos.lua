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

--@LIB

local pos = {}

local positions = F{}

local pos_mt = {
    __index = function(self, field)
        if field == "linenumber" then
            local _, nb_nl = self.input:sub(1, self.index):gsub("\n", {})
            local linenumber = self.firstline + nb_nl
            rawset(self, field, linenumber)
            return linenumber
        end
        error(("Unexpected error: %s: unknown field"):format(field))
    end,
    __tostring = function(self)
        return ("%s:%d"):format(self.filename, self.linenumber)
    end,
}

function pos.push(filename, firstline, input, index)
    positions[#positions+1] = setmetatable({
        filename = filename,
        firstline = firstline or 1,
        input = input,
        index = index,
    }, pos_mt)
end

function pos.pop()
    positions[#positions] = nil
end

function pos.top()
    return positions[#positions]
end

function pos.last()
    for i = #positions, 1, -1 do
        if positions[i].filename then return positions[i] end
    end
    return positions[#positions]
end

return pos
