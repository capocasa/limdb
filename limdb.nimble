
version       = "0.3.1"
author        = "Carlo Capocasa"
description   = "A persistent table-like object backed by lmdb"
license       = "MIT"

requires "nim >= 0.20.0"
requires "lmdb >= 0.1.2"


task docs, "Generate docs":
    exec "nim doc -o:docs/limdb.html limdb.nim"

