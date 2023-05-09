# This is just an example to get you initTransactioned. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name initTransactions with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import os
import limdb
import typetraits

let testLocation = getTempDir() / "tlimdb"
removeDir(testLocation)
let db = initDatabase(testLocation)

db["foo"] = "bar"
assert db["foo"] == "bar", "write and read back"
assert db.hasKey("foo"), "key exists op"
assert "foo" in db, "in syntax"
assert len(db) == 1, "length"

db.del("foo")
doAssertRaises(Exception): discard db["foo"]
assert not db.hasKey("foo"), "key does not exist op"
assert not ("foo" in db), "not in syntax"
assert len(db) == 0, "length"

block:
  let t = db.initTransaction()
  t["fuz"] = "buz"
  assert len(t) == 1, "length with transaction"
  t.commit()

block:
  let t = db.initTransaction()
  assert t["fuz"] == "buz", "write and read back with transaction"
  assert t.hasKey("fuz"), "key exists op with ransaction"
  assert "fuz" in t, "in syntax"
  assert len(t) == 1, "length with transaction"
  t.reset()

block:
  let t = db.initTransaction()
  t.del("fuz")
  t.commit()

block:
  let t = db.initTransaction()
  doAssertRaises(Exception): discard t["fuz"]
  assert not t.hasKey("fuz"), "key does not exist op with transaction"
  assert not ("fuz" in t), "not in syntax with transaction"
  assert len(t) == 0, "length with transaction"
  t.reset()

let db2 = initDatabase(db, (db2: string, string))
doAssertRaises(Exception): discard db2["foo"]

db2["foo"] = "bar"
assert db2["foo"] == "bar", "write and read back on named database"
db2.del("foo")
doAssertRaises(Exception): discard db2["foo"]

block:
  let t = db2.initTransaction()
  t["fuz"] = "buz"
  t.commit()

block:
  let t = db2.initTransaction()
  assert t["fuz"] == "buz", "write and read back with transaction on named database"
  t.reset()

block:
  let t = db2.initTransaction()
  t.del("fuz")
  t.commit()

block:
  let t = db2.initTransaction()
  doAssertRaises(Exception): discard t["fuz"]
  t.reset()

block:
  let t = db2.initTransaction()
  t["foo"] = "bar"
  t["fuz"] = "buz"
  t["fooo"] = "baar"
  t["fuuz"] = "buuz"
  t.commit()

block:
  var s:seq[string]
  for key in db2.keys:
    s.add(key)
  assert s == @["foo", "fooo", "fuuz", "fuz"], "iterate over keys in order"

block:
  let t = db2.initTransaction()
  var s:seq[string]
  for key in t.keys:
    s.add(key)
  t.reset()
  assert s == @["foo", "fooo", "fuuz", "fuz"], "iterate over keys in order with transaction"

block:
  var s:seq[string]
  for value in db2.values:
    s.add(value)
  assert s == @["bar", "baar", "buuz", "buz"], "iterate over values in order"

block:
  let t = db2.initTransaction()
  var s:seq[string]
  for value in t.values:
    s.add(value)
  t.reset()
  assert s == @["bar", "baar", "buuz", "buz"], "iterate over values in order"

block:
  var k:seq[string]
  var v:seq[string]
  for key, value in db2:
    k.add(key)
    v.add(value)
  assert k == @["foo", "fooo", "fuuz", "fuz"], "iterate over pairs in order, keys"
  assert v == @["bar", "baar", "buuz", "buz"], "iterate over pairs in order, values"

block:
  for value in db2.mvalues:
    if value == "buuz":
      value = "baaz"

  for key, value in db2.mpairs:
    if key == "fooo":
      value = "baaa"

  var v:seq[string]
  for value in db2.values:
    v.add(value)
  assert v == @["bar", "baaa", "baaz", "buz"], "iterate over values and pairs, modifying one value each"

  assert len(db2) == 4, "count length"

block:
  let db3 = db.initDatabase((db3: string, string))
  assert db3.getOrDefault("foo") == "", "key does not exist, use default"
  db3["foo"] = "bar"
  assert db3.getOrDefault("foo") == "bar", "key there, use value"
  db3.del("foo")

  let t = db3.initTransaction()
  assert t.getOrDefault("foo") == "", "key does not exist, use default, in transaction"
  t["foo"] = "bar"
  assert t.getOrDefault("foo") == "bar", "key there, use value, in transaction"
  t.reset()

block:
  let db4 = db.initDatabase((db4: string, string))
  assert db4.hasKeyOrPut("foo", "bar") == false, "returns false if key not in database"
  assert db4["foo"] == "bar", "value was set"
  assert db4.hasKeyOrPut("foo", "fuz"), "returns true if key in database"
  assert db4["foo"] == "bar", "value was not set, still previous value"
  db4.del("foo")

  let t = db4.initTransaction
  assert t.hasKeyOrPut("foo", "bar") == false, "returns false if key does not exist in transaction"
  assert t["foo"] == "bar", "value was set"
  assert t.hasKeyOrPut("foo", "fuz"), "returns true if key in database"
  assert t["foo"] == "bar", "value was not set, still previous value"
  t.reset

block:
  let db5 = db.initDatabase((db5: string, string))
  let s = db5.getOrPut("foo", "bar")
  assert s == "bar", "value was returned"
  assert db5["foo"] == "bar", "value was put"
  let s2 = db5.getOrPut("foo", "fuz")
  assert s2 == "bar", "value in database is returned"
  db5.del("foo")

  let t = db5.initTransaction
  let s3 = t.getOrPut("foo", "bar")
  assert s3 == "bar", "value was returned"
  assert t["foo"] == "bar", "value was put"
  let s4 = t.getOrPut("foo", "fuz")
  assert s4 == "bar", "value in database is returned"
  t.reset

block:
  let db6 = db.initDatabase((db6: string, string))
  var val: string
  assert not db6.pop("foo", val), "not there"
  assert not db6.take("foo", val), "not there"
  assert val == "", "no changes"
  db6["foo"] = "bar"
  assert db6.pop("foo", val), "there"
  assert val == "bar", "assigned"
  assert not db6.hasKey("foo"), "no longer there"
  db6["foo"] = "bar"
  val = ""
  assert db6.take("foo", val), "there"
  assert val == "bar", "assigned"
  assert not db6.hasKey("foo"), "no longer there"

  let t = db6.initTransaction
  val = ""
  assert not t.pop("foo", val), "not there"
  assert not t.take("foo", val), "not there"
  assert val == "", "no changes"
  t["foo"] = "bar"
  assert t.pop("foo", val), "there"
  assert val == "bar", "assigned"
  assert not t.hasKey("foo"), "no longer there"
  t["foo"] = "bar"
  val = ""
  assert t.take("foo", val), "there"
  assert val == "bar", "assigned"
  assert not t.hasKey("foo"), "no longer there"
  t.reset

when NimMajor >= 1 and NimMinor >= 4:
  block:
    let db7 = db.initDatabase((db7: string, string))
    db7.withTransaction t:
      t["foo"] = "bar"
      t["fuz"] = "buz"

    assert db7["foo"] == "bar", "written through transaction"
    assert db7["fuz"] == "buz", "written through transaction"

    db7.withTransaction tt:
      assert tt["foo"] == "bar", "read through transaction"
      assert tt["fuz"] == "buz", "read through transaction"

    try:
      withTransaction(db7, t):
        t["buz"] = "buz"
        raise newException(CatchableError, "catch me if you can")
    except CatchableError:
      discard

    assert "buz" notin db7, "rollback on exception"

    # TODO: Test for defect on manual reset/commit

block:
  let db8 = db.initDatabase((db8: int, int))
  db8[123] = 456
  assert db8[123] == 456


block:
  let db9 = db.initDatabase((db9: int, string))
  db9[3] = "fuz"
  db9[1] = "foo"
  db9[4] = "buz"
  db9[2] = "bar"

  var a: seq[string]
  for v in db9.values:
    a.add(v)
  assert a == @["foo", "bar", "fuz", "buz"], "order by key numerically regardless of insertion order"

const p = "/tmp/db"

block:
  let db10 = db.initDatabase((db10: int, int))
  db10.withTransaction(t):
    t[3] = 3
    t[2] = 2
    t[1] = 1
    
    assert t[1] == 1
    assert t[2] == 2
    assert t[3] == 3

block:
  let db11 = db.initDatabase((db11: float, int))

  db11.withTransaction(t):
    t[3.1] = 3
    t[2.1] = 2
    t[1.1] = 1

    assert t[1.1] == 1
    assert t[2.1] == 2 
    assert t[3.1] == 3

block:
  let db12 = db.initDatabase((db12: string, string))
  db12.withTransaction(t):
    t["foo"] = "c"
    t["bar"] = "b"
    t["fuz"] = "a"
 
  var r: seq[(string, string)]
  for k, v in db12:
    r.add((k, v))

  assert r == {"bar": "b", "foo": "c", "fuz": "a"}

block:
  let db13 = db.initDatabase((db13: array[3, float], string))

  db13.withTransaction(t):
    t[ [1.1, 2.2, 3.3] ] = "foo"
    t[ [2.1, 2.2, 3.3] ] = "fuz"
    t[ [1.1, 2.2, 3.4] ] = "bar"
    

    assert t[ [1.1, 2.2, 3.3] ] == "foo"
    assert t[ [1.1, 2.2, 3.4] ] == "bar"
    assert t[ [2.1, 2.2, 3.3] ] == "fuz"

  var r: seq[(array[3, float], string)]
  for k, v in db13:
    r.add((k, v))
  assert r == {[1.1, 2.2, 3.3] : "foo", [1.1, 2.2, 3.4]: "bar", [2.1, 2.2, 3.3]: "fuz"}

type Foo = object
  a: int
  b: array[3, int]

block:
  let db14 = db.initDatabase((db14: Foo, float))

  db14.withTransaction(t):

    t[ Foo( a: 1, b: [4,5,6] ) ] = 1.1

  assert db14[ Foo( a: 1, b: [4,5,6]) ] == 1.1

block:
  let db15 = db.initDatabase((db15: int, Foo))

  db15.withTransaction(t):
    t[ 0 ] = Foo( a: 1, b: [1,2,3] )
    t[ 1 ] = Foo( a: 2, b: [4,5,6] )
  
  var r: seq[(int, Foo)]
  for k, v in db15:
    r.add((k, v))
  
  assert r == {0: Foo( a: 1, b: [1,2,3] ), 1: Foo( a: 2, b: [4,5,6] )}

block:
  let db16 = db.initDatabase((db16: (int, int), tuple[a: int, b: int]))

  db16[ (2, 4) ] = (a: 2, b: 4)
  db16[ (6, 8) ] = (a: 6, b: 8)
  
  var r: seq[((int, int), tuple[a: int, b: int])]
  db16.withTransaction(t):
    for k, v in t:
      r.add((k, v))
  
  assert r == { (2, 4): (a: 2, b: 4), (6, 8): (a: 6, b: 8) }

block:
  let db17 = db.initDatabase((db17: int, seq[float]))

  db17.withTransaction(t):
    t[0] = @[1.0,2.0,3.0]
    assert t[0] == @[1.0,2.0,3.0]

type
  FooNum = enum
    w, x, y, z
  LetterNum = enum
    a = 10, b = 20, c = 30, d = 40

block:
  let db18 = db.initDatabase((db18: FooNum, LetterNum))

  db18.tx:  # ultra-shorthand
    tx[x] = c
    tx[z] = d

  assert db18[x] == c
  assert db18[z] == d
 
  # force writable
  db18.withTransaction t, readwrite:
    t[x] = a
  
  db18.tx:
    tx[z] = b

  # read only
  db18.withTransaction abc, readonly:
    assert abc[x] == a

  db18.tx ro:
    assert tx[z] == b


block:
  let db19 = db.initDatabase((db19: int, string))
  let db20 = db.initDatabase((db21: float, float))
  let db21 = db.initDatabase((db122: string, int))

  let t = initTransaction((db19, db20, db21))
  t[0][3] = "foo"
  t[1][1.1] = 2.2
  t[2]["bar"] = 6
  t[0].commit

  let dbs = (db19, db20, db21)
  let (t0, t1, t2) = initTransaction(dbs, readonly)
  assert t0[3] == "foo"
  assert t1[1.1] == 2.2
  assert t2["bar"] == 6
  t0.reset

  try:
    t[1][3.3] = 4.4
    assert false, "transaction committed"
  except IOError: # transaction no longer valid
    discard
  
  dbs.withTransaction t:
    assert t[0][3] == "foo"
    t[0][4] = "bar"
  assert db19[4] == "bar"

  let dbs2 = (a: db19, b: db20, c: db21)
  let v = initTransaction(dbs2)
  v.a[6] = "fuz"
  v.b[3.3] = 6.6
  v.c["buz"] = 12
  v.commit

  let w = (a: db19, b: db20, c: db21).initTransaction readonly
  assert w.a[6] == "fuz"
  assert w.b[3.3] == 6.6
  assert w.c["buz"] == 12
  w.reset

  dbs2.withTransaction t, readwrite:
    assert t.a[6] == "fuz"
    t.a[7] = "buz"
  assert db19[7] == "buz"

  dbs.tx:
    tx[0][5] = "fuz"
  dbs.tx ro:
    assert tx[0][5] == "fuz"

  dbs2.tx rw:
    tx.a[9] = "foo"
  dbs2.tx:
    assert tx.a[9] == "foo"
  # TODO: test static errors.
  # `db[1] = 2` in explicit readonly for initTransaction, withTransaction and tx
  # `t.commit/t.reset` in transaction block

block:
  let testLocation2 = getTempDir() / "tlimdb2"
  removeDir(testLocation2)
  let dbs = initDatabase(testLocation2, (foo: int, bar: int, string, fuz: FooNum, LetterNum))

  assert dbs.foo is Database[int, int]
  assert dbs.bar is Database[int, string]
  assert dbs.fuz is Database[FooNum, LetterNum]
  assert dbs.tupleLen == 3

  let db = initDatabase(testLocation2, (int, int))
  assert db is Database[int, int]
  
  # TODO: assert compile error for
  # let db = initDatabase(testLocation2, (int, int, int))

