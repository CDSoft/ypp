--[[
This file is part of bang.

bang is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

bang is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with bang.  If not, see <https://www.gnu.org/licenses/>.

For further information about bang you can visit
https://github.com/cdsoft/bang
]]

---------------------------------------------------------------------
-- Release
---------------------------------------------------------------------

section "Binary release"

local F = require "F"
local sh = require "sh"

var "release" "$builddir/release"

rule "release-tar" {
    description = "tar $out",
    command = "tar -caf $out $in --transform='s#$prefix#$dest#'",
}

return function(t)

    assert(t.name, "missing name field")
    assert(t.sources, "missing sources field")

    local version = sh "git describe --tags" : trim()

    local function build_release(target_name, ext)
        local name = F{ t.name, version, target_name } : flatten() : str "-"
        return build("$release"/version/name..".tar.gz") { "release-tar",
            build.luax[target_name]("$release/.build"/target_name/t.name..ext) { t.sources },
            prefix = "$release/.build"/target_name,
            dest = name/"bin",
        }
    end

    phony "release" {
        build_release("lua", ".lua"),
        require "targets" : map(function(target)
            return build_release(target.name, "")
        end),
    }

end
