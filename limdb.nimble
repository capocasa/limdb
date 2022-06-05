
version       = "0.1.0"
author        = "Carlo Capocasa"
description   = "A persistent table-like object backed by lmdb"
license       = "MIT"

requires "lmdb"

task test, "Run tests":
    exec "nim c -r tests/tlimdb"
    rmFile "tests/tlimdb"

task docs, "Generate docs":
    exec "nim doc -o:docs/limdb.html limdb.nim"

