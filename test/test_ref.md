# ypp tests

## Basic text substitution

$1 + 2 = 3$



$$ \sum_{n=1}^{100} = 5050 $$

- Line 1
- Line 2
- Line 3
- Line 4
- Line 5
- Line 6
- Line 7
- Line 8
- Line 9
- Line 10


nil in an expression = @(nil)

nil in a statement = 



weird = bizarre string )) => ) unbalanced ())

malformed expression: @[===========[ foo bar ]=====]
malformed chunk: @@[===========[ foo bar ]=====]

function call: 90.0
chaining methods: 55
chaining methods: WORLD! <- HELLO
chaining methods: OLLEH -< !DLROW
chaining methods: WORLD! <- HELLO  : reverse()

escaping: `@F.range(1, 10):sum()`

### pattern_0

`"1+1=@(1+1)"` => `"1+1=2"`

### pattern_1

1+1 = 2
1+1 = 2

### pattern_2

1+1 = 2
1+1 = 2
1+1 = 2
1+1 = 2

### pattern_3



pi = 3.1415926535898
math.max(2, 3) = 3
F.maximum{2, 3, 1} = 3
func(1, 2)[[three]] = three = 1 + 2
functb{1, 2}[[three]] = three = 1 + 2
string.upper[=[ Hello World! ]=] = HELLO WORLD!

ignored pattern: someone@example.com
undefined variable: @undefined

### Special syntax for assignments


$golden\_ratio = 1.6$


a = 14


b = {x=1, y=2}


c = a long string



d = 1, 4, 9, 16, 25, 36, 49, 64, 81, 100

## File inclusion



Macro char is <!> now in this file but not in the included files.



foo = bar
foo = @foo

### Included from another file

This paragraph has been included.

Caller:

-   `input_file(1)`: `./test/test.md`
-   `input_path(1)`: `./test`

Callee:

-   `input_file()`: `./test/test_inc.md`
-   `input_path()`: `./test`

This part is not included:

This part is also not included:


foo = bar
foo = @foo



Macro char <@> is back.

foo = !foo
foo = bar

lines: 28

## Comments





## Conditional




Texte français conservé (lang=fr)

## Documentation extraction

**`answer`** takes any question and returns the most relevant answer.

Example:

``` c
    const char *meaning
        = answer("What's the meaning of life?");
```

The code is:

``` c
const char *answer(const char *question)
{
    return "42";
}
```


## Scripts

### Custom language

- 1+1 = 2
- 2+2 = 4

### Predefined language

- 3+3 = 6
- 4+4 = 8

### Formatting script output

#### Explicit conversion

  X   Y   Z
  --- --- ---
  a   b   c
  d   e   f


#### Implicit conversion

  X   Y   Z
  --- --- ---
  a   b   c
  d   e   f


## Images



### Images with the default format (SVG)

- ypp_images/9a8a73b7973f99e3.svg
- .build/test/ypp_images/9a8a73b7973f99e3.svg


### Images with a specific format (e.g. PNG)

- ypp_images/2e84820d15bf345b.png
- .build/test/ypp_images/2e84820d15bf345b.png


### Images with a custom command

- ypp_images/9a8a73b7973f99e3.svg
- .build/test/ypp_images/9a8a73b7973f99e3.svg


### Images generated with Octave

ypp_images/test-octave.svg

ypp_images/4cd70118e8654415.svg

### Images from an external file

ypp_images/test-dot.svg

ypp_images/398c8ba71be19f13.svg

### Images preprocessed with ypp


ypp_images/hello.svg

## Scripts loaded on the command line

`test_loaded` = `true`

## Scripts loaded by test.md



`test_2_loaded` = `true`



`test3.test_3_loaded` = `true`

## File creation




check .build/test/test-file.txt
