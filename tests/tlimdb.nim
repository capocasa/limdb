# This is just an example to get you initTransactioned. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name initTransactions with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import os
import limdb

let db = initDatabase(getTempDir() / "testlimdb")

db["foo"] = "bar"
assert db["foo"] == "bar", "write and read back"
assert db.hasKey("foo"), "key exists op"
assert "foo" in db, "in syntax"

db.del("foo")
doAssertRaises(Exception): discard db["foo"]
assert not db.hasKey("foo"), "key does not exist op"
assert not ("foo" in db), "not in syntax"

block:
  let t = db.initTransaction()
  t["fuz"] = "buz"
  t.commit()

block:
  let t = db.initTransaction()
  assert t["fuz"] == "buz", "write and read back with transaction"
  assert t.hasKey("fuz"), "key exists op with ransaction"
  assert "fuz" in t, "in syntax"
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
  t.reset()

let db2 = db.initDatabase("foodb")
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


