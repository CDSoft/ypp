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

local function flex_type(x)
    if type(x) == "string" then return "str" end
    if type(x) == "table" then
        local mt = getmetatable(x)
        return (mt and mt.__tostring) and "str" or "opt"
    end
    return nil
end

local function flex_str_opt(f)
    return function(x, y)
        local tx = flex_type(x)
        local ty = flex_type(y)
        if tx == "str" and ty == "opt" then
            return f(tostring(x), y)
        end
        if ty == "str" and tx == "opt" then
            return f(tostring(y), x)
        end
        if ty == nil then
            if tx == "opt" then
                local opt = x
                return setmetatable({}, {
                    __tostring = function(_) error "string expected" end,
                    __index = function(_, _) error "string expected" end,
                    __call = function(_, str)
                        assert(flex_type(str) == "str", "string expected")
                        return f(tostring(str), opt)
                    end,
                })
            end
            if tx == "str" then
                local str = x
                return setmetatable({}, {
                    __tostring = function(_) return f(tostring(str), {}) end,
                    __index = function(_, k)
                        return function(s, ...)
                            return string[k](tostring(s), ...)
                        end
                    end,
                    __call = function(_, opt)
                        assert(flex_type(opt) == "opt", "table expected")
                        return f(tostring(str), opt)
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
