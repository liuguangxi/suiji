#import "preamble.typ": *


// Background image
#let truchet-tiles(seed: 42, unit-size: 50, x-unit: 10, y-unit: 10, stroke: black + 1pt) = {
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
    std.curve(stroke: stroke, ..cmd)
  )
}


// Cover
#page(
  margin: 0pt,
  background: [
    #place(rect(width: 100%, height: 100%,
      fill: gradient.linear((main-color.lighten(70%), 0%), (main-color.lighten(80%), 100%))
    ))
    #place(dx: 0pt, dy: 155pt,
      truchet-tiles(
        seed: 40,
        unit-size: 27, x-unit: 22, y-unit: 10,
        stroke: 4pt + gradient.linear((main-color.lighten(70%), 0%), (white, 100%))
      )
    )
  ]
)[
  #place(dx: 0pt, dy: 0pt, box(
    width: 100%, height: 40pt,
    {
      set align(horizon)
      h(2em)
      text(size: 24pt, font: "Buenard", fill: rgb("#239dad"))[*typst*]
      h(0.5em)
      text(size: 18pt, font: sans-font, fill: luma(30%))[Package]
    }
  ))

  #place(dx: 96pt, dy: 200pt,
    text(size: 48pt, font: sans-font, weight: "bold")[
      #text(fill: main-color.darken(60%))[#name] \
      User's Manual
    ]
  )

  #place(dx: 100pt, dy: 330pt,
    text(size: 20pt, font: sans-font)[
      Version #text(fill: main-color.darken(60%))[*#version*] \
      #date
    ]
  )

  #place(dx: 100pt, dy: 650pt,
    text(size: 20pt, font: sans-font, weight: "bold")[#author]
  )
]
