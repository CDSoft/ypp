--@LOAD

--[[@@@
* `when(cond)(text)`: emit `text` only if `cond` is true.

E.g.:

?(false)
```
@(when(lang="en") [===[
The current language is English.
]===])
```
?(true)
@@@]]

local F = require "F"

return function(cond)
    return cond and ypp or F.const ""
end
