#import "/src/lib.typ": *


#set page(width: auto, height: auto, margin: 0pt)


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
