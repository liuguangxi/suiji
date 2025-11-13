#import "/src/lib.typ": *


#set page(width: auto, height: auto, margin: 0pt)


#{
  let n-sz = 200
  let data = ()
  for d in range(1, 31) {
    data = haltonset(d, size: n-sz, permutation: false)
  }
}
