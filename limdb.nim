
# this is mainly here to temporarily store form data after each keystroke
# it probably doesn't matter at the likely scale of usage, but it just seems
# like such bad fit for sqllite to write to the darn file and block comment loading
# whenever someone presses a key. Hence, way overkill but lovely, lmdb.

# could do it on the client but it will just be such a pleasant surprise when
# someone finds a half-finished comment already there when loading on another device

import std/os, std/tables, lmdb

export lmdb

type
  Database* = object
    env*: LMDBEnv
    namespaces*: TableRef[string, Dbi]  # TODO: why doesn't Table work here?

  Transaction* = object
    txn*: LMDBTxn
    dbi*: Dbi

proc initDatabase*(filename: string): Database =
  createDir(filename)
  result.env = newLMDBEnv(filename)
  result.namespaces = newTable[string, Dbi]()

proc initNamespace*(db: Database, namespace= "", args:uint = 0): Dbi =
  let dummy = db.env.newTxn()  # lmdb quirk, need an initial txn to open dbi that can be kept
  result = dummy.dbiOpen(namespace, args.cuint)
  dummy.commit()

proc start*(db: Database, namespace:string = "", args:uint = 0): Transaction =
  if not (namespace in db.namespaces):
    db.namespaces[namespace] = initNamespace(db, namespace, args)
  result.dbi = db.namespaces[namespace]
  result.txn = db.env.newTxn()

proc `[]`*(t: Transaction, key: string): string =
  lmdb.get(t.txn, t.dbi, key)

proc `[]=`*(t: Transaction, key, value: string) =
  lmdb.put(t.txn, t.dbi, key, value)

proc del*(t: Transaction, key, value: string) =
  # weird lmdb quirk, you delete with both key and value because you can "shadow"
  # a key's value with another put
  lmdb.del(t.txn, t.dbi, key, value)

proc del*(t: Transaction, key: string) =
  # shortcut here to just get rid of one of the values
  lmdb.del(t.txn, t.dbi, key, lmdb.get(t.txn, t.dbi, key))

proc commit*(t: Transaction) =
  t.txn.commit()

proc release*(t: Transaction) =
  t.txn.abort()

proc `[]`*(d: Database, key: string, namespace=""): string =
  let t = d.start(namespace)
  result = t[key]
  t.release()

proc `[]=`*(d: Database, key, value: string, namespace="") =
  let t = d.start(namespace)
  t[key] = value
  t.commit()

proc del*(db: Database, key, value: string, namespace="") =
  let t = db.start(namespace)
  t.del(key, value)
  t.commit()

proc del*(db: Database, key: string, namespace="") =
  let t = db.start(namespace)
  t.del(key)
  t.commit()

