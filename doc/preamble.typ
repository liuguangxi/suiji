#import "/src/lib.typ": *


#let name = "suiji"
#let version = "0.5.1"
#let date = "December 2025"
#let author = "Guangxi Liu"

#let serif-font = "Minion Pro"
#let sans-font = "Myriad Pro"
#let mono-font = "Consolas"

#let main-color = purple.lighten(20%)


#let attr-req = text(size: 10pt)[_Required_]
#let attr-pos = text(size: 10pt)[_Positional_]
#let attr-set = text(size: 10pt)[_Settable_]
#let attr-ret = text(size: 10pt)[_Returned_]
#let attr-or = text(size: 10pt)[or]

#let fn-name = text.with(fill: blue, weight: "bold")

#let typc-code = raw.with(lang: "typc")

#let grad-type = gradient.linear(
  (blue.lighten(50%), 0%),
  (green.lighten(50%), 25%),
  (yellow.lighten(50%), 50%),
  (orange.lighten(50%), 75%),
  (red.lighten(50%), 100%)
)

#let t-bool = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: yellow.lighten(50%))[`bool`];#h(0.25em)]
#let t-int = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: yellow.lighten(50%))[`int`];#h(0.25em)]
#let t-float = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: yellow.lighten(50%))[`float`];#h(0.25em)]
#let t-str = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: green.lighten(50%))[`str`];#h(0.25em)]
#let t-array = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: fuchsia.lighten(70%))[`array`];#h(0.25em)]
#let t-dictionary = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: fuchsia.lighten(70%))[`dictionary`];#h(0.25em)]
#let t-content = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: teal.lighten(50%))[`content`];#h(0.25em)]
#let t-color = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: grad-type)[`color`];#h(0.25em)]
#let t-fill = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: grad-type)[`fill`];#h(0.25em)]
#let t-stroke = [#h(0.25em);#box(outset: 2pt, radius: 2pt, stroke: 2pt + grad-type)[`stroke`];#h(0.25em)]
#let t-none = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: red.lighten(70%))[`none`];#h(0.25em)]
#let t-any = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: luma(80%))[`any`];#h(0.25em)]
#let t-object = [#h(0.25em);#box(outset: 2pt, radius: 2pt, fill: luma(80%))[`object`];#h(0.25em)]


#let fn-block = block.with(width: 100%, inset: 6pt, fill: luma(90%), stroke: (left: luma(40%) + 3pt))

#let para-block = block.with(width: 100%, inset: 6pt, fill: main-color.lighten(90%), stroke: (left: main-color.darken(60%) + 3pt))

#let txt-g = text.with(fill: green, weight: "bold")
#let txt-g0 = text.with(fill: green.darken(30%))
