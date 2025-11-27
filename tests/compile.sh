#!/bin/bash

find . -name "*.typ" | xargs -i typst c --root .. --no-pdf-tags {}

