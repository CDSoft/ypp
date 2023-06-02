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

local function flex_str_opt(f)
    return function(x, y)
        local tx = type(x)
        local ty = type(y)
        if tx == "string" and ty == "table" then
            return f(x, y)
        end
        if ty == "string" and tx == "table" then
            return f(y, x)
        end
        if ty == "nil" then
            if tx == "table" then
                local opt = x
                return setmetatable({}, {
                    __tostring = function(_) error "string expected" end,
                    __call = function(_, str)
                        assert(type(str) == "string", "string expected")
                        return f(str, opt)
                    end,
                })
            end
            if tx == "string" then
                local str = x
                return setmetatable({}, {
                    __tostring = function(_) return f(str, {}) end,
                    __call = function(_, opt)
                        assert(type(opt) == "table", "table expected")
                        return f(str, opt)
                    end,
                })
            end
            error "string or table expected"
        end
        error "string and table (optional) expected"
    end
end

return {
    str_opt = flex_str_opt,
}
