# ypp tests

## Basic text substitution

$1 + 2 = @(1 + 2)$

@@(
    function sum(a, b)
        return F.range(a, b):sum()
    end
)

$$ \sum_{n=1}^{100} = @(sum(1, 100)) $$

@(F.range(10):map(F.prefix"- Line "))

nil in an expression = @(nil)

nil in a statement = @@(return nil)

@@[===[
-- large block with unbalanced parentheses )))
weird = ") unbalanced ())"
]===]

weird = @[[ "bizarre string )) => " .. weird ]]

malformed expression: @[===========[ foo bar ]=====]
malformed chunk: @@[===========[ foo bar ]=====]


## File inclusion

@(include("test_inc.md", {pattern="===(.-)===", shift=2}))

## Comments

@@(--[===[
This comment is ignored
]===])

## Conditional

@@(lang = "fr")

@(when(lang=="en") "English text discarded (lang=@(lang))")
@(when(lang=="fr") "Texte français conservé (lang=@(lang))")

## Documentation extraction

@(doc("test.c", {doc="@@@(.-)@@@", shift=2}))

## Scripts

### Custom language

- 1+1 = @(script "python" [[print(1+1)]])
- 2+2 = @(script "python %s" [[print(2+2)]])

### Predefined language

- 3+3 = @(script.python [[print(3+3)]])
- 4+4 = @(script.sh [[echo $((4+4))]])

### Formatting script output

@(convert(script.python [===[
print("X, Y, Z")
print("a, b, c")
print("d, e, f")
]===], "csv"))

## Images

@@(
build = os.getenv "BUILD"
example = [===[
digraph {
    A -> B
}
]===]
)

### Images with the default format (SVG)

#### Implicit image path and output path (ypp cache)

@(F.map(F.prefix "- ", {image.dot (example)}))

#### Explicit image path

@(F.map(F.prefix "- ", {image.dot { img = fs.join(build, "test", "img", "ypp_dot_test-1") } (example)}))

#### Different explicit image path and output path

@(F.map(F.prefix "- ", {image.dot { img = fs.join("img", "ypp_dot_test-2"), out = fs.join(build, "test", "img") } (example)}))

### Images with a specific format (e.g. PNG)

#### Implicit image path and output path (ypp cache)

@(F.map(F.prefix "- ", {image.dot.png (example)}))

#### Explicit image path

@(F.map(F.prefix "- ", {image.dot.png { img = fs.join(build, "test", "img", "ypp_dot_test-1") } (example)}))

#### Different explicit image path and output path

@(F.map(F.prefix "- ", {image.dot.png { img = fs.join("img", "ypp_dot_test-2"), out = fs.join(build, "test", "img") } (example)}))

## Scripts loaded on the command line

`test_loaded` = `@(test_loaded)`

## Scripts loaded by test.md

@@(require "test/test2")

`test_2_loaded` = `@(test_2_loaded)`
