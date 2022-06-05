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
    ## A key-value database in a memory-mapped on-disk storage location.
    env*: LMDBEnv
    dbi*: Dbi

  Transaction* = object
    ## A transaction may be created and reads or writes performed on it instead of directly
    ## on a database object. That way, reads or writes are not affected by other writes happening
    ## at the same time, and changes happen all at once at the end or not at all.
    txn*: LMDBTxn
    dbi*: Dbi

  Blob* = Val
    ## A variable-length collection of bytes that can be used as either a key or value. This
    ## is LMDB's native storage type- a block of memory. `string` types are converted automatically,
    ## and conversion for other data types can be added by adding `fromBlob` and `toBlob` for a type.

proc open*(db: Database, name: string): Dbi =
  # Open a database and return a low-level handle
  let dummy = db.env.newTxn()  # lmdb quirk, need an initial txn to open dbi that can be kept
  result = dummy.dbiOpen(name, if name == "": 0 else: lmdb.CREATE)
  dummy.commit()

proc initDatabase*(filename = "", name = "", maxdbs = 255): Database =
  ## Connect to an on-disk storage location and open a database. If the path does not exist,
  ## a directory will be created.
  createDir(filename)
  result.env = newLMDBEnv(filename, maxdbs)
  result.dbi = result.open(name)

proc initDatabase*(db: Database, name = ""): Database =
  ## Open another database of a different name in an already-connected on-disk storage location.
  result.env = db.env
  result.dbi = result.open(name)

proc initTransaction*(db: Database): Transaction =
  ## Start a transaction from a database.
  ##
  ## Reads and writes on the transaction will reflect the same
  ## point in time and will not be affected by other writes.
  ##
  ## After reads, `reset` must be called on the transaction. After writes,
  ## `commit` must be called to perform all of the writes, or `reset` to perform
  ## none of them.
  ##
  ## .. caution::
  ##     Calling neither `reset` nor `commit` on a transaction can block database access.
  ##     This commonly happens when an exception is raised.
  result.dbi = db.dbi
  result.txn = db.env.newTxn()

proc toBlob*(s: string): Blob =
  ## Convert a string to a chunk of data, key or value, for LMDB
  ## .. note::
  ##     If you want other data types than a string, implement this for the data type
  result.mvSize = s.len.uint
  result.mvData = s.cstring

proc fromBlob*(b: Blob): string =
  ## Convert a chunk of data, key or value, to a string
  ## .. note::
  ##     If you want other data types than a string, implement this for the data type
  result = newStringOfCap(b.mvSize)
  result.setLen(b.mvSize)
  copyMem(cast[pointer](result.cstring), cast[pointer](b.mvData), b.mvSize)

proc `[]`*(t: Transaction, key: string): string =
  # Read a value from a key in a transaction
  var k = key.toBlob
  var d: Blob
  let err = lmdb.get(t.txn, t.dbi, addr(k), addr(d))
  if err == 0:
    result = d.fromBlob
  elif err == lmdb.NOTFOUND:
    raise newException(KeyError, $strerror(err))
  else:
    raise newException(Exception, $strerror(err))

proc `[]=`*(t: Transaction, key, value: string) =
  # Write a value to a key in a transaction
  var k = key.toBlob
  var v = value.toBlob
  let err = lmdb.put(t.txn, t.dbi, addr(k), addr(v), 0)
  if err == 0:
    return
  elif err == lmdb.NOTFOUND:
    raise newException(KeyError, $strerror(err))
  else:
    raise newException(Exception, $strerror(err))

proc del*(t: Transaction, key, value: string) =
  ## Delete a key-value pair
  # weird lmdb quirk, you delete with both key and value because you can "shadow"
  # a key's value with another put
  var k = key.toBlob
  var v = value.toBlob
  let err = lmdb.del(t.txn, t.dbi, addr(k), addr(v))
  if err == 0:
    return
  elif err == lmdb.NOTFOUND:
    raise newException(KeyError, $strerror(err))
  else:
    raise newException(Exception, $strerror(err))

template del*(t: Transaction, key: string) =
  ## Delete a value in a transaction
  ## .. note::
  ##     LMDB requires you to delete by key and value. This proc fetches
  ##     the value for you, giving you the more familiar interface.
  t.del(key, t[key])

proc hasKey*(t: Transaction, key: string): bool =
  ## See if a key exists without fetching any data
  var key = key
  var k = Blob(mvSize: key.len.uint, mvData: key.cstring)
  var dummy:Blob
  return 0 == get(t.txn, t.dbi, addr(k), addr(dummy))

proc contains*(t: Transaction, key: string): bool =
  ## Alias for hasKey to support `in` syntax
  hasKey(t, key)

proc commit*(t: Transaction) =
  ## Commit a transaction. This writes all changes made in the transaction to disk.
  t.txn.commit()

proc reset*(t: Transaction) =
  ## Reset a transaction. This throws away all changes made in the transaction.
  ## After only reading in a transaction, reset it as well.
  ## .. note::
  ##     This is called `reset` because that is a pleasant and familiar term for reverting
  ##     changes. The term differs from LMDB though, under the hood this calles `mdb_abort`,
  ##     not `mdb_reset`- the latter does something else not covered by LimDB.
  t.txn.abort()

proc `[]`*(db: Database, key: string): string =
  ## Fetch a value in the database
  ## .. note::
  ##     This inits and resets a transaction under the hood
  let t = db.initTransaction
  try:
    result = t[key]
  finally:
    t.reset()

proc `[]=`*(d: Database, key, value: string) =
  ## Set a value in the database
  ## .. note::
  ##     This inits and commits a transaction under the hood
  let t = d.initTransaction
  try:
    t[key] = value
  except:
    t.reset()
    raise
  t.commit()

proc del*(db: Database, key, value: string) =
  ## Delete a key-value pair in the database
  ## .. note::
  ##     This inits and commits a transaction under the hood
  let t = db.initTransaction
  try:
    t.del(key, value)
  except:
    t.reset()
    raise
  t.commit()

proc del*(db: Database, key: string) =
  ## Deletes a value in the database
  ## .. note::
  ##     This inits and commits a transaction under the hood
  ## .. note::
  ##     LMDB requires you to delete by key and value. This proc fetches
  ##     the value for you, giving you the more familiar interface.
  let t = db.initTransaction
  try:
    t.del(key)
  except:
    t.reset()
    raise
  t.commit()

proc hasKey*(db: Database, key: string):bool =
  ## See if a key exists without fetching any data in a transaction
  let t = db.initTransaction
  result = t.hasKey(key)
  t.reset()

proc contains*(db: Database, key:string):bool =
  ## Alias for hasKey to support `in` syntax in transactions
  hasKey(db, key)

iterator keys*(t: Transaction): string =
  ## Iterate over all keys in a database with a transaction
  let cursor = cursorOpen(t.txn, t.dbi)
  var key:Blob
  var data:Blob
  let err = cursorGet(cursor, addr(key), addr(data), lmdb.FIRST)
  if err == 0:
    yield fromBlob(key)
    while true:
      let err = cursorGet(cursor, addr(key), addr(data), op=NEXT)
      if err == 0:
        yield key.fromBlob
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator values*(t: Transaction): string =
  ## Iterate over all values in a database with a transaction.
  let cursor = cursorOpen(t.txn, t.dbi)
  var key:Blob
  var data:Blob
  let err = cursorGet(cursor, addr(key), addr(data), lmdb.FIRST)
  if err == 0:
    yield fromBlob(data)
    while true:
      let err = cursorGet(cursor, addr(key), addr(data), op=NEXT)
      if err == 0:
        yield fromBlob(data)
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator mvalues*(t: Transaction): var string =
  ## Iterate over all values in a database with a transaction, allowing
  ## the values to be modified.
  let cursor = cursorOpen(t.txn, t.dbi)
  var key:Blob
  var data:Blob
  let err = cursorGet(cursor, addr(key), addr(data), lmdb.FIRST)
  if err == 0:
    var d: ref string
    new(d)
    d[] = fromBlob(data)
    yield d[]
    var mdata = d[].toBlob
    if 0 != cursorPut(cursor, addr(key), addr(mdata), 0):
      cursor.cursorClose
      raise newException(Exception, $strerror(err))
    while true:
      let err = cursorGet(cursor, addr(key), addr(data), op=NEXT)
      if err == 0:
        var d:ref string
        new(d)
        d[] = fromBlob(data)
        yield d[]
        var mdata = d[].toBlob
        if 0 != cursorPut(cursor, addr(key), addr(mdata), 0):
          cursor.cursorClose
          raise newException(Exception, $strerror(err))
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator pairs*(t: Transaction): (string, string) =
  ## Iterate over all key-value pairs in a database with a transaction.
  let cursor = cursorOpen(t.txn, t.dbi)
  var key:Blob
  var data:Blob
  let err = cursorGet(cursor, addr(key), addr(data), lmdb.FIRST)
  if err == 0:
    yield (fromBlob(key), fromBlob(data))
    while true:
      let err = cursorGet(cursor, addr(key), addr(data), op=NEXT)
      if err == 0:
        yield (fromBlob(key), fromBlob(data))
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator mpairs*(t: Transaction): (string, var string) =
  ## Iterate over all key-value pairs in a database with a transaction, allowing
  ## the values to be modified.
  let cursor = cursorOpen(t.txn, t.dbi)
  var key:Blob
  var data:Blob
  let err = cursorGet(cursor, addr(key), addr(data), lmdb.FIRST)
  if err == 0:
    var d: ref string
    new(d)
    d[] = data.fromBlob
    yield (key.fromBlob, d[])
    var mdata = d[].toBlob
    if 0 != cursorPut(cursor, addr(key), addr(mdata), 0):
      cursor.cursorClose
      raise newException(Exception, $strerror(err))
    while true:
      let err = cursorGet(cursor, addr(key), addr(data), op=NEXT)
      if err == 0:
        var d:ref string
        new(d)
        d[] = data.fromBlob
        yield (key.fromBlob, d[])
        var mdata = d[].toBlob
        if 0 != cursorPut(cursor, addr(key), addr(mdata), 0):
          cursor.cursorClose
          raise newException(Exception, $strerror(err))
      elif err == lmdb.NOTFOUND:
        cursor.cursorClose
        break
      else:
        cursor.cursorClose
        raise newException(Exception, $strerror(err))

iterator keys*(db: Database): string =
  ## Iterate over all keys pairs in a database.
  ## .. note::
  ##     This inits and resets a transaction under the hood
  let t = db.initTransaction
  for key in t.keys:
    yield key
  t.reset()

iterator values*(db: Database): string =
  ## Iterate over all values in a database
  ## .. note::
  ##     This inits and resets a transaction under the hood
  let t = db.initTransaction
  for value in t.values:
    yield value
  t.reset()

iterator pairs*(db: Database): (string, string) =
  ## Iterate over all values in a database
  ## .. note::
  ##     This inits and resets a transaction under the hood
  let t = db.initTransaction
  for pair in t.pairs:
    yield pair
  t.reset()

iterator mvalues*(db: Database): var string =
  ## Iterate over all values in a database allowing modification
  ## .. note::
  ##     This inits and resets a transaction under the hood
  let t = db.initTransaction
  for value in t.mvalues:
    yield value
  t.commit()

iterator mpairs*(db: Database): (string, var string) =
  ## Iterate over all key-value pairs in a database allowing the values
  ## to be modified
  ## .. note::
  ##     This inits and resets a transaction under the hood
  let t = db.initTransaction
  for k, v in t.mpairs:
    yield (k, v)
  t.commit()

proc copy*(db: Database, filename: string) =
  ## Copy a database to a different directory. This also performs routine database
  ## maintenance so the resulting file with usually be smaller. This is best performed
  ## when no one is writing to the database directory.
  let err = envCopy(db.env, filename.cstring)
  if err != 0:
    raise newException(Exception, $strerror(err))

template clear*(t: Transaction) =
  ## Remove all key-values pairs from the database, emptying it.
  ## .. note::
  ##     The size of the database will stay the same on-disk but won't grow until
  ##     more data than was in there before is added. It will shrink if it is copied.
  emptyDb(t.txn, t.dbi)

proc clear*(db: Database) =
  ## Remove all key-values pairs from the database, emptying it.
  ## .. note::
  ##     This creates and commits a transaction under the hood
  let t = db.initTransaction
  t.clear
  t.commit

proc close(db: Database) =
  ## Close the database directory. This will free up some memory and make all databases
  ## that were created from the same directory unavailable. This is not necessary for many use cases.
  ## .. note::
  ##     This creates and commits a transaction under the hood
  envClose(db.env)


