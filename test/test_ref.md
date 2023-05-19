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


nil in an expression = nil

nil in a statement = 



weird = bizarre string )) => ) unbalanced ())

malformed expression: @[===========[ foo bar ]=====]
malformed chunk: @@[===========[ foo bar ]=====]


## File inclusion

### Included from another file

This paragraph has been included.

Caller:

-   `input_file(1)`: `./test/test.md`
-   `input_path(1)`: `./test`

Callee:

-   `input_file()`: `./test/test_inc.md`
-   `input_path()`: `./test`


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

  X   Y   Z
  --- --- ---
  a   b   c
  d   e   f


## Images



### Images with the default format (SVG)

#### Implicit image path and output path (ypp cache)

- .build/test/ypp_cache/9d3c8eb78369bfa1.svg
- .build/test/ypp_cache/9d3c8eb78369bfa1.svg


#### Explicit image path

- .build/test/img/ypp_dot_test-1.svg
- .build/test/img/ypp_dot_test-1.svg


#### Different explicit image path and output path

- img/ypp_dot_test-2.svg
- .build/test/img/ypp_dot_test-2.svg


### Images with a specific format (e.g. PNG)

#### Implicit image path and output path (ypp cache)

- .build/test/ypp_cache/01398c77c7fd40c2.png
- .build/test/ypp_cache/01398c77c7fd40c2.png


#### Explicit image path

- .build/test/img/ypp_dot_test-1.png
- .build/test/img/ypp_dot_test-1.png


#### Different explicit image path and output path

- img/ypp_dot_test-2.png
- .build/test/img/ypp_dot_test-2.png


### Images with a custom command

- .build/test/ypp_cache/9d3c8eb78369bfa1.svg
- .build/test/ypp_cache/9d3c8eb78369bfa1.svg


### Images generated with Octave

.build/test/ypp_cache/577b1d4914ad253d.svg

## Scripts loaded on the command line

`test_loaded` = `true`

## Scripts loaded by test.md



`test_2_loaded` = `true`

