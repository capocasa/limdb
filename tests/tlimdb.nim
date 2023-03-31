# This is just an example to get you initTransactioned. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name initTransactions with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import os
import limdb

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

let db2 = db.initDatabase("db2")
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
  let db3 = db.initDatabase("db3")
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
  let db4 = db.initDatabase("db4")
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
  let db5 = db.initDatabase("db5")
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
  let db6 = db.initDatabase("db6")
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


