/*@@@
**`answer`** takes any question
and returns the most relevant answer.

Example:
``` c
    const char *meaning
        = answer("What's the meaning of life?");
```

The code is:
``` c
@(include.raw("test.c", {pattern="//".."===%s*(.-)%s*$"}))
```
@@@*/

//===
const char *answer(const char *question)
{
    return "42";
}

