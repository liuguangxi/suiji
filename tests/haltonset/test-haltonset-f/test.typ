#import "/src/lib.typ": *


#{
  let arr = ()

  arr = haltonset-f(1, size: 0)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(1, size: 1)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(3, size: 1)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(3, size: 6, permutation: false)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(3, size: 6, permutation: true)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(3, size: 6, skip: 10, leap: 0, permutation: true)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(3, size: 6, skip: 0, leap: 1, permutation: true)
  raw(repr(arr)); parbreak()

  arr = haltonset-f(3, size: 6, skip: 10, leap: 1, permutation: true)
  raw(repr(arr)); parbreak()
}
