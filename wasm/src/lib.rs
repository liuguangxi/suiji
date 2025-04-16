use wasm_minimal_protocol::*;
use ciborium::{de::from_reader, ser::into_writer};


initiate_protocol!();



//----------------------------------------------------------
// Random functions
//----------------------------------------------------------

// Tausworthe operator
#[inline(always)]
fn tausworthe(s: u32, a: u8, b: u8, c: u32, d: u8) -> u32 {
    let s1 = (s & c) << d;
    let s2 = ((s << a) ^ s) >> b;
    s1 ^ s2
}


// Get a new random integer from [0, 2^32) by update state
#[inline(always)]
fn taus_get(st: [u32; 3]) -> ([u32; 3], u32) {
    let s1 = tausworthe(st[0], 13, 19, 4294967294, 12);
    let s2 = tausworthe(st[1], 2, 25, 4294967288, 4);
    let s3 = tausworthe(st[2], 3, 11, 4294967280, 17);
    let val = s1 ^ s2 ^ s3;
    ([s1, s2, s3], val)
}


// Get a new random float from [0, 1) by update state
#[inline(always)]
fn taus_get_float(st: [u32; 3]) -> ([u32; 3], f64) {
    let (st, val) = taus_get(st);
    (st, val as f64 / 4294967296.0)
}


// Construct a new random number generator with a seed
fn taus_set(seed: u32) -> [u32; 3] {
    let mut s = seed;
    if s == 0 {s = 1;}

    let mut s1 = 69069 * s;
    if s1 < 2 {s1 += 2;}
    let mut s2 = 69069 * s1;
    if s2 < 8 {s2 += 8;}
    let mut s3 = 69069 * s2;
    if s3 < 16 {s3 += 16;}
    let mut st = [s1, s2, s3];

    // Warm it up
    (st, _) = taus_get(st);
    (st, _) = taus_get(st);
    (st, _) = taus_get(st);
    (st, _) = taus_get(st);
    (st, _) = taus_get(st);
    (st, _) = taus_get(st);
    st
}


// Return random integers from [0, n), 1 <= n <= 0xFFFFFFFF
#[inline(always)]
fn uniform_int(rng: [u32; 3], n: u32) -> ([u32; 3], u32) {
    let scale: u32 = 0xFFFFFFFF / n;
    let mut rng = rng;
    let mut val: u32;

    loop {
        (rng, val) = taus_get(rng);
        let k = val / scale;
        if k < n {
            return (rng, k)
        }
    }
}


// Return random integers from low (inclusive) to high (exclusive)
fn integers(rng: [u32; 3], sz: u32, low: i64, gap: u32) -> ([u32; 3], Vec<i64>) {
    let mut rng = rng;
    let mut val: u32;
    let mut a: Vec<i64> = Vec::new();

    for _ in 0..sz {
        (rng, val) = uniform_int(rng, gap);
        a.push(val as i64 + low);
    }
    (rng, a)
}


// Return random floats in the half-open interval [0.0, 1.0)
fn random(rng: [u32; 3], sz: u32) -> ([u32; 3], Vec<f64>) {
    let mut rng = rng;
    let mut val: f64;
    let mut a: Vec<f64> = Vec::new();

    for _ in 0..sz {
        (rng, val) = taus_get_float(rng);
        a.push(val);
    }
    (rng, a)
}


// Draw samples from a uniform distribution of half-open interval [low, high) (includes low, but excludes high)
fn uniform(rng: [u32; 3], sz: u32, low: f64, high: f64) -> ([u32; 3], Vec<f64>) {
    let mut rng = rng;
    let mut val: f64;
    let mut a: Vec<f64> = Vec::new();

    for _ in 0..sz {
        (rng, val) = taus_get_float(rng);
        a.push(low * (1.0 - val) + high * val);
    }
    (rng, a)
}


// Draw random samples from a normal (Gaussian) distribution
fn normal(rng: [u32; 3], sz: u32, loc: f64, scale: f64) -> ([u32; 3], Vec<f64>) {
    let mut rng = rng;
    let mut val: f64;
    let mut x: f64;
    let mut y: f64;
    let mut r2: f64;
    let mut a: Vec<f64> = Vec::new();

    for _ in 0..sz {
        loop {
            // Choose x and y in uniform square (-1,-1) to (+1,+1)
            (rng, val) = taus_get_float(rng);
            x = -1.0 + 2.0 * val;
            (rng, val) = taus_get_float(rng);
            y = -1.0 + 2.0 * val;

            // See if it is in the unit circle
            r2 = x * x + y * y;
            if r2 <= 1.0 && r2 != 0.0 {break}
        }

        // Box-Muller transform
        a.push(loc + scale * y * (-2.0 * r2.ln() / r2).sqrt());
    }
    (rng, a)
}


// Preprocess the given probalilities of the discrete events
// and return a object that contains the lookup table for the discrete random number generator
fn discrete_preproc(p: Vec<f64>) -> (u32, Vec<u32>, Vec<f64>) {
    let k_event: u32 = p.len() as u32;
    let mut p_tot: f64 = p.iter().sum();
    if p_tot <= 0.0 {
        p_tot = 2.22e-16;
    }
    let mut pp: Vec<f64> = p.iter().map(|x| x / p_tot).collect();
    let mut a: Vec<u32> = vec![0; k_event as usize];
    let mut f: Vec<f64> = vec![0.0; k_event as usize];

    let mean = 1.0 / k_event as f64;
    for k in 0..k_event {
        if pp[k as usize] < mean {
            a[k as usize] = 0;
        } else {
            a[k as usize] = 1;
        }
    }

    let mut bigs: Vec<u32> = Vec::new();
    let mut smalls: Vec<u32> = Vec::new();
    for k in 0..k_event {
        if a[k as usize] == 1 {
            bigs.push(k);
        } else {
            smalls.push(k);
        }
    }
    while smalls.len() > 0 {
        let s = smalls.pop().unwrap();
        if bigs.len() == 0 {
            a[s as usize] = s;
            f[s as usize] = 1.0;
            continue;
        }
        let b = bigs.pop().unwrap();
        a[s as usize] = b;
        f[s as usize] = k_event as f64 * pp[s as usize];
        let d = mean - pp[s as usize];
        pp[s as usize] += d;
        pp[b as usize] -= d;
        if pp[b as usize] < mean {
            smalls.push(b);
        } else if pp[b as usize] > mean {
            bigs.push(b);
        } else {
          a[b as usize] = b;
          f[b as usize] = 1.0;
        }
    }
    while bigs.len() > 0 {
        let b = bigs.pop().unwrap();
        a[b as usize] = b;
        f[b as usize] = 1.0;
    }

    for k in 0..k_event {
        f[k as usize] += k as f64;
        f[k as usize] /= k_event as f64;
    }

    (k_event, a, f)
}


// Return random indices from the given probalilities of the discrete events
// Require preprocessed probalilities of the discrete events
fn discrete(rng: [u32; 3], sz: u32, g: (u32, Vec<u32>, Vec<f64>)) -> ([u32; 3], Vec<u32>) {
    let mut rng = rng;
    let mut u: f64;
    let mut a: Vec<u32> = Vec::new();

    for _ in 0..sz {
        (rng, u) = taus_get_float(rng);
        let c = (u * g.0 as f64).floor() as u32;
        let f = g.2[c as usize];
        if f == 1.0 {
            a.push(c);
        } else if u < f {
            a.push(c);
        } else {
            a.push(g.1[c as usize]);
        }
    }
    (rng, a)
}


// Randomly shuffle a given array (only return array index)
fn shuffle(rng: [u32; 3], sz: u32) -> ([u32; 3], Vec<u32>) {
    let mut rng = rng;
    let mut i: u32 = sz - 1;
    let mut j: u32;
    let mut a: Vec<u32> = (0..sz).collect();

    while i > 0 {
        (rng, j) = uniform_int(rng, i + 1);
        if i != j {
            a.swap(i as usize, j as usize);
        }
        i -= 1;
    }
    (rng, a)
}


// Generate random samples from a given array (only return array index)
fn choice(rng: [u32; 3], sz: u32, n: u32, replacement: bool, permutation: bool) -> ([u32; 3], Vec<u32>) {
    let mut rng = rng;
    let mut a: Vec<u32> = Vec::new();

    if replacement {    // sample with replacement
        let mut val: u32;
        for _ in 0..sz {
            (rng, val) = uniform_int(rng, n);
            a.push(val);
        }
    } else {    // sample without replacement
        let mut val: f64;
        let mut i: u32 = 0;
        let mut j: u32 = 0;
        while i < n && j < sz {
            (rng, val) = taus_get_float(rng);
            if (n - i) as f64 * val < (sz - j) as f64 {
                a.push(i);
                j += 1;
            }
            i += 1;
        }
        if permutation {
            let ai: Vec<u32>;
            (rng, ai) = shuffle(rng, sz);
            let mut ap: Vec<u32> = Vec::new();
            for i in ai {
                ap.push(a[i as usize]);
            }
            a = ap;
        }
    }

    (rng, a)
}



//----------------------------------------------------------
// Export functions
//----------------------------------------------------------

// Construct a new random number generator with a seed
#[wasm_func]
pub fn gen_rng_fn(arg: &[u8]) -> Vec<u8> {
    let args: u32 = from_reader(arg).unwrap();

    let ret = taus_set(args);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Return random integers from low (inclusive) to high (exclusive)
#[wasm_func]
pub fn integers_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32, i64, u32) = from_reader(arg).unwrap();

    let ret = integers(args.0, args.1, args.2, args.3);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Return random floats in the half-open interval [0.0, 1.0)
#[wasm_func]
pub fn random_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32) = from_reader(arg).unwrap();

    let ret = random(args.0, args.1);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Draw samples from a uniform distribution of half-open interval [low, high) (includes low, but excludes high)
#[wasm_func]
pub fn uniform_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32, f64, f64) = from_reader(arg).unwrap();

    let ret = uniform(args.0, args.1, args.2, args.3);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Draw random samples from a normal (Gaussian) distribution
#[wasm_func]
pub fn normal_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32, f64, f64) = from_reader(arg).unwrap();

    let ret = normal(args.0, args.1, args.2, args.3);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Preprocess the given probalilities of the discrete events
// and return a object that contains the lookup table for the discrete random number generator
#[wasm_func]
pub fn discrete_preproc_fn(arg: &[u8]) -> Vec<u8> {
    let args: Vec<f64> = from_reader(arg).unwrap();

    let ret = discrete_preproc(args);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Return random indices from the given probalilities of the discrete events
// Require preprocessed probalilities of the discrete events
#[wasm_func]
pub fn discrete_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32, (u32, Vec<u32>, Vec<f64>)) = from_reader(arg).unwrap();

    let ret = discrete(args.0, args.1, args.2);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Randomly shuffle a given array (only return array index)
#[wasm_func]
pub fn shuffle_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32) = from_reader(arg).unwrap();

    let ret = shuffle(args.0, args.1);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}


// Generate random samples from a given array (only return array index)
#[wasm_func]
pub fn choice_fn(arg: &[u8]) -> Vec<u8> {
    let args: ([u32; 3], u32, u32, bool, bool) = from_reader(arg).unwrap();

    let ret = choice(args.0, args.1, args.2, args.3, args.4);

    let mut out = Vec::new();
    into_writer(&ret, &mut out).unwrap();
    out
}
