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
https://codeberg.org/cdsoft/ypp
--]]

--@LIB

local F = require "F"

local function format_value(x)
    local mt = getmetatable(x)
    if mt and mt.__tostring then return tostring(x) end
    if type(x) == "table" then return F.flatten(x):map(tostring):unlines() end
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
-- and returns the start and stop of the next expression

local function empty(_, i0) return i0, i0 end

local function parse_token(skip)
    return function(x)
        local pattern = "^"..skip.."()"..x.."()"
        return function(s, i0)
            if not i0 then return end
            return s:match(pattern, i0)
        end
    end
end

local function seq2(p1, p2)
    return function(s, i0)
        local i1, i2 = p1(s, i0)
        local i3, i4 = p2(s, i2)
        if i3 then return i1, i4 end
    end
end

local function alt(ps)
    return function(s, i0)
        for _, p in ipairs(ps) do
            local i1, i2 = p(s, i0)
            if i1 then return i1, i2 end
        end
    end
end

local token         = parse_token "%s*"
local jump_to_token = parse_token ".-"

local parse_parentheses     = token "%b()" -- (...)
local parse_brackets        = token "%b{}" -- {...}
local parse_square_brackets = token "%b[]" -- [...]

local parse_long_string_open = token"%[=-%["
local parse_long_string_close = function(level) return jump_to_token("]"..level.."]") end

local function parse_long_string(s, i0)
    -- [==[ ... ]==]
    local o1, o2 = parse_long_string_open(s, i0)
    if not o1 then return end
    local c1, c2 = parse_long_string_close(s:sub(o1+1, o2-2))(s, o2)
    if c1 then return o1, c2 end
end

local function parse_quoted_string(c)
    local boundary = token(c)
    return function(s, i0)
        local i1, i2 = boundary(s, i0)
        if not i1 then return end
        local i = i2
        while i <= #s do
            local ci = s:sub(i, i)
            if ci == c then return i1, i+1 end
            if ci == '\\' then i = i + 1 end
            i = i + 1
        end
    end
end

local parse_single_quoted_string = parse_quoted_string "'"
local parse_double_quoted_string = parse_quoted_string '"'
local parse_ident = token"[%w_]+"
local parse_field_access = token"[.:]"
local parse_dot = token"%."
local parse_eq = token"="

local sexpr_parsers

local function parse_sexpr(s, i0)
    if not i0 then return end
    return alt(sexpr_parsers)(s, i0)
end

-- E -> ident SE
local parse_expr = seq2(parse_ident, parse_sexpr)

sexpr_parsers = {
    seq2(parse_parentheses, parse_sexpr),           -- SE -> (...) SE
    seq2(parse_brackets, parse_sexpr),              -- SE -> {...} SE
    seq2(parse_double_quoted_string, parse_sexpr),  -- SE -> "..." SE
    seq2(parse_single_quoted_string, parse_sexpr),  -- SE -> '...' SE
    seq2(parse_long_string, parse_sexpr),           -- SE -> [[...]] SE
    seq2(parse_square_brackets, parse_sexpr),       -- SE -> [...] SE
    seq2(parse_field_access, parse_expr),           -- SE -> [.:] E
    empty,                                          -- SE -> empty
}

local function parse_lhs(s, i0)
    -- LHS -> identifier ([...] | '.' identifier)*
    local i1, i2 = parse_ident(s, i0)
    if not i1 then return end
    local i = i2
    ::loop::
    local i3, i4 = parse_square_brackets(s, i)
    if i3 then i = i4; goto loop end
    local i5, i6 = parse_dot(s, i) ---@diagnostic disable-line: unused-local
    local i7, i8 = parse_ident(s, i6)
    if i7 then i = i8; goto loop end
    return i1, i
end

local rhs_parsers = {
    token"%-?%d+%.%d+e%-?%d+",          -- RHS -> number
    token"%-?%d+%.e%-?%d+",             -- RHS -> number
    token"%-?%.%d+e%-?%d+",             -- RHS -> number
    token"%-?%d+e%-?%d+",               -- RHS -> number
    token"%-?%d+%.%d+",                 -- RHS -> number
    token"%-?%d+%.",                    -- RHS -> number
    token"%-?%.%d+",                    -- RHS -> number
    token"%-?%d+",                      -- RHS -> number
    token"true",                        -- RHS -> boolean
    token"false",                       -- RHS -> boolean
    parse_parentheses,                  -- RHS -> (...)
    parse_brackets,                     -- RHS -> {...}
    parse_double_quoted_string,         -- RHS -> "..."
    parse_single_quoted_string,         -- RHS -> '..."
    parse_long_string,                  -- RHS -> [=[ ... ]=]
    parse_expr,                         -- RHS -> expr
}

local parse_rhs = alt(rhs_parsers)

local function parse(s, i0, state)

    local expr_tag = state.conf.expr
    local esc_expr_tag = state.conf.esc_expr
    local stat_tag = state.conf.stat

    local parse_tag = jump_to_token(esc_expr_tag.."+")

    -- find the start of the next expression
    local i1, i2 = parse_tag(s, i0)
    if not i1 then return #s+1, #s+1, "" end
    local tag = s:sub(i1, i2-1)

    -- S -> "@@ LHS = RHS"
    if tag == stat_tag then
        local i3, i4 = parse_lhs(s, i2)
        local i5, i6 = parse_eq(s, i4) ---@diagnostic disable-line: unused-local
        local i7, i8 = parse_rhs(s, i6)
        if i7 then return i1, i8, eval(s:sub(i1, i8-1), tag, s:sub(i3, i8-1), state) end
    end

    -- S -> "(@|@@)..."
    if tag == expr_tag or tag == stat_tag then
        do -- S -> "(@|@@)(...)"
            local i3, i4 = parse_parentheses(s, i2)
            if i3 then return i1, i4, eval(s:sub(i1, i4-1), tag, s:sub(i3+1, i4-2), state) end
        end
        do -- S -> "(@|@@)[==[...]==]"
            local i3, i4 = parse_long_string(s, i2)
            if i3 then
                local expr = s:sub(i3, i4-1):gsub("^%[=*%[(.*)%]=*%]$", "%1")
                return i1, i4, eval(s:sub(i1, i4-1), tag, expr, state)
            end
        end
        do -- S -> "(@|@@)"expr
            local i3, i4 = parse_expr(s, i2)
            if i3 then return i1, i4, eval(s:sub(i1, i4-1), tag, s:sub(i3, i4-1), state) end
        end
    end

    -- S -> @+ (return the invalid tag unchanged)
    return i1, i2, tag

end

return function(s, conf)
    local ts = {}
    local state = {conf=conf}
    local i = 1
    while i <= #s do
        local i1, i2, out = parse(s, i, state)
        if not i2 then
            ts[#ts+1] = s:sub(i, #s)
            break
        end
        if i1 > i then ts[#ts+1] = s:sub(i, i1-1) end
        ts[#ts+1] = out
        i = i2
    end
    return table.concat(ts)
end
