--@LOAD

--[[@@@
* `image(render, ext)(source)`: use the command `render` to produce an image from the source `source` with the format `ext` (`"svg"`, `"png"` or `"pdf"`).
  `image` returns the name of the image (e.g. to point to the image once deployed) and the actual file path (e.g. to embed the image in the final document).
* `image(render, ext){...}(source)`: same as `image(render, ext)(source)` with a few options. `{...}` can define some fields:
  - `img`: name of the output image (or a hash if `img` is not defined).
  - `out`: destination path of the image (or the directory of `img` if `out` is not defined).
    The optional `out` field overloads `img` to change the output directory when rendering the image.

The `render` parameter is a string that defines the command to execute to generate the image.
It contains some parameters:

- `%i` is replaced by the name of the input document (generated from a hash of `source`).
- `%o` is replaced by the name of the output image file (generated from the `img` and `out` fields).
- `%h` is replaced by a hash computed from the image source (this option is probality completely useless...).

The `img` field is optional. The default value is a name generated in the directory given by the
environment variable `YPP_CACHE` (`.ypp` if `YPP_CACHE` is not defined).

The file format (extension) must be in `render`,
after the `%o` tag (e.g.: `%o.png`), not in the `img` field.

If the program requires a specific input file extension, it can be specified in `render`,
after the `%i` tag (e.g.: `%i.xyz`).

Some render commands are predefined.
For each render `X` (which produces images in the default format)
there are 3 other render commands `X.svg`, `X.png` and `X.pdf` which explicitely specify the image format.
They can be used similaryly to `image`: `X(source)` or `X{...}(source)`.

@@( local engine = {
        circo = "Graphviz",
        dot = "Graphviz",
        fdp = "Graphviz",
        neato = "Graphviz",
        osage = "Graphviz",
        patchwork = "Graphviz",
        sfdp = "Graphviz",
        twopi = "Graphviz",
        actdiag = "Blockdiag",
        blockdiag = "Blockdiag",
        nwdiag = "Blockdiag",
        packetdiag = "Blockdiag",
        rackdiag = "Blockdiag",
        seqdiag = "Blockdiag",
        mmdc = "Mermaid",
        asy = "Asymptote",
        plantuml = "PlantUML",
        ditaa = "ditaa",
        gnuplot = "gnuplot",
        lsvg = "lsvg",
    }
    local function cmp(x, y)
        assert(engine[x], x.." engine unknown")
        assert(engine[y], y.." engine unknown")
        if engine[x] == engine[y] then return x < y end
        return engine[x] < engine[y]
    end
    return F{
        "Image engine | ypp function | Example",
        "-------------|--------------|--------",
    }
    ..
    F.keys(image):sort(cmp):map(function(x)
        return ("[%s] | `%s` | `image.%s(source)`"):format(engine[x], x, x)
    end)
)

Example:

?(false)
``` markdown
![ypp image generation example](@(image.dot {img="doc/ypp"} [===[
digraph {
    rankdir=LR;
    input -> ypp -> output
    ypp -> image
}
]===]))
```
?(true)

is rendered as

![ypp image generation example](@(image.dot {img="doc/ypp"} [===[
digraph {
    rankdir=LR;
    input -> ypp -> output
    ypp -> image
}
]===]))

@@@]]

local F = require "F"
local fs = require "fs"
local sh = require "sh"

local function get_input_ext(s)
    return s:match("%%i(%.%w+)") or ""
end

local function get_ext(s)
    return s:match("%%o(%.%w+)") or ""
end

local function make_diagram_cmd(src, img, render)
    return render:gsub("%%i", src):gsub("%%o", img)
end

local function render_diagram(cmd)
    assert(sh.run(cmd), "Diagram error")
end

local function default_image_cache()
    return _G["YPP_CACHE"] or os.getenv "YPP_CACHE" or ".ypp"
end

local function expand_path(path)
    if path:sub(1, 2) == "~/" then
        return os.getenv("HOME").."/"..path:sub(3)
    else
        return path
    end
end

local function diagram(exe, render, default_ext)
    render = render : gsub("%%exe", exe)
                    : gsub("%%ext", default_ext)
                    : gsub("%%o", "%%o."..default_ext)
    local function prepare_diagram(opts, contents)
        local input_ext = get_input_ext(render)
        local ext = get_ext(render)
        local img = opts.img
        local output_path = opts.out
        local hash_digest = crypt.hash(render..contents)
        if not img then
            local image_cache = default_image_cache()
            fs.mkdirs(image_cache)
            img = fs.join(image_cache, hash_digest)
        else
            img = img:gsub("%%h", hash_digest)
        end
        local out = expand_path(output_path and fs.join(output_path, fs.basename(img)) or img)
        local meta = out..ext..".meta"
        local meta_content = F.unlines {
            "source: "..hash_digest,
            "render: "..render,
            "img: "..img,
            "out: "..out,
            "",
            contents,
        }
        local old_meta = fs.read(meta) or ""
        if not fs.is_file(out..ext) or meta_content ~= old_meta then
            fs.with_tmpdir(function(tmpdir)
                fs.mkdirs(fs.dirname(out))
                local name = fs.join(tmpdir, "diagram")
                local name_ext = name..input_ext
                assert(fs.write(name_ext, contents), "Can not create "..name_ext)
                assert(fs.write(meta, meta_content), "Can not create "..meta)
                local render_cmd = make_diagram_cmd(name, out, render)
                render_diagram(render_cmd)
            end)
        end
        return img..ext, out..ext
    end
    return function(opts)
        if type(opts) == "string" then
            -- no options, use the cache
            return prepare_diagram({}, opts) -- opts is actually the source of the image
        else
            return function(contents)
                return prepare_diagram(opts, contents)
            end
        end
    end
end

local default_ext = "svg"

local PLANTUML = _G["PLANTUML"] or os.getenv "PLANTUML" or fs.join(fs.dirname(arg[0]), "plantuml.jar")
local DITAA = _G["DITAA"] or os.getenv "DITAA" or fs.join(fs.dirname(arg[0]), "ditaa.jar")

local graphviz = "%exe -T%ext -o %o %i"
local plantuml = "java -jar "..PLANTUML.." -pipe -charset UTF-8 -t%ext < %i > %o"
local asymptote = "%exe -f %ext -o %o %i"
local mermaid = "%exe -i %i -o %o"
local blockdiag = "%exe -a -T%ext -o %o %i"
local ditaa = "java -jar "..DITAA.." %svg -o -e UTF-8 %i %o"
local gnuplot = "%exe -e 'set terminal %ext' -e 'set output \"%o\"' -c %i"
local lsvg = "%exe %i.lua %o"

local function define(t)
    local self = {}
    local mt = {}
    for k, v in pairs(t) do
        if k:match "^__" then
            mt[k] = v
        else
            self[k] = v
        end
    end
    return setmetatable(self, mt)
end

local function instantiate(exe, render)
    return define {
        __call = function(_, ...) return diagram(exe, render, default_ext)(...) end,
        svg = diagram(exe, render, "svg"),
        png = diagram(exe, render, "png"),
        pdf = diagram(exe, render, "pdf"),
    }
end

return define {
    dot         = instantiate("dot", graphviz),
    neato       = instantiate("neato", graphviz),
    twopi       = instantiate("twopi", graphviz),
    circo       = instantiate("circo", graphviz),
    fdp         = instantiate("fdp", graphviz),
    sfdp        = instantiate("sfdp", graphviz),
    patchwork   = instantiate("patchwork", graphviz),
    osage       = instantiate("osage", graphviz),
    plantuml    = instantiate("plantuml", plantuml),
    asy         = instantiate("asy", asymptote),
    mmdc        = instantiate("mmdc", mermaid),
    actdiag     = instantiate("actdiag", blockdiag),
    blockdiag   = instantiate("blockdiag", blockdiag),
    nwdiag      = instantiate("nwdiag", blockdiag),
    packetdiag  = instantiate("packetdiag", blockdiag),
    rackdiag    = instantiate("rackdiag", blockdiag),
    seqdiag     = instantiate("seqdiag", blockdiag),
    ditaa       = instantiate("ditaa", ditaa),
    gnuplot     = instantiate("gnuplot", gnuplot),
    lsvg        = instantiate("lsvg", lsvg),
    __call = function(_, render, ext) return diagram(nil, render, ext) end,
    __index = {
        set_format = function(fmt) default_ext = fmt end,
    },
}
