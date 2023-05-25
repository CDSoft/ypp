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

function call: @math.deg(math.pi/2)
chaining methods: @F.range(1, 10):sum()
chaining methods: @string.words[==[ hello world! ]==] : map(string.upper) : reverse() : str(" <- ")
chaining methods: @string.words[==[ hello world! ]==] : map(string.upper) : reverse() : str(" <- ") : reverse()
chaining methods: @string.words[==[ hello world! ]==] : map(string.upper) : reverse() : str(" <- ") @/ : reverse()

escaping: `@q"@F.range(1, 10):sum()"`

### pattern_0

?(false)`"1+1=@(1+1)"`?(true) => `"1+1=@(1+1)"`

### pattern_1

1+1 = @(1+1)
1+1 = @@(return 1+1)

### pattern_2

1+1 = @[[1+1]]
1+1 = @[==[1+1]==]
1+1 = @@[[return 1+1]]
1+1 = @@[==[return 1+1]==]

### pattern_3

@@[===[
    function func(x, y)
        return function(s)
            return s.." = "..x.." + "..y
        end
    end
    function functb(xs)
        return function(s)
            return s.." = "..F.str(xs, " + ")
        end
    end
]===]

pi = @math.pi
math.max(2, 3) = @math.max(2, 3)
F.maximum{2, 3, 1} = @F.maximum{2, 3, 1}
func(1, 2)[[three]] = @func(1, 2)[[three]]
functb{1, 2}[[three]] = @functb{1, 2}[[three]]
string.upper[=[ Hello World! ]=] = @string.upper[=[Hello World!]=]

ignored pattern: someone@example.com

## File inclusion

@include("test_inc.md", {pattern="===(.-)===", shift=2})

## Comments

@@(--[===[
This comment is ignored
]===])

@comment[=[
This comment is also ignored
]=]

## Conditional

@@(lang = "fr")

@when(lang=="en") [[English text discarded (lang=@(lang))]]
@when(lang=="fr") [[Texte français conservé (lang=@(lang))]]

## Documentation extraction

@doc("test.c", {doc="@@@(.-)@@@", shift=2})

## Scripts

### Custom language

- 1+1 = @script("python") [[print(1+1)]]
- 2+2 = @script("python %s") [[print(2+2)]]

### Predefined language

- 3+3 = @script.python [[print(3+3)]]
- 4+4 = @script.sh [[echo $((4+4))]]

### Formatting script output

@convert(script.python [===[
print("X, Y, Z")
print("a, b, c")
print("d, e, f")
]===], {from="csv"})

## Images

@@[[
example = [===[
digraph {
    A -> B
}
]===]
]]

### Images with the default format (SVG)

@F.map(F.prefix "- ", {image.dot (example)})

### Images with a specific format (e.g. PNG)

@F.map(F.prefix "- ", {image.dot.png (example)})

### Images with a custom command

@F.map(F.prefix "- ", {image("dot -T%ext -o %o %i", "svg") (example)})

### Images generated with Octave

@image.octave [===[
x = 0:0.01:3;
plot (x, erf (x));
hold on;
plot (x, x, "r");
axis ([0, 3, 0, 1]);
text (0.65, 0.6175, ...
      ['$\displaystyle\leftarrow x = {2 \over \sqrt{\pi}}' ...
       '\int_{0}^{x} e^{-t^2} dt = 0.6175$'],
      "interpreter", "latex");
xlabel ("x");
ylabel ("erf (x)");
title ("erf (x) with text annotation");
]===]

### Images from an external file

@image.dot "@test/test.dot"

## Scripts loaded on the command line

`test_loaded` = `@test_loaded`

## Scripts loaded by test.md

@@require "test/test2"

`test_2_loaded` = `@test_2_loaded`
