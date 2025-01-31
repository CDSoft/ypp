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
https://github.com/cdsoft/ypp
--]]

--@LIB

local F = require "F"

local function format_value(x)
    local mt = getmetatable(x)
    if mt and mt.__tostring then return tostring(x) end
    if type(x) == "table" then return F.map(tostring, x):unlines() end
    return tostring(x)
end

local function traceback(tag, expr, conf)
    if tag==conf.expr and expr:match("^[%w_.]*$") then return F.const() end
    return function(message, opts)
        if opts and opts.erroneous_source then
            -- Compilation error
            ypp.error_in(opts.erroneous_source, "%s", message)
        else
            -- Execution error => print the traceback
            ypp.error("%s", message)
        end
        os.exit(1)
    end
end

local function eval(s, tag, expr, state)
    local msgh = traceback(tag, expr, state.conf)
    local expr_tag = state.conf.expr -- must be read before eval since they may be modified by the macro function
    local stat_tag = state.conf.stat
    local ok_compile, chunk, compile_error = xpcall(load, msgh, (tag==expr_tag and "return " or "")..expr, expr, "t")
    if not ok_compile then return s end -- load execution error
    if not chunk then -- compilation error
        msgh(compile_error, {erroneous_source=expr})
        return s
    end
    local ok_eval, val = xpcall(chunk, msgh)
    if not ok_eval then return s end
    if val == nil and tag==expr_tag and expr:match("^[%w_]+$") then return s end
    if tag == stat_tag then
        if val ~= nil then
            return format_value(val)
        else
            return ""
        end
    end
    return format_value(val)
end

-- a parser is a function that takes a string and a position
-- and returns the start and stop of the next expression and the expression

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

local function parse_square_brackets(s, i0)
    -- [...]
    local i1, expr, i2 = s:match("^%s*()(%b[])()", i0)
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
    -- SE -> [...] SE
    do
        local _, i1, _ = parse_square_brackets(s, i0)
        if i1 then
            local i2 = parse_sexpr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> [.:] E
    do
        local i1 = s:match("^%s*[.:]()", i0)
        if i1 then
            local _, i2, _ = parse_expr(s, i1)
            if i2 then return i2 end
        end
    end
    -- SE -> nil
    do
        return i0
    end
end

local function parse_lhs(s, i0)
    -- LHS -> identifier ([...] | '.' identifier)*
    local i1, i2 = s:match("^%s*()[%w_]+()", i0)
    if i1 then
        local i = i2
        while true do
            local i3, i4 = s:match("^%s*()%b[]()", i)
            if i3 then
                i = i4
            else
                local i5, i6 = s:match("^%s*()%.%s*[%w_]+()", i)
                if i5 then
                    i = i6
                else
                    return i1, i
                end
            end
        end
    end
end

local atoms = {
    "^%s*()%-?%d+%.%d+e%-?%d+()",
    "^%s*()%-?%d+%.e%-?%d+()",
    "^%s*()%-?%.%d+e%-?%d+()",
    "^%s*()%-?%d+e%-?%d+()",
    "^%s*()%-?%d+%.%d+()",
    "^%s*()%-?%d+%.()",
    "^%s*()%-?%.%d+()",
    "^%s*()%-?%d+()",
    "^%s*()true()",
    "^%s*()false()",
}

local function parse_rhs(s, i0)
    -- RHS -> number | bool
    for _, atom in ipairs(atoms) do
        local i1, i2 = s:match(atom, i0)
        if i1 then return i1, i2 end
    end
    -- RHS = (...)
    do
        local i1, i2, _ = parse_parentheses(s, i0)
        if i1 then
            return i1, i2
        end
    end
    -- RHS = {...}
    do
        local i1, i2, _ = parse_brackets(s, i0)
        if i1 then
            return i1, i2
        end
    end
    -- RHS = "..."
    do
        local i1, i2, _ = parse_quoted_string(s, i0, '"')
        if i1 then
            return i1, i2
        end
    end
    -- RHS = '...'
    do
        local i1, i2, _ = parse_quoted_string(s, i0, "'")
        if i1 then
            return i1, i2
        end
    end
    -- RHS = [=[ ... ]=]
    do
        local i1, i2, _ = parse_long_string(s, i0)
        if i1 then
            return i1, i2
        end
    end
    -- RHS -> expr
    do
        local i1, i2, _ = parse_expr(s, i0)
        if i1 then
            return i1, i2
        end
    end
end

local function parse(s, i0, state)

    local expr_tag = state.conf.expr
    local esc_expr_tag = state.conf.esc_expr
    local stat_tag = state.conf.stat

    -- find the start of the next expression
    local i1, tag, i2 = s:match("()("..esc_expr_tag.."+)()", i0)
    if not i1 then return #s+1, #s+1, "" end

    -- S -> "@@ LHS = RHS
    if tag == stat_tag then
        local i3, i4 = parse_lhs(s, i2)
        if i3 then
            local i5 = s:match("^%s*=()", i4)
            if i5 then
                local i6, i7 = parse_rhs(s, i5)
                if i6 then
                    return i1, i7, eval(s:sub(i1, i7-1), tag, s:sub(i3, i7-1), state)
                end
            end
        end
    end

    -- S -> "@@?..."
    if tag == expr_tag or tag == stat_tag then
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

return function(s, conf)
    local ts = {}
    local state = {conf=conf}
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
