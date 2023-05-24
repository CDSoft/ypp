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

--@LOAD

--[[@@@
* `script(cmd)(source)`: execute `cmd` to interpret `source`.
  `source` is first saved to a temporary file which name is added to the command `cmd`.
  If `cmd` contains `%s` then `%s` is replaces by the temporary script name.
  Otherwise the script name is appended to the command.
  An explicit file extension can be given after `%s` for languages that require
  specific file extensions (e.g. `%s.fs` for F#).

`script` also predefines shortcuts for some popular languages:

@@( local descr = {
        bat = "`command` (DOS/Windows)",
        cmd = "`cmd` (DOS/Windows)",
        fs = "`dotnet fsi` (F# on Windows)",
    }
    return F.keys(script):map(function(lang)
        return ("- `script.%s(source)`: run a script with %s"):format(lang, descr[lang] or lang:cap())
    end)
)

Example:

?(false)
```
$\sum_{i=0}^100 = @script.python "print(sum(range(101)))"$
```
?(true)
is rendered as
```
$\sum_{i=0}^100 = @script.python "print(sum(range(101)))"$
```
@@@]]

local F = require "F"
local fs = require "fs"
local sh = require "sh"

local function make_script_cmd(cmd, arg, ext)
    arg = arg..ext
    local n1, n2
    cmd, n1 = cmd:gsub("%%s"..(ext~="" and "%"..ext or ""), arg)
    cmd, n2 = cmd:gsub("%%s", arg)
    if n1+n2 == 0 then cmd = cmd .. " " .. arg end
    return cmd
end

local scripttypes = {
    {cmd="^python",         ext=".py"},
    {cmd="^lua",            ext=".lua"},
    {cmd="^bash",           ext=".sh"},
    {cmd="^zsh",            ext=".sh"},
    {cmd="^sh",             ext=".sh"},
    {cmd="^cmd",            ext=".cmd"},
    {cmd="^command",        ext=".bat"},
    {cmd="^dotnet%s+fsi",   ext=".fsx"},
}

local function script_ext(cmd)
    local ext = cmd:match("%%s(%.%w+)") -- extension given by the command line
    if ext then return ext end
    for _, scripttype in ipairs(scripttypes) do
        if cmd:match(scripttype.cmd) then return scripttype.ext end
    end
    return ""
end

local function run_script(cmd, content)
    return fs.with_tmpdir(function (tmpdir)
        local name = fs.join(tmpdir, "script")
        local ext = script_ext(cmd)
        fs.write(name..ext, content)
        local output = sh.read(make_script_cmd(cmd, name, ext))
        if output then
            return output:gsub("%s*$", "")
        else
            error("script error")
        end
    end)
end

local run = F.curry(run_script)

return setmetatable({
    python = run "python",
    lua = run "lua",
    bash = run "bash",
    zsh = run "zsh",
    sh = run "sh",
    cmd = run "cmd",
    bat = run "command",
    fs = run "dotnet fsi",
}, {
    __call = function(_, cmd) return run(cmd) end,
})
