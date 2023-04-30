--@LOAD

--[[@@@
* `convert(s, [from, to, shift])`: convert the string `s` from the format `from` to the format `to` and shifts the header levels by `shift`.

This function requires a Pandoc Lua interpreter. The conversion is made by [Pandoc] itself.

The parameters `from`, `to` and `shift` are optional. By default Pandoc converts documents from and to Markdown and the header level is not modified (as if `shift` were `0`).
@@@]]

return function(content, from, to, shift)
    assert(pandoc, "The convert macro requires a Pandoc Lua interpreter")
    local doc = pandoc.read(content, from)
    local div = pandoc.Div(doc.blocks)
    if shift then
        div = pandoc.walk_block(div, {
            Header = function(h)
                h = h:clone()
                h.level = h.level + shift
                return h
            end,
        })
    end
    return pandoc.write(pandoc.Pandoc(div.content), to)
end
