*****
LimDB
*****

Fast, in-process key-value store with a table-like interface persisted to disk using lmdb.

Why?
####

Memory-mapped files are one of the fastest ways to store data but are not safe to
access concurrently. Lmdb is a proven and mature to solution to that problem,
offering full compliance to ACID3, a common standard for database reliability, while
keeping most of the speed.

Leveraging the excellent nim-lmdb interface, LimDB makes a larg-ish sub-set of lmdb features
available in an interface familiar to Nim users who have experience with a table.

While programming with LimDB feels like using a table, it is still very much lmdb.
Some common boilerplate is automated and LimDB is clever about bundling lmdb's moving
parts, but there are no bolted-on bits or obscuring of lmdb's behavior.

Simple Usage
############

Provide LimDB with a local storage directory and then use it like you would use a table. After
inserting the element, it's on disk an can be accessed even after the program is restarted,
or concurrently by different threads or processes.

.. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")
    db["foo"] = "bar"  # that's it, foo -> bar is now on disk
    echo db["foo"]     # prints bar

Now if you comment out the write, you can run the program again and read the value off disk
    
.. code-block:: nim
    import limdb
    let db = initDatabase("myDirectory")
    # db["foo"] = "bar"
    echo db["foo"]  # also prints "bar"

That's it. If you just need to quickly save some data, you can stop reading here and start programming.

Transactions
############

Sometimes you need to read or write to the database in several related ways that are best done as a group.
This is a common database concept and most databases support them. Reads and writes grouped in this way are
gauranteed not to be affected by other writes happening at the same time. Also, all writes are completed at once
after the transaction, and if there is an error, no writes happen at all. This goes a long way towards not
messing up your data.

A transaction is started using `initTransaction`, and stopped with either `reset` or `commit`. Use `reset` if
you only read data, or you want to throw away all writes. Use `commit` to actually perform all the writes.

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

.. caution::
    Make sure to reset transactions when exceptions are thrown. If you use
    a database object directly without calling `initTransaction`,
    LimDB handles this for you.

Iterators
#########

While you can access any data using the keys, you might want all of the data or not know the keys. You can use the usual `keys`, `values` and `pairs` iterators with a LimDB. They can be used standalone on a database or as part of a transaciton.

You can also use `mvalues` and `mpairs` to modify values on the go.

   .. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")
    let t = db.initTransaction
    t["foo"] = "bar"
    t["fuz"] = "buz"
    t.commit()

    for key in db.keys:
      echo key
    # prints:
    # foo
    # fuz
    
    let t = db.initTransaction()
    for value in t.values:
      echo value
    t.reset()
    # prints:
    # bar
    # buz

    for key, value in db:
      echo "$# -> $#" % (key, value)

    # prints:
    # foo -> bar
    # fuz -> buz

    for value in db.mvalues:
      if value == "fuz":
        value = "buzz"

    t.initTransaction
    for key, value in t.mpairs:
      if key == "foo":
        value = "barz"
    t.commit()
 
    for key, value in db:
      echo "$# -> $#" % (key, value)

    # prints:
    # foo -> barz
    # fuz -> buzz


Named Databases
###############

More than one database can be placed in the same storage location. No keys or values are shared
between databases, so the key foo will remain empty in database B if it is set in database A.

To access more than one database in the same Nim program, create an additional database from an existing
one. The connection and storage location will be shared.

The default database, the one used in the examples above, also has a name, an empty string `""`.

.. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")

    let db2 = db.initDatabase("myName")

    db["foo"] = "bar"
    db2["foo"] = "another bar

Database objects created from other database objects do not differ from ones created directly from a filename.

Only one database may be initialized from the same storage location, additional ones can be created from it.

.. caution::
    If you use named databases, their names will appear as keys in the default database,
    The one named empty string `""`.
    In this case it is usually best not to use the default database for anything else,
    and iterate over the default databases' keys to get a list of named databases.

Limitations
###########

Only strings are supported as data types, for now. In order to save other data types, they can be serialized to strings.

Improvements
############

* Use generics to support any data type that a `toBlob` and `fromBlob` can be written for. Possibly keep string versions as a shortcut.
* Use Nim views to provide an alternative interface allowing safe zero-copy data access in with Nim data types (lmdb itself does not copy data when accessing)
* Useful iterators: `keysFrom`, `keysBetween`, other common usage of lmdb cursors
* Map lmdb multipe values per key feature to something Nimish, perhaps iterators or seqs

Why is it called LimDB?
#######################

LimDB was originally named LimrodDB after the ancient king Nimrod's younger sibling,
Limrod, who didn't make it into the history books because he was short.
It was later renamed LimDB for marketing reasons.

By a wild coincidence, it also sounds a little like a vaguely pleasing jumble of Nim and LMDB.


