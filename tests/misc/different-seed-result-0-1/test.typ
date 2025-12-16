#import "/src/lib.typ": *

// See https://github.com/liuguangxi/suiji/issues/5
#{
  let (rng0, rng1) = (gen-rng(0), gen-rng(1))
  let ((_, int0), (_, int1)) = (integers(rng0), integers(rng1))
  assert.ne(int0, int1)

  let (rng0, rng1) = (gen-rng-f(0), gen-rng-f(1))
  let ((_, int0), (_, int1)) = (integers-f(rng0), integers-f(rng1))
  assert.ne(int0, int1)
}
