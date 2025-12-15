#import "/src/lib.typ": *


#set page(width: auto, height: auto, margin: 0pt)


#{
  let seed = 0
  let unit = 1mm
  let (width, height) = (300,) * 2

  let rng = gen-rng-f(seed)
  let data = ()
  (rng, data) = integers-f(rng, low: 0, high: 256, size: width * height * 3)

  grid(columns: (unit,)*width, rows: unit,
    ..data.chunks(3).map(((r,g,b)) => grid.cell(fill: rgb(r,g,b))[])
  )
}
