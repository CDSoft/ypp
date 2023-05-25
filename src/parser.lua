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

local function format_value(x)
    local mt = getmetatable(x)
    if mt and mt.__tostring then return tostring(x) end
    if type(x) == "table" then return F.map(tostring, x):unlines() end
    return tostring(x)
end

local function traceback(tag, expr)
    if tag=="@" and expr:match("^[%w_.]*$") then return function() end end
    return function(message)
        local trace = F.flatten {
            fs.basename(arg[0])..": "..message,
            F(debug.traceback())
                : lines()
                : take_while(function(line)
                    return line:trim() ~= "[C]: in function 'xpcall'"
                end),
        }
        io.stderr:write(trace:unlines())
        os.exit(1)
    end
end

local function eval(s, tag, expr, state)
    if state.on then
        local msgh = traceback(tag, expr)
        local ok_compile, chunk = xpcall(load, msgh, (tag=="@" and "return " or "")..expr, expr, "t")
        if not ok_compile or not chunk then return s end
        local ok_eval, y = xpcall(chunk, msgh)
        if not ok_eval then return s end
        if tag == "@@" then
            if y ~= nil then
                return format_value(y)
            else
                return ""
            end
        end
        return format_value(y)
    else
        return s
    end
end

-- a parser is a function that takes a string, a position and returns the start and stop of the next expression

local function parse_parentheses(s, i0)
    -- (...)
    local full, i1 = s:match("^%s*(%b())()", i0)
    if full then
        local inside = full:sub(2, -2)
        return inside, i1
    end
end

local function parse_brackets(s, i0)
    -- {...}
    local full, i1 = s:match("^%s*(%b{})()", i0)
    if full then
        local inside = full:sub(2, -2)
        return inside, i1
    end
end

local function parse_long_string(s, i0)
    -- [==[ ... ]==]
    local sep, i1 = s:match("^%s*%[(=-)%[()", i0)
    if sep then
        local i2, i3 = s:match("()%]"..sep.."%]()", i1)
        if i2 then
            local inside = s:sub(i1, i2-1)
            return inside, i3
        end
    end
end

local function parse_quoted_string(s, i0, c)
    -- "..."
    local i1 = s:match('^%s*()'..c, i0)
    if i1 then
        local i = i1+1
        while i <= #s do
            if s:sub(i, i) == c then
                return i+1
            end
            if s:sub(i, i) == '\\' then
                i = i+1
            end
            i = i+1
        end
    end
end

local parse_sexpr

local function parse_expr(s, i0)
    -- E -> ident SE
    local i1, ident, i2 = s:match("^%s*()([%w_]+)()", i0)
    if ident then
        local i3 = parse_sexpr(s, i2)
        if i3 then return i1, i3 end
    end
end

parse_sexpr = function(s, i0)
    -- SE -> [.:] E
    do
        local i1 = s:match("^%s*[.:]()", i0)
        if i1 then
            local _, i2 = parse_expr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> (...) SE
    do
        local _, i1 = parse_parentheses(s, i0)
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> {...} SE
    do
        local _, i1 = parse_brackets(s, i0)
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> "..." SE
    do
        local i1 = parse_quoted_string(s, i0, '"')
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> '...' SE
    do
        local i1 = parse_quoted_string(s, i0, "'")
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> [[...]] SE
    do
        local _, i1 = parse_long_string(s, i0)
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> nil
    do
        return i0
    end
end

local function parse(s, i0)

    -- find the start of the next expression
    local i1, tag, i2 = s:match("()([@?/]+)()", i0)
    if not i1 then return #s+1, #s+1, F.const"" end

    -- S -> "@/"
    if tag == "@/" then
        return i1, i2, function(state)
            return state.on and "" or tag
        end
    end

    -- S -> "?%b()"
    if tag == "?" then
        local cond, i3 = parse_parentheses(s, i2)
        if cond then
            return i1, i3, function(state)
                state.on = assert(load("return "..cond, cond, "t"))()
                return ""
            end
        end
    end

    -- S -> "@@?..."
    if tag == "@" or tag == "@@" then
        -- S -> "@@?(...)"
        do
            local inside, i3 = parse_parentheses(s, i2)
            if inside then
                return i1, i3, function(state)
                    return eval(s:sub(i1, i3-1), tag, inside, state)
                end
            end
        end
        -- S -> "@@?[==[...]==]"
        do
            local inside, i3 = parse_long_string(s, i2)
            if inside then
                return i1, i3, function(state)
                    return eval(s:sub(i1, i3-1), tag, inside, state)
                end
            end
        end
        -- S -> "@@?"expr
        do
            local i3, i4 = parse_expr(s, i2)
            if i3 then
                local expr = s:sub(i3, i4-1)
                return i1, i4, function(state)
                    return eval(s:sub(i1, i4-1), tag, expr, state)
                end
            end
        end

    end

    -- S -> {}
    return i2, i2, F.const""

end

return function(s)
    local ts = {}
    local state = {on=true}
    local i = 1
    while i <= #s do
        local i1, i2, f = parse(s, i)
        if i1 then
            if i1 > i then
                ts[#ts+1] = s:sub(i, i1-1)
            end
            ts[#ts+1] = f(state)
            i = i2
        else
            ts[#ts+1] = s:sub(i, #s)
            i = #s+1
        end
    end
    return table.concat(ts)
end
