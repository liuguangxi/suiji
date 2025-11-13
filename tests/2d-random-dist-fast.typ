#set document(date: none)


#import "/src/lib.typ": *
#import "@preview/lilaq:0.5.0" as lq


#set page(width: auto, height: auto, margin: 10pt)


#{
  let sz = 1024
  let (width, height) = (300pt,) * 2

  let rng = gen-rng-f(123)
  let (rng, x1) = uniform-f(rng, size: sz)
  let (rng, y1) = uniform-f(rng, size: sz)

  let arr = haltonset-f(2, size: sz)
  let x2 = range(sz).map(i => arr.at(i).at(0))
  let y2 = range(sz).map(i => arr.at(i).at(1))

  show: lq.set-grid(stroke: none)

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

  h(10pt)

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
