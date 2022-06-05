## .. include:: docs.rst

# this is mainly here to temporarily store form data after each keystroke
# it probably doesn't matter at the likely scale of usage, but it just seems
# like such bad fit for sqllite to write to the darn file and block comment loading
# whenever someone presses a key. Hence, way overkill but lovely, lmdb.

# could do it on the client but it will just be such a pleasant surprise when
# someone finds a half-finished comment already there when loading on another device

import std/os, lmdb

export lmdb

type
  Database* = object
    env*: LMDBEnv
    dbi*: Dbi

  Transaction* = object
    txn*: LMDBTxn
    dbi*: Dbi

proc open*(db: Database, name: string): Dbi =
  let dummy = db.env.newTxn()  # lmdb quirk, need an initial txn to open dbi that can be kept
  result = dummy.dbiOpen(name, if name == "": 0 else: lmdb.CREATE)
  dummy.commit()

proc initDatabase*(filename = "", name = "", maxdbs = 255): Database =
  createDir(filename)
  result.env = newLMDBEnv(filename, maxdbs)
  result.dbi = result.open(name)

proc initDatabase*(db: Database, name = ""): Database =
  result.env = db.env
  result.dbi = result.open(name)

proc initTransaction*(db: Database): Transaction =
  result.dbi = db.dbi
  result.txn = db.env.newTxn()

proc `[]`*(t: Transaction, key: string): string =
  lmdb.get(t.txn, t.dbi, key)

proc `[]=`*(t: Transaction, key, value: string) =
  lmdb.put(t.txn, t.dbi, key, value)

proc del*(t: Transaction, key, value: string) =
  # weird lmdb quirk, you delete with both key and value because you can "shadow"
  # a key's value with another put
  lmdb.del(t.txn, t.dbi, key, value)

template del*(t: Transaction, key: string) =
  # shortcut here to just get rid of one of the values
  lmdb.del(t.txn, t.dbi, key, lmdb.get(t.txn, t.dbi, key))

proc hasKey*(t: Transaction, key: string): bool =
  var key = key
  var k = Val(mvSize: key.len.uint, mvData: key.cstring)
  var dummy:Val
  return 0 == get(t.txn, t.dbi, addr(k), addr(dummy))

proc contains*(t: Transaction, key: string): bool =
  hasKey(t, key)

proc commit*(t: Transaction) =
  t.txn.commit()

proc reset*(t: Transaction) =
  t.txn.abort()

proc `[]`*(db: Database, key: string): string =
  let t = db.initTransaction()
  try:
    result = t[key]
  finally:
    t.reset()

proc `[]=`*(d: Database, key, value: string) =
  let t = d.initTransaction()
  try:
    t[key] = value
  except:
    t.reset()
    raise
  t.commit()

proc del*(db: Database, key, value: string) =
  let t = db.initTransaction()
  try:
    t.del(key, value)
  except:
    t.reset()
    raise
  t.commit()

proc del*(db: Database, key: string) =
  let t = db.initTransaction()
  try:
    t.del(key)
  except:
    t.reset()
    raise
  t.commit()

proc hasKey*(db: Database, key: string):bool =
  let t = db.initTransaction()
  result = t.hasKey(key)
  t.reset()

proc contains*(db: Database, key:string):bool =
  hasKey(db, key)

iterator keys*(t: Transaction): string =
  let cursor = cursorOpen(t.txn, t.dbi)
  var k:Val
  var d:Val
  let err = cursorGet(cursor, addr(k), addr(d), lmdb.FIRST)
  if err == 0:
    var key = newStringOfCap(k.mvSize)
    key.setLen(k.mvSize)
    copyMem(cast[pointer](key.cstring), cast[pointer](k.mvData), k.mvSize)
    yield key
    while true:
      let err = cursorGet(cursor, addr(k), addr(d), op=NEXT)
      if err == 0:
        var key = newStringOfCap(k.mvSize)
        key.setLen(k.mvSize)
        copyMem(cast[pointer](key.cstring), cast[pointer](k.mvData), k.mvSize)
        yield key
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator values*(t: Transaction): string =
  let cursor = cursorOpen(t.txn, t.dbi)
  var k:Val
  var d:Val
  let err = cursorGet(cursor, addr(k), addr(d), lmdb.FIRST)
  if err == 0:
    var data = newStringOfCap(d.mvSize)
    data.setLen(d.mvSize)
    copyMem(cast[pointer](data.cstring), cast[pointer](d.mvData), d.mvSize)
    yield data
    while true:
      let err = cursorGet(cursor, addr(k), addr(d), op=NEXT)
      if err == 0:
        var data = newStringOfCap(d.mvSize)
        data.setLen(d.mvSize)
        copyMem(cast[pointer](data.cstring), cast[pointer](d.mvData), d.mvSize)
        yield data
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator pairs*(t: Transaction): (string, string) =
  let cursor = cursorOpen(t.txn, t.dbi)
  var k:Val
  var d:Val
  let err = cursorGet(cursor, addr(k), addr(d), lmdb.FIRST)
  if err == 0:
    var key = newStringOfCap(k.mvSize)
    key.setLen(k.mvSize)
    copyMem(cast[pointer](key.cstring), cast[pointer](k.mvData), k.mvSize)
    var data = newStringOfCap(d.mvSize)
    data.setLen(d.mvSize)
    copyMem(cast[pointer](data.cstring), cast[pointer](d.mvData), d.mvSize)
    yield (key, data)
    while true:
      let err = cursorGet(cursor, addr(k), addr(d), op=NEXT)
      if err == 0:
        var key = newStringOfCap(k.mvSize)
        key.setLen(k.mvSize)
        copyMem(cast[pointer](key.cstring), cast[pointer](k.mvData), k.mvSize)
        var data = newStringOfCap(d.mvSize)
        data.setLen(d.mvSize)
        copyMem(cast[pointer](data.cstring), cast[pointer](d.mvData), d.mvSize)
        yield (key, data)
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator keys*(db: Database): string =
  let t = db.initTransaction()
  for key in t.keys:
    yield key
  t.reset()

iterator values*(db: Database): string =
  let t = db.initTransaction()
  for value in t.values:
    yield value
  t.reset()

iterator pairs*(db: Database): (string, string) =
  let t = db.initTransaction()
  for pair in t.pairs:
    yield pair
  t.reset()

