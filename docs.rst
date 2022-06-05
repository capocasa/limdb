*****
limdb
*****

Fast in-process key-value store with a table-like interface backed by lmdb.

Why?
####

Memory-mapped files are one of the fastest ways to store data but are not
thread-safe or consistent, which is solved keeping most of the speed by a
mature database project called lmdb. Using the excellent nim-lmdb, limdb
makes a sub-set of lmdb features familiar to use by resembling a persistent Nim table.

Simple Usage
############

limdb acts similarly to a Nim table, except that you specify a storage location on creation.

.. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")
    db["foo"] = "bar"  # that's it, foo -> bar is now on disk

If you just need to quickly save some data, you can stop reading here.

Transactions
############

Transactions are supported, so read or written data will be consistent even if concurrently.

Writes are grouped so either all writes of a transaction are performe or none at all.

.. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")
    let t = db.initTransaction
    t["foo"] = "bar"
    t["fuz"] = "buz"
    t.commit()
    
    let t = db.initTransaction
    t["foo"] = "another bar"
    t["fuz"] = "another buz"
    t.reset()  # foo and bar remain unchanged

    let t = db.initTransaction
    echo t["foo"]
    echo t["bar"]
    t.reset()  # read-only transactions are always reset

.. caution ::
    Make sure to reset transactions when exceptions are thrown. In Simple usage,
    limdb handles this for you.

Named Databases
###############

More than one database can be placed in the same storage location. No keys or values are shared
between databases, so the key foo will remain empty in database B if it is set in database A.

To access more than one database in the same Nim program, create an additional database from an existing
one. The connection and storage location will be shared.

The default database, the one used in the examples above, also has a name, an empty string `""`.

    import limdb
    let db = initDatabase("myDirectory")

    let db2 = db.initDatabase("myName")

    db["foo"] = "bar"
    db2["foo"] = "another bar

Database objects created from other database objects do not differ from ones created directly from a filename.

Only one database may be initialized from the same storage location, additional ones can be created from it.

Why is it called limdb?
#######################

Limdb was originally named Limroddb after the ancient king Nimrod's younger sibling,
Limrod, who didn't make it into the history books because of his diminuitive stature.
It was renamed Limdb for marketing reasons.

It also sounds a little like a vaguely pleasing jumble of Nim and Lmdb.


