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
                    return not line:find("[C]: in function 'xpcall'", 1, true)
                    and not line:find("src/parser%.lua:%d+: in local 'msgh'")
                end)
                : filter(function(line)
                    return not line:find("src/parser%.lua:%d+:")
                end),
        }
        io.stderr:write(trace:unlines())
        io.stderr:flush()
        os.exit(1)
    end
end

local function eval(s, tag, expr, state)
    if state.on then
        local msgh = traceback(tag, expr)
        local ok_compile, chunk, compile_error = xpcall(load, msgh, (tag=="@" and "return " or "")..expr, expr, "t")
        if not ok_compile then return s end -- load execution error
        if not chunk then -- compilation error
            msgh(compile_error)
            return s
        end
        local ok_eval, val = xpcall(chunk, msgh)
        if not ok_eval then return s end
        if val == nil and tag=="@" and expr:match("^[%w_]+$") then return s end
        if tag == "@@" then
            if val ~= nil then
                return format_value(val)
            else
                return ""
            end
        end
        return format_value(val)
    else
        return s
    end
end

-- a parser is a function that takes a string, a position and returns the start and stop of the next expression and the expression

local function parse_parentheses(s, i0)
    -- (...)
    local i1, expr, i2 = s:match("^%s*()(%b())()", i0)
    if expr then
        return i1, i2, expr:sub(2, -2)
    end
end

local function parse_brackets(s, i0)
    -- {...}
    local i1, expr, i2 = s:match("^%s*()(%b{})()", i0)
    if expr then
        return i1, i2, expr:sub(2, -2)
    end
end

local function parse_long_string(s, i0)
    -- [==[ ... ]==]
    local i1, sep, i2 = s:match("^%s*()%[(=-)%[()", i0)
    if sep then
        local i3, i4 = s:match("()%]"..sep.."%]()", i2)
        if i3 then
            return i1, i4, s:sub(i2, i3-1)
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
                return i1, i+1, s:sub(i1+1, i-1)
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
        if i3 then return i1, i3, s:sub(i1, i3-1) end
    end
end

parse_sexpr = function(s, i0)
    -- SE -> [.:] E
    do
        local i1 = s:match("^%s*[.:]()", i0)
        if i1 then
            local _, i2, _ = parse_expr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> (...) SE
    do
        local _, i1, _ = parse_parentheses(s, i0)
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> {...} SE
    do
        local _, i1, _ = parse_brackets(s, i0)
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> "..." SE
    do
        local _, i1, _ = parse_quoted_string(s, i0, '"')
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> '...' SE
    do
        local _, i1, _ = parse_quoted_string(s, i0, "'")
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> [[...]] SE
    do
        local _, i1, _ = parse_long_string(s, i0)
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

local function parse(s, i0, state)

    -- find the start of the next expression
    local i1, tag, i2 = s:match("()([@?/]+)()", i0)
    if not i1 then return #s+1, #s+1, "" end

    -- S -> "@/"
    if tag == "@/" then
        return i1, i2, state.on and "" or tag
    end

    -- S -> "?%b()"
    if tag == "?" then
        local _, i3, cond = parse_parentheses(s, i2)
        if cond then
            state.on = assert(load("return "..cond, cond, "t"))()
            return i1, i3, ""
        end
    end

    -- S -> "@@?..."
    if tag == "@" or tag == "@@" then
        -- S -> "@@?(...)"
        do
            local _, i3, expr = parse_parentheses(s, i2)
            if expr then
                return i1, i3, eval(s:sub(i1, i3-1), tag, expr, state)
            end
        end
        -- S -> "@@?[==[...]==]"
        do
            local _, i3, expr = parse_long_string(s, i2)
            if expr then
                return i1, i3, eval(s:sub(i1, i3-1), tag, expr, state)
            end
        end
        -- S -> "@@?"expr
        do
            local _, i3, expr = parse_expr(s, i2)
            if expr then
                return i1, i3, eval(s:sub(i1, i3-1), tag, expr, state)
            end
        end

    end

    -- S -> {}
    return i2, i2, ""

end

return function(s)
    local ts = {}
    local state = {on=true}
    local i = 1
    while i <= #s do
        local i1, i2, out = parse(s, i, state)
        if i1 then
            if i1 > i then
                ts[#ts+1] = s:sub(i, i1-1)
            end
            ts[#ts+1] = out
            i = i2
        else
            ts[#ts+1] = s:sub(i, #s)
            i = #s+1
        end
    end
    return table.concat(ts)
end
