#!/bin/bash

find . -name "*.typ" | xargs -i hyperfine --warmup=1 --runs=10 "typst c --root .. --ppi=10 --format=png {}"
