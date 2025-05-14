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

--@LOAD

--[[@@@
* `defer(func)`: emit a unique tag that will later be replaced by the result of `func()`.

E.g.:

@q[=====[
```
@@ N = 0
total = @defer(function() return N end) (should be "2")
...
@@(N = N+1)
@@(N = N+1)
```
]=====]
@@@]]

local deferred_functions = {}

local function defer(func)
    local tag = string.format("▶%d◀", F.size(deferred_functions))
    deferred_functions[tag] = func
    return tag
end

local function replace(s)
    for tag, func in pairs(deferred_functions) do
        s = s:gsub(tag, func())
    end
    return s
end

return setmetatable({
    defer = defer,
    replace = replace,
}, {
    __call = function(self, s) return self.defer(s) end,
})
