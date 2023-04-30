--@LOAD

--[[@@@
* `atexit(func)`: execute `func` when the whole output is computed, before actually writing the output.
@@@]]

local _functions = {}

return setmetatable({}, {
    __call = function(_, func)
        table.insert(_functions, func)
    end,
    __index = {
        run = function(_)
            while #_functions > 0 do
                table.remove(_functions, #_functions)()
            end
        end,
    },
})
