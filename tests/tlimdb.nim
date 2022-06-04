# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import limdb

let db = initDatabase("testlimdb")

db["foo"] = "bar"
assert db["foo"] == "bar", "high level write and read back"
db.del("foo")
doAssertRaises(Exception): discard db["foo"]

block:
  let t = db.start()
  t["fuz"] = "buz"
  t.commit()

block:
  let t = db.start()
  assert t["fuz"] == "buz", "write and read back via explicit transaction"
  t.release()

block:
  let t = db.start()
  t.del("fuz")
  t.commit()

block:
  let t = db.start()
  doAssertRaises(Exception): discard t["fuz"]
  t.release()

