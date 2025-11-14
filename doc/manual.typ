#import "preamble.typ": *


// PDF meta data
#set document(
  title: [#name User's Manual],
  author: (author),
  date: none
)


// Cover
#include "cover.typ"


// Configuration
#counter(page).update(1)

#set page(
  header: [
    #set align(center)
    #box(width: 1fr, inset: (x: 2pt, y: 5pt), stroke: (bottom: 0.5pt))[
      _#name User's Manual_ #h(1fr) #context counter(page).display()
    ]
  ]
)

#set par(justify: true)

#set text(font: serif-font, size: 12pt)

#show raw: set text(font: mono-font, size: 11pt)
#show raw.where(block: true): set text(font: mono-font, size: 9pt)
#show raw.where(block: true): block.with(
    width: 100%, inset: 6pt,
    fill: luma(90%), stroke: (left: luma(40%) + 3pt)
)

#show footnote: set text(fill: main-color.darken(60%))
#show ref: set text(fill: main-color.darken(60%))
#show link: set text(fill: main-color.darken(20%))

#set list(marker: text(fill: main-color.darken(60%))[#sym.triangle.filled.r])

#set heading(numbering: (..nums) => nums.pos().map(str).join("."))
#show heading: set text(font: sans-font)
#show heading: set block(above: 1.5em, below: 1em)
#show heading.where(level: 1): set text(size: 18pt, fill: main-color.darken(60%))
#show heading.where(level: 1): set block(below: 1.5em)

#show outline.entry.where(level: 1): set outline.entry(fill: none)
#show outline.entry.where(level: 1): it => {
  set block(above: 1.5em)
  set text(font: sans-font, fill: main-color.darken(60%))
  strong[#it]
}

#show figure.where(kind: table): set figure.caption(position: top)
#show figure.caption: it => [
  #text(font: sans-font, weight: "bold")[
    #it.supplement
    #context it.counter.display(it.numbering)
  ]
  #h(0.5em) #it.body
]


// Contents
#heading(bookmarked: true, numbering: none, outlined: false, [Contents])
#outline(title: none)

#pagebreak(weak: true)


// Main matter
= Introduction

The package `suiji`#footnote[https://typst.app/universe/package/suiji] is a high efficient random number generator in Typst.
Partial algorithm is inherited from GSL#footnote[https://www.gnu.org/software/gsl]
and most APIs are similar to NumPy Random Generator#footnote[https://numpy.org/doc/stable/reference/random/generator.html].
It provides pure function implementation and does not rely on any global state variables, resulting in better performance and independency.

It has the following features:
- All functions are immutable, which means results of random are completely deterministic.
- Core random engine chooses _maximally equidistributed combined Tausworthe generator_.
- Generate random integers or floats from various distribution.
- Randomly shuffle an array of objects.
- Randomly sample from an array of objects.
- Generate quasi-random Halton sequences of different dimensions.
- Accelerate random number generation based on the WebAssembly plugin.

To use it, import the latest version of this package with:
```typ
#import "@preview/suiji:0.5.0": *
```
This line will be omitted in the examples codes that follows.

In the following sections, the use of the corresponding random functions are described in detail.

#pagebreak()


= Guide

== Random Number Algorithm

The algorithm implemented in this package is actually a _pseudorandom number generator_ (PRNG).
The PRNG-generated sequence is not truly random, because it is completely determined by an initial value,
called the PRNG's seed (which may include truly random values).

By balancing the complexity of the implementation and the quality of the results,
the PRNG chooses _maximally equidistributed combined Tausworthe generator_.
The sequence is
$ x_n = s_n^1 xor s_n^2 xor s_n^3 $
where
$
s_(n+1)^1 &= ((s_n^1 space.med\&space.med 4294967294) << 12) xor (((s_n^1 << 13) xor s_n^1) >> 19) \
s_(n+1)^2 &= ((s_n^2 space.med\&space.med 4294967288) << 4) xor (((s_n^2 << 2) xor s_n^2) >> 25) \
s_(n+1)^3 &= ((s_n^3 space.med\&space.med 4294967280) << 17) xor (((s_n^3 << 3) xor s_n^3) >> 11)
$
computed modulo $2^32$. In the formulas above $xor$ denotes _exclusive-or_.

The period of this generator is $2^88$ (about $10^26$).
It uses 3 words (32-bit unsigned integers) of state per generator.

The generator only accept 32-bit seed, with higher values being reduced modulo $2^32$.
A new random integer from $[0, 2^32)$ is obtained by updating the state.
Samples from each distribution implemented here can be obtained using the generator as an underlying source of randomness.


== Quasi-Random Numbers

_Quasi-random number generators_ (QRNGs) produce highly uniform samples of the unit hypercube. QRNGs minimize the discrepancy between the distribution of generated points and a distribution with equal proportions of points in each sub-cube of a uniform partition of the hypercube. As a result, QRNGs systematically fill the “holes” in any initial segment of the generated quasi-random sequence.

Quasi-random sequences seek to fill space uniformly, and to do so in such a way that initial segments approximate this behavior up to a specified density.

Currently only Halton sequences are supported. Produced by the `haltonset` function. These sequences use different prime bases to form successively finer uniform partitions of the unit interval in each dimension.


== Design Considerations

As mentioned earlier, the process of generating random numbers requires state preservation.
When implemented in Typst, the `state` function can be used to preserve the state values of random numbers.
However, Typst's state management system is not very efficient. A purely functional style is preferred.
This package chooses the latter.

Function purity means that for the same arguments, they always return the same result.
They cannot "remember" things to produce another value when they are called a second time.
To follow this rule, a special variable `rng` is chosen as the input and output parameters of the random number generation function.
The variable `rng` is actually the 3 state words of the underlying random generator.
Within the function, its value is updated and output.

Therefore, the basic usage of the random number generation function is as follows.
- The original `rng` should be created by function `gen-rng`, with an integer as the argument of seed.
- Call other random number generation functions as needed, using `rng` as input and output parameters.

As long as the value of the initialized `rng` does not change, the result of the random number output is stable and reproducible.

For functions that generate quasi-random sequences like `haltonset`, call it directly using the appropriate parameter values. And the output of the quasi-random sequences is deterministic.


== WASM plugin

Random number generation is a compute-intensive task. And this task could be accelerated based on the WebAssembly (WASM) plugin.

In addition to the computation itself, there is an additional protocol overhead for calling the plugin.
To minimize this overhead, the following optimization is used.
- Input and output parameters are packaged into an array type.
- Input and output array is serialized as CBOR#footnote[https://cbor.io] format and transmitted in the protocol buffers.
- The validity of the parameters is checked on the Typst wrapper function.

The benchmark (see @chap:benchmark) shows that the acceleration is noticeable with plugin, especially for batch random number generation.

The functions implemented based on the plugin ensure that the interface and functionality are completely consistent with the original Typst script versions.
The only exception is that the results of normally distributed random numbers exhibit extremely minor differences,
due to the different internal floating-point calculation methods.

The set of functions based on the plugin have the suffix `-f` in their names.
For example, `gen-rng-f` and `integers-f` are the fast versions of `gen-rng` and `integers`, respectively.
It is recommended to always use the function version accelerated by the plugin.

#pagebreak(weak: true)


= Reference

== `gen-rng` / `gen-rng-f`

Construct a new random number generator with a seed.

*Note*: The arguments and functions of `gen-rng` and `gen-rng-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`gen-rng`]`(`\
`  `#t-int`,`\
`) -> `#t-object
]
#fn-block[
#fn-name[`gen-rng-f`]`(`\
`  `#t-int`,`\
`) -> `#t-object
]

#para-block[
*`seed`* #h(1fr) #t-int #h(1em) #attr-req #h(0.5em) #attr-pos

The value of seed, effective value is an integer from $[0, 2^32-1]$.

*Note*: Actually, any integer is acceptable because it performs modulo $2^32$ operations internally.
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-ret

Generated object of random number generator, which is transparent to the users.
]


== `integers` / `integers-f`

Return random integers from low to high.
The interval and the size of array can be customized.

Define _gap_ for the sample interval is `high` - `low` if `endpoint` is `false`, otherwise `high` - `low` + 1.
And the valid range of _gap_ is $[1, 2^32]$.

*Note*: The arguments and functions of `integers` and `integers-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`integers`]`(`\
`  `#t-object`,`\
`  low:` #t-int`,`\
`  high:` #t-int`,`\
`  size:` #t-none;#t-int`,`\
`  endpoint:` #t-bool`,`\
`) -> (`#t-object`,`#t-int;#t-array`)`
]
#fn-block[
#fn-name[`integers-f`]`(`\
`  `#t-object`,`\
`  low:` #t-int`,`\
`  high:` #t-int`,`\
`  size:` #t-none;#t-int`,`\
`  endpoint:` #t-bool`,`\
`) -> (`#t-object`,`#t-int;#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`low`* #h(1fr) #t-int #h(1em) #attr-set

The lowest (signed) integers to be drawn from the distribution.

Default: #typc-code("0")
]

#para-block[
*`high`* #h(1fr) #t-int #h(1em) #attr-set

One above the largest (signed) integer to be drawn from the distribution.

Default: #typc-code("100")
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned array size, must be `none` or non-negative integer.
Here `none` means return single random number (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`endpoint`* #h(1fr) #t-bool #h(1em) #attr-set

if `true`, sample from the interval $[$`low`, `high`$]$ instead of the default $[$`low`, `high`$)$.

Default: #typc-code("false")
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-int;#t-array: Returned single or array of random numbers.
]


== `random` / `random-f`

Return random floats in the half-open interval $[0.0, 1.0)$.
The size of array can be customized.

*Note*: The arguments and functions of `random` and `random-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`random`]`(`\
`  `#t-object`,`\
`  size:` #t-none;#t-int`,`\
`  endpoint:` #t-bool`,`\
`) -> (`#t-object`,`#t-float;#t-array`)`
]
#fn-block[
#fn-name[`random-f`]`(`\
`  `#t-object`,`\
`  size:` #t-none;#t-int`,`\
`  endpoint:` #t-bool`,`\
`) -> (`#t-object`,`#t-float;#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned array size, must be `none` or non-negative integer.
Here `none` means return single random number (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-float;#t-array: Returned single or array of random numbers.
]


== `uniform` / `uniform-f`

Draw samples from a uniform distribution of half-open interval $[$low, high$)$ (includes low, but excludes high).
The interval and the size of array can be customized.

*Note*: The arguments and functions of `uniform` and `uniform-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`uniform`]`(`\
`  `#t-object`,`\
`  low:` #t-int;#t-float`,`\
`  high:` #t-int;#t-float`,`\
`  size:` #t-none;#t-int`,`\
`) -> (`#t-object`,`#t-float;#t-array`)`
]
#fn-block[
#fn-name[`uniform-f`]`(`\
`  `#t-object`,`\
`  low:` #t-int;#t-float`,`\
`  high:` #t-int;#t-float`,`\
`  size:` #t-none;#t-int`,`\
`) -> (`#t-object`,`#t-float;#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`low`* #h(1fr) #t-int #attr-or #t-float #h(1em) #attr-set

The lower boundary of the output interval.

Default: #typc-code("0.0")
]

#para-block[
*`high`* #h(1fr) #t-int #attr-or #t-float #h(1em) #attr-set

The upper boundary of the output interval.

Default: #typc-code("1.0")
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned array size, must be `none` or non-negative integer.
Here `none` means return single random number (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-float;#t-array: Returned single or array of random numbers.
]


== `normal` / `normal-f`

Draw random samples from a normal (Gaussian) distribution.
The mean / standard deviation and the size of array can be customized.

*Note*: The arguments and functions of `normal` and `normal-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`normal`]`(`\
`  `#t-object`,`\
`  loc:` #t-int;#t-float`,`\
`  scale:` #t-int;#t-float`,`\
`  size:` #t-none;#t-int`,`\
`) -> (`#t-object`,`#t-float;#t-array`)`
]
#fn-block[
#fn-name[`normal-f`]`(`\
`  `#t-object`,`\
`  loc:` #t-int;#t-float`,`\
`  scale:` #t-int;#t-float`,`\
`  size:` #t-none;#t-int`,`\
`) -> (`#t-object`,`#t-float;#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`loc`* #h(1fr) #t-int #attr-or #t-float #h(1em) #attr-set

The mean (centre) of the distribution.

Default: #typc-code("0.0")
]

#para-block[
*`scale`* #h(1fr) #t-int #attr-or #t-float #h(1em) #attr-set

The standard deviation (spread or width) of the distribution, must be non-negative.

Default: #typc-code("1.0")
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned array size, must be `none` or non-negative integer.
Here `none` means return single random number (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-float;#t-array: Returned single or array of random numbers.
]


== `discrete-preproc` / `discrete-preproc-f`

Preprocess the given probalilities of the discrete events and return a object that contains the lookup table for the discrete random number generator.
The returned object can only be used in functions of `discrete` or `discrete-f`.

*Note*: The arguments and functions of `discrete-preproc` and `discrete-preproc-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`discrete-preproc`]`(`\
`  `#t-array`,`\
`) -> `#t-dictionary
]
#fn-block[
#fn-name[`discrete-preproc-f`]`(`\
`  `#t-array`,`\
`) -> `#t-dictionary
]

#para-block[
*`p`* #h(1fr) #t-array #h(1em) #attr-req #h(0.5em) #attr-pos

The array of probalilities of the discrete events, probalilities must be non-negative.
]

#para-block[
*`g`* #h(1fr) #t-dictionary #h(1em) #attr-ret

Generated object that contains the lookup table, which is transparent to the users.
]


== `discrete` / `discrete-f`

Return random indices from the given probalilities of the discrete events.
Require preprocessed probalilities of the discrete events.

*Note*: The arguments and functions of `discrete` and `discrete-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`discrete`]`(`\
`  `#t-object`,`\
`  `#t-dictionary`,`\
`  size:` #t-none;#t-int`,`\
`) -> (`#t-object`,`#t-int;#t-array`)`
]
#fn-block[
#fn-name[`discrete-f`]`(`\
`  `#t-object`,`\
`  `#t-dictionary`,`\
`  size:` #t-none;#t-int`,`\
`) -> (`#t-object`,`#t-int;#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`g`* #h(1fr) #t-dictionary #h(1em) #attr-req #h(0.5em) #attr-pos

Generated object that contains the lookup table by `discrete-preproc` or `discrete-preproc-f` function.
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned array size, must be `none` or non-negative integer.
Here `none` means return single random number (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-int;#t-array: Returned single or array of random indices.
]


== `shuffle` / `shuffle-f`

Randomly shuffle a given array.

*Note*: The arguments and functions of `shuffle` and `shuffle-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`shuffle`]`(`\
`  `#t-object`,`\
`  `#t-array`,`\
`) -> (`#t-object`,`#t-array`)`
]
#fn-block[
#fn-name[`shuffle-f`]`(`\
`  `#t-object`,`\
`  `#t-array`,`\
`) -> (`#t-object`,`#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`arr`* #h(1fr) #t-array #h(1em) #attr-req #h(0.5em) #attr-pos

The array to be shuffled.
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-array: Returned shuffled array.
]


== `choice` / `choice-f`

Generate random samples from a given array.
The sample assumes a uniform distribution over all entries in the array.

*Note*: The arguments and functions of `choice` and `choice-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`choice`]`(`\
`  `#t-object`,`\
`  `#t-array`,`\
`  size:` #t-none;#t-int`,`\
`  replacement:` #t-bool`,`\
`  permutation:` #t-bool`,`\
`) -> (`#t-object`,`#t-any;#t-array`)`
]
#fn-block[
#fn-name[`choice-f`]`(`\
`  `#t-object`,`\
`  `#t-array`,`\
`  size:` #t-none;#t-int`,`\
`  replacement:` #t-bool`,`\
`  permutation:` #t-bool`,`\
`) -> (`#t-object`,`#t-any;#t-array`)`
]

#para-block[
*`rng`* #h(1fr) #t-object #h(1em) #attr-req #h(0.5em) #attr-pos

The object of random number generator.
]

#para-block[
*`arr`* #h(1fr) #t-array #h(1em) #attr-req #h(0.5em) #attr-pos

The array to be sampled.
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned array size, must be `none` or non-negative integer.
Here `none` means return single random sample (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`replacement`* #h(1fr) #t-bool #h(1em) #attr-set

Whether the sample is with or without replacement. `true` meaning that a value of `arr` can be selected multiple times.

Default: #typc-code("true")
]

#para-block[
*`permutation`* #h(1fr) #t-bool #h(1em) #attr-set

Whether the sample is permuted when sampling without replacement. `false` provides a speedup.

Default: #typc-code("true")
]

#para-block[
*`(rng, arr)`* #h(1fr) #t-array #h(1em) #attr-ret

- `rng` #t-object: Returned updated object of random number generator.
- `arr` #t-any;#t-array: Returned single or array of random samples.
]


== `haltonset` / `haltonset-f`

Generate a Halton sequence point set.

*Note*: The arguments and functions of `haltonset` and `haltonset-f` are the same.

#heading(bookmarked: false, outlined: false, level: 3, numbering: none)[Parameters]

#fn-block[
#fn-name[`haltonset`]`(`\
`  `#t-int`,`\
`  size:` #t-none;#t-int`,`\
`  skip:` #t-int`,`\
`  leap:` #t-int`,`\
`  permutation:` #t-bool`,`\
`) -> `#t-float;#t-array
]
#fn-block[
#fn-name[`haltonset-f`]`(`\
`  `#t-int`,`\
`  size:` #t-none;#t-int`,`\
`  skip:` #t-int`,`\
`  leap:` #t-int`,`\
`  permutation:` #t-bool`,`\
`) -> `#t-float;#t-array
]

#para-block[
*`dim`* #h(1fr) #t-int #h(1em) #attr-req #h(0.5em) #attr-pos

The number of dimensions in the set, effective value is an integer from [1, 30].
]

#para-block[
*`size`* #h(1fr) #t-none #attr-or #t-int #h(1em) #attr-set

The returned points array size, must be `none` or non-negative integer.
Here `none` means return single point sample (i.e. `size` is 1).

Default: #typc-code("none")
]

#para-block[
*`skip`* #h(1fr) #t-int #h(1em) #attr-set

The number of initial points to omit.

Default: #typc-code("0")
]

#para-block[
*`leap`* #h(1fr) #t-int #h(1em) #attr-set

The number of points to miss out between returned points.

Default: #typc-code("0")
]

#para-block[
*`permutation`* #h(1fr) #t-bool #h(1em) #attr-set

Whether use permutations of coefficients in each of the radical inverse functions.

Default: #typc-code("true")
]

#para-block[
*`arr`* #h(1fr) #t-float;#t-array #h(1em) #attr-ret

Returned array of points.
]

#pagebreak(weak: true)


= Benchmarks <chap:benchmark>

== Cases

Various test cases are used to compare the execution efficiency of the two types of functions in different scenarios.

#heading(bookmarked: false, outlined: false, level: 4, numbering: none)[Random Integers]

Generate random integers with different array size. The test codes are as follows.

- *bench-integers-1*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 100000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = integers(rng, low: 0, high: 10000, size: n-sz)
  }
}
```
- *bench-integers-f-1*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 100000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = integers-f(rng, low: 0, high: 10000, size: n-sz)
  }
}
```
- *bench-integers-2*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = integers(rng, low: 0, high: 10000, size: n-sz)
  }
}

```
- *bench-integers-f-2*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = integers-f(rng, low: 0, high: 10000, size: n-sz)
  }
}
```
- *bench-integers-3*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = integers(rng, low: 0, high: 10000, size: n-sz)
  }
}
```
- *bench-integers-f-3*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = integers-f(rng, low: 0, high: 10000, size: n-sz)
  }
}
```

#heading(bookmarked: false, outlined: false, level: 4, numbering: none)[Uniform Distribution Random Numbers]

Generate random numbers from a uniform distribution with different array size. The test codes are as follows.

- *bench-uniform-1*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 100000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = uniform(rng, low: -10.0, high: 10.0, size: n-sz)
  }
}
```
- *bench-uniform-f-1*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 100000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = uniform-f(rng, low: -10.0, high: 10.0, size: n-sz)
  }
}
```
- *bench-uniform-2*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = uniform(rng, low: -10.0, high: 10.0, size: n-sz)
  }
}
```
- *bench-uniform-f-2*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = uniform-f(rng, low: -10.0, high: 10.0, size: n-sz)
  }
}
```
- *bench-uniform-3*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = uniform(rng, low: -10.0, high: 10.0, size: n-sz)
  }
}
```
- *bench-uniform-f-3*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = uniform-f(rng, low: -10.0, high: 10.0, size: n-sz)
  }
}
```

#heading(bookmarked: false, outlined: false, level: 4, numbering: none)[Normal Distribution Random Numbers]

Generate random numbers from a normal distribution with different array size. The test codes are as follows.

- *bench-normal-1*
```typ
#{
  let seed = 0
  let n-tot = 50000
  let n-sz = 50000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = normal(rng, loc: 5.0, scale: 10.0, size: n-sz)
  }
}
```
- *bench-normal-f-1*
```typ
#{
  let seed = 0
  let n-tot = 50000
  let n-sz = 50000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = normal-f(rng, loc: 5.0, scale: 10.0, size: n-sz)
  }
}
```
- *bench-normal-2*
```typ
#{
  let seed = 0
  let n-tot = 50000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = normal(rng, loc: 5.0, scale: 10.0, size: n-sz)
  }
}
```
- *bench-normal-f-2*
```typ
#{
  let seed = 0
  let n-tot = 50000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = normal-f(rng, loc: 5.0, scale: 10.0, size: n-sz)
  }
}
```
- *bench-normal-3*
```typ
#{
  let seed = 0
  let n-tot = 50000
  let n-sz = 1
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = normal(rng, loc: 5.0, scale: 10.0, size: n-sz)
  }
}
```
- *bench-normal-f-3*
```typ
#{
  let seed = 0
  let n-tot = 50000
  let n-sz = 1
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = ()
  for _ in range(n-loop) {
    (rng, data) = normal-f(rng, loc: 5.0, scale: 10.0, size: n-sz)
  }
}
```

#heading(bookmarked: false, outlined: false, level: 4, numbering: none)[Random Shuffle]

Randomly shuffle a given array with different array size. The test codes are as follows.

- *bench-shuffle-1*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 100000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = range(n-sz)
  for _ in range(n-loop) {
    (rng, data) = shuffle(rng, data)
  }
}
```
- *bench-shuffle-f-1*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 100000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = range(n-sz)
  for _ in range(n-loop) {
    (rng, data) = shuffle-f(rng, data)
  }
}
```
- *bench-shuffle-2*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = range(n-sz)
  for _ in range(n-loop) {
    (rng, data) = shuffle(rng, data)
  }
}
```
- *bench-shuffle-f-2*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 1000
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = range(n-sz)
  for _ in range(n-loop) {
    (rng, data) = shuffle-f(rng, data)
  }
}
```
- *bench-shuffle-3*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 10
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng(seed)
  let data = range(n-sz)
  for _ in range(n-loop) {
    (rng, data) = shuffle(rng, data)
  }
}
```
- *bench-shuffle-f-3*
```typ
#{
  let seed = 0
  let n-tot = 100000
  let n-sz = 10
  let n-loop = int(n-tot / n-sz)

  let rng = gen-rng-f(seed)
  let data = range(n-sz)
  for _ in range(n-loop) {
    (rng, data) = shuffle-f(rng, data)
  }
}
```

== Results

The command-line tool `hyperfine`#footnote[https://github.com/sharkdp/hyperfine] is used for benchmarking.
For each case, it runs the benchmark on a warm cache and performs 10 benchmarking runs.

The list of benchmark results is below.

#figure(
  caption: [Benchmark results]
)[
  #align(center)[
    #table(
      align: left,
      columns: (150pt, 150pt),
      fill: (_, y) => if calc.odd(y) {main-color.lighten(90%)},
      stroke: none,
      table.hline(stroke: main-color.darken(60%) + 1.5pt),
      [*Case Name*], [*Average Time* (#txt-g[mean] ± #txt-g0[σ])],
      table.hline(stroke: main-color.darken(60%) + 0.75pt),
      [bench-integers-1], [#txt-g[8.321 s] ± #txt-g0[0.154 s]],
      [bench-integers-f-1], [#txt-g[429.3 ms] ± #txt-g0[25.9 ms]],
      [bench-integers-2], [#txt-g[8.341 s] ± #txt-g0[0.197 s]],
      [bench-integers-f-2], [#txt-g[418.8 ms] ± #txt-g0[11.7 ms]],
      [bench-integers-3], [#txt-g[11.123 s] ± #txt-g0[0.369 s]],
      [bench-integers-f-3], [#txt-g[8.049 s] ± #txt-g0[0.504 s]],
      table.hline(stroke: main-color.darken(60%) + 0.75pt),
      [bench-uniform-1], [#txt-g[7.747 s] ± #txt-g0[0.252 s]],
      [bench-uniform-f-1], [#txt-g[439.7 ms] ± #txt-g0[10.9 ms]],
      [bench-uniform-2], [#txt-g[7.824 s] ± #txt-g0[0.133 s]],
      [bench-uniform-f-2], [#txt-g[446.3 ms] ± #txt-g0[10.7 ms]],
      [bench-uniform-3], [#txt-g[9.766 s] ± #txt-g0[0.065 s]],
      [bench-uniform-f-3], [#txt-g[8.026 s] ± #txt-g0[0.643 s]],
      table.hline(stroke: main-color.darken(60%) + 0.75pt),
      [bench-normal-1], [#txt-g[9.786 s] ± #txt-g0[0.151 s]],
      [bench-normal-f-1], [#txt-g[417.2 ms] ± #txt-g0[11.7 ms]],
      [bench-normal-2], [#txt-g[9.858 s] ± #txt-g0[0.130 s]],
      [bench-normal-f-2], [#txt-g[426.0 ms] ± #txt-g0[14.1 ms]],
      [bench-normal-3], [#txt-g[11.110 s] ± #txt-g0[0.270 s]],
      [bench-normal-f-3], [#txt-g[4.112 s] ± #txt-g0[0.130 s]],
      table.hline(stroke: main-color.darken(60%) + 0.75pt),
      [bench-shuffle-1], [#txt-g[8.558 s] ± #txt-g0[0.132 s]],
      [bench-shuffle-f-1], [#txt-g[882.1 ms] ± #txt-g0[20.2 ms]],
      [bench-shuffle-2], [#txt-g[8.489 s] ± #txt-g0[0.060 s]],
      [bench-shuffle-f-2], [#txt-g[866.7 ms] ± #txt-g0[13.1 ms]],
      [bench-shuffle-3], [#txt-g[7.936 s] ± #txt-g0[0.109 s]],
      [bench-shuffle-f-3], [#txt-g[1.522 s] ± #txt-g0[0.027 s]],
      table.hline(stroke: main-color.darken(60%) + 1.5pt)
    )
  ]
]

Note that the total length of data processed in each set of test cases is the same.
The following results can be observed:
- The more data processed in each round, the more noticeable the acceleration becomes. Especially in the normal tests, the plugin version (bench-normal-f-1) is about 23 times faster than original one (bench-normal-1).
- If the amount of data processed per round is very small (for example, only one), there is only a minimal performance improvement. The overhead of the function call becomes more apparent. But more efficient in the normal and shuffle tests, as the internal calculations are more complex for a single process.
- The original version also becomes slower if the amount of data processed per round is very small. So in practice, as many random numbers as possible should be generated at once.

#pagebreak(weak: true)


= Examples

== Basic Functions

Here the same seed is specified to two generators so that we have reproducible results.

#let codes = ```
#let print-arr(arr) = {
  if type(arr) != array {
    [#raw(str(arr) + " ")]
  } else {
    [#raw(arr.map(it => str(it)).join(" "))]
  }
}

#{
  let seed = 1
  let rng1 = gen-rng-f(seed)
  let rng2 = gen-rng-f(seed)
  let (_, arr1) = random-f(rng1, size: 3)
  let (_, arr2) = random-f(rng2, size: 3)
  print-arr(arr1); parbreak()
  print-arr(arr2); parbreak()
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval("#show raw: set text(font: mono-font, size: 9pt);" + codes.text, mode: "markup", scope: (mono-font: mono-font, gen-rng-f: gen-rng-f, random-f: random-f))
    )
  }
)

For random number generator type function like `integers-f`,
it doesn't matter if you call the function once or multiple times, you end up with the same array value.

#let codes = ```
#let print-arr(arr) = {
  if type(arr) != array {
    [#raw(str(arr) + " ")]
  } else {
    [#raw(arr.map(it => str(it)).join(" "))]
  }
}

#{
  let seed = 1

  let rng = gen-rng-f(seed)
  let arr1 = ()
  let (rng, arr1) = integers-f(rng, low: 0, high: 100, size: 20)
  print-arr(arr1); parbreak()

  let rng = gen-rng-f(seed)
  let arr2 = ()
  let val
  for _ in range(4) {
    (rng, val) = integers-f(rng, low: 0, high: 100, size: 5)
    arr2.push(val)
  }
  arr2 = arr2.flatten()
  print-arr(arr2); parbreak()

  let rng = gen-rng-f(seed)
  let arr3 = ()
  let val
  for _ in range(20) {
    (rng, val) = integers-f(rng, low: 0, high: 100, size: none)
    arr3.push(val)
  }
  print-arr(arr3); parbreak()
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval("#show raw: set text(font: mono-font, size: 9pt);" + codes.text, mode: "markup", scope: (mono-font: mono-font, gen-rng-f: gen-rng-f, integers-f: integers-f))
    )
  }
)

Here we generate 10000 random samples from a normal distribution with $N(5.0, 10.0^2)$, and calculate their mean and standard deviation.

#let codes = ```
#{
  let rng = gen-rng-f(42)
  let arr = ()
  let n = 10000
  (_, arr) = normal-f(rng, loc: 5.0, scale: 10.0, size: n)
  let a-mean = arr.sum() / n
  let a-std = calc.sqrt(arr.map(x => calc.pow(x - a-mean, 2)).sum() / n)
  [#raw("mean = " + str(a-mean)) \ #raw("std = " + str(a-std))]
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval("#show raw: set text(font: mono-font, size: 9pt);" + codes.text, mode: "markup", scope: (mono-font: mono-font, gen-rng-f: gen-rng-f, normal-f: normal-f))
    )
  }
)

Here we shuffle the sequence of the English letters A-Z.

#let codes = ```
#{
  let rng = gen-rng-f(1)
  let arr = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".clusters()
  let (_, arr-s) = shuffle-f(rng, arr)
  raw(arr-s.join())
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval("#show raw: set text(font: mono-font, size: 9pt);" + codes.text, mode: "markup", scope: (mono-font: mono-font, gen-rng-f: gen-rng-f, shuffle-f: shuffle-f))
    )
  }
)

Here, we randomly select 256 arrows from 8 different sets of arrows and arrange them in a 16 by 16 grid.

#let codes = ```
#{
  set text(size: 10pt, fill: purple)
  let rng = gen-rng-f(1)
  let arr = (sym.arrow.r, sym.arrow.l, sym.arrow.t, sym.arrow.b, sym.arrow.tr, sym.arrow.br, sym.arrow.tl, sym.arrow.bl)
  let (_, arr-c) = choice-f(rng, arr, size: 256)
  grid(
    align: horizon + center,
    columns: (12pt,)*16, rows: 12pt,
    stroke: gray + 1pt,
    ..arr-c
  )
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    set align(center)
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval(codes.text, mode: "markup", scope: (gen-rng-f: gen-rng-f, choice-f: choice-f))
    )
  }
)

Here we simulate a biased dice throw, with the occurrence probability of the six sides is 1/21, 2/21, 3/21, 4/21, 5/21 and 6/21, respectively.

#let codes = ```
#let print-arr(arr) = {
  if type(arr) != array {
    [#raw(str(arr) + " ")]
  } else {
    [#raw(arr.map(it => str(it)).join(" "))]
  }
}

#{
  let rng = gen-rng-f(1)
  let p = (1/21, 2/21, 3/21, 4/21, 5/21, 6/21)
  let g = discrete-preproc-f(p)
  let (_, arr) = discrete-f(rng, g, size: 300)
  let points = arr.map(x => x + 1)
  print-arr(points)
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval("#show raw: set text(font: mono-font, size: 9pt);" + codes.text, mode: "markup", scope: (mono-font: mono-font, gen-rng-f: gen-rng-f, discrete-preproc-f: discrete-preproc-f, discrete-f: discrete-f))
    )
  }
)


== Graphics with Randomness

In data visualization or graphing, randomness may sometimes be introduced. Various random functions in the package can help with this.

Below is a random pixel map of 150 by 150. The RGB component of each pixel is a random number.

#let codes = ```
#{
  let seed = 123
  let unit = 2pt
  let (width, height) = (150, 150)

  let rng = gen-rng-f(seed)
  let (_, data) = integers-f(rng, low: 0, high: 256, size: width * height * 3)

  grid(columns: (unit,)*width, rows: unit,
    ..data.chunks(3).map(((r,g,b)) => grid.cell(fill: rgb(r,g,b))[])
  )
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    set align(center)
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval(codes.text, mode: "markup", scope: (gen-rng-f: gen-rng-f, integers-f: integers-f))
    )
  }
)

The example below creates a trajectory of a 2D random walk.

#let codes = ```
#{
  let seed = 9
  let n = 2000
  let step-size = 6
  let curve-stroke = stroke(paint: gradient.linear(blue, green, angle: 45deg), thickness: 1pt, cap: "round", join: "round")

  let rng = gen-rng-f(seed)
  let (rng, va) = uniform-f(rng, low: 0, high: 2*calc.pi, size: n)
  let (rng, vl) = uniform-f(rng, low: 0.5, high: 1.0, size: n)

  let a = 0
  let (x-min, x-max, y-min, y-max) = (0, 0, 0, 0)
  let (x, y) = (0, 0)
  let (dx, dy) = (0, 0)
  let cmd = ()
  for i in range(n) {
    a += va.at(i)
    dx = calc.cos(a) * vl.at(i) * step-size
    dy = -calc.sin(a) * vl.at(i) * step-size
    x += dx
    y += dy
    x-min = calc.min(x-min, x)
    x-max = calc.max(x-max, x)
    y-min = calc.min(y-min, y)
    y-max = calc.max(y-max, y)
    cmd.push(std.curve.line((dx * 1pt, dy * 1pt), relative: true))
  }
  cmd.insert(0, std.curve.move((-x-min * 1pt, -y-min * 1pt)))

  let width = (x-max - x-min) * 1pt
  let height = (y-max - y-min) * 1pt
  box(
    width: width, height: height,
    place(std.curve(stroke: curve-stroke, ..cmd))
  )
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    set align(center)
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval(codes.text, mode: "markup", scope: (gen-rng-f: gen-rng-f, uniform-f: uniform-f))
    )
  }
)

Here is a common form of the Truchet tiles#footnote[https://en.wikipedia.org/wiki/Truchet_tiles].
Decorate each tile with two quarter-circles connecting the midpoints of adjacent sides.
Each such tile has two possible orientations.

#let codes = ```
#{
  let seed = 42
  let unit-size = 10
  let (x-unit, y-unit) = (30, 30)
  let curve-stroke = 2pt + gradient.linear((purple.lighten(50%), 0%), (blue.lighten(50%), 100%), angle: 45deg)

  let c = 4/3*(calc.sqrt(2)-1)
  let tot-unit = x-unit * y-unit
  let s = unit-size * 1pt
  let t = s / 2
  let cell(dx, dy, k) = if k == 0 {(
    std.curve.move((dx, dy)),
    std.curve.move((t, 0pt), relative: true),
    std.curve.cubic((0pt, t*c), (-t*(1-c), t), (-t, t), relative: true),
    std.curve.move((2*t, 0pt), relative: true),
    std.curve.cubic((-t*c, 0pt), (-t, t*(1-c)), (-t, t), relative: true)
  )} else {(
    std.curve.move((dx, dy)),
    std.curve.move((t, 0pt), relative: true),
    std.curve.cubic((0pt, t*c), (t*(1-c), t), (t, t), relative: true),
    std.curve.move((-2*t, 0pt), relative: true),
    std.curve.cubic((t*c, 0pt), (t, t*(1-c)), (t, t), relative: true)
  )}

  let rng-f = gen-rng-f(seed)
  let (_, vk) = integers-f(rng-f, high: 2, size: tot-unit)
  let cmd = range(tot-unit).map(i => cell(calc.rem(i, x-unit) * s, calc.floor(i / x-unit) * s, vk.at(i))).join()

  box(
    width: s * x-unit, height: s * y-unit,
    std.curve(stroke: curve-stroke, ..cmd)
  )
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    set align(center)
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval(codes.text, mode: "markup", scope: (gen-rng-f: gen-rng-f, integers-f: integers-f))
    )
  }
)

Below is two scatter plots of the two dimensions, with uniform pseudorandom numbers and quasi-random Halton sequence, respectively.

#let codes = ```
#import "@preview/lilaq:0.5.0" as lq

#{
  let sz = 1024
  let (width, height) = (190pt,) * 2
  let rng = gen-rng-f(123)
  let (rng, x1) = uniform-f(rng, size: sz)
  let (rng, y1) = uniform-f(rng, size: sz)
  let arr = haltonset-f(2, size: sz)
  let x2 = range(sz).map(i => arr.at(i).at(0))
  let y2 = range(sz).map(i => arr.at(i).at(1))

  lq.diagram(
    width: width, height: height,
    title: [*Random (uniform)*],
    xaxis: (ticks: none), yaxis: (ticks: none),
    xlim: (0, 1), ylim: (0, 1),
    lq.scatter(
      x1, y1,
      size: (15,)*sz,
      color: range(sz).map(i => i/sz),
      map: color.map.cividis
    )
  )

  h(20pt)

  lq.diagram(
    width: width, height: height,
    title: [*Quasi-Random (Halton)*],
    xaxis: (ticks: none), yaxis: (ticks: none),
    xlim: (0, 1), ylim: (0, 1),
    lq.scatter(
      x2, y2,
      size: (15,)*sz,
      color: range(sz).map(i => i/sz),
      map: color.map.cividis
    )
  )
}
```

#grid(align: horizon, gutter: 10pt, columns: 1fr,
  raw(block: true, lang: "typ", codes.text),
  {
    set align(center)
    box(width: 100%, inset: 5pt, stroke: luma(50%),
      eval(codes.text, mode: "markup", scope: (gen-rng-f: gen-rng-f, uniform-f: uniform-f, haltonset-f: haltonset-f))
    )
  }
)

#pagebreak(weak: true)
