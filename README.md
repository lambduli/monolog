# Monolog

Monolog is a simple logic programming language. It's syntax is a subset of the Prolog.

It is available within this REPL.

_____

To run: `$ ruby main.rb`


## How to (work with the REPL):

### To store a fact or rule in the knowledge base

Make sure you are in the storing mode by inputting `:s` or `:store` and hitting enter.
Now you can insert predicates and fact one by one into the knowledge base.


### To show the whole knowledge base

In any mode input `:show` and the whole knowledge base will be printed one fact/rule per line.


### To clear the whole knowledge base

In any mode input `:clear` and the whole knodledge base will be cleared.


### To check a validity of the term

First switch to the checking mode by inputting `:c` or `:check` and hitting enter.
Now you can submit a term in the form of lone "predicate query" like `foo(x)` or conjuction of terms like `foo(x), bar(y)`.


### To control the flow of the evaluation

When querying terms, which can backtrack and may produce more than just one answer use `:n` or `:next` to search for the next answer and `:d` or `:done` for concluding the search.

___

## Examples

You can load following fragment of the knowledge base into the REPL.

```prolog
plus(z, N, N).
plus(s(N), M, s(R)) :- plus(N, M, R).
times(z, _, z).
times(s(N), M, A) :- times(N, M, R), plus(R, M, A).
fact(z, s(z)).
fact(s(N), R) :- fact(N, PR), times(s(N), PR, R).
```

Now switch to the `checking mode` and try following queries.

Computing the factorial of 4 using Peano numbers:

`fact(s(s(s(s(z)))), R).` should produce `R = s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(s(z))))))))))))))))))))))))`

Of course 24 of `s`'s are a bit hard to count, so maybe something bit smaller:

`fact(s(s(z)), R).` should produce `R = s(s(z))`

Computing factorials is interesting, but it doesn't really manifest the power and beauty of the logic programming. We can try a different example, we can ask which number is the same as it's factorial.

`fact(A, A).`

And `Monolog` will promptly answer with `A = s(z)` if we ask him politely to try and find another answer it will produce `A = s(s(z))`. That should be enough and we should instruct `Monolog` to conclude this query. There is no other number which would satisfy our condition anyway.

This was quite enlightening but we can go even further, we can ask `Monolog` to find all the pairs of numbers such that they are in the `fact` relation as we defined it.

`fact(A, B).` And it should feed us the following.
```prolog
  A = z
  B = s(z)
```

We are now free to ask for another pair from the `fact` relation and we will be greeted with

```prolog
  A = s(z)
  B = s(z)
```

We can go on infinitely or until the search for a single answer takes longer then couple of moments, which will be roughly around factorial of the number 5 or 6 depending on your hardware, our infinity is quite small, but it's all that we got.

