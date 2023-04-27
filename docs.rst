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
    let db = initDatabase[string, string]("myDirectory")
    db["foo"] = "bar"  # that's it, foo -> bar is now on disk
    echo db["foo"]     # prints bar

Now if you comment out the write, you can run the program again and read the value off disk
    
.. code-block:: nim
    import limdb
    let db = initDatabase[string, string]("myDirectory")
    # db["foo"] = "bar"
    echo db["foo"]  # also prints "bar"

That's it. If you just need to quickly save some data, you can stop reading here and start programming.

Reading and writing in blocks
#############################

It's usually good practice to organize related reads and writes to any database into a kind of unit- in
database-speak, this is called a *transaction*. A transaction makes sure that all reads and writes
performed through it can be safely assumed to be happening at the exact same time and without interference.
It is also made sure that all changes happen, or none do- you there is an error in your code, or the power
goes out, either the transaction happened or it didn't- there is no in-between to break your database. 

With LimDB, use a `with`-block on your database to perform all reads and writes in the block in a transaction.
The block contains a special variable `t` containing the transaction. You can work on it using the same
read- and write operations as you can with a database object.

.. code-block:: nim
    import limdb
    let db = initDatabase[string, string]("myDirectory")
    with db:
      t["foo"] = "bar"
      echo t["foo"]

If you don't put any read operations in your code, the transaction is reset under the hood, giving you extra
assurances there aren't any accidental writes happening.

If there is an error in your code that isn't caught within the `with`-block, the transaction is always reset.

.. code-block:: nim
    import limdb
    let db = initDatabase[string, string]("myDirectory")
    with db:
      t["foo"] = "bar"
   
      # triggers a KeyError, program exits and
      # t["foo"] = "bar" does not end up in the database
      echo t["fuz"] 

If you need to make some writes you're might need to reset based
on further conditions, you can raise an exception
and catch it outside the block.

.. code-block:: nim
    import limdb

    proc valid(): bool = 
      false  # a real program would perform checks here 

    let db = initDatabase[string, string]("myDirectory")
    try:
      with db:
        t["foo"] = "bar"
        if not valid():
          raise newException(ValueError)
    except ValueError:
      discard
      # t["foo"] was not set to "bar"

You can also catch exceptions the standard library raises like this.

Iterators
#########

While you can access any data using the keys, you might want all of the data or not know the keys. You can use the usual `keys`, `values` and `pairs` iterators with a LimDB. They can be used standalone on a database or as part of a transaciton.

You can also use `mvalues` and `mpairs` to modify values on the go.

   .. code-block:: nim

    import limdb
    let db = initDatabase[string, string]("myDirectory")
    with db:
      t["foo"] = "bar"
      t["fuz"] = "buz"

    for key in db.keys:
      echo key
    # prints:
    # foo
    # fuz

    with db:
      for value in t.values:
        echo value
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

    with db:
      for key, value in t.mpairs:
        if key == "foo":
          value = "barz"
 
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
    let db = initDatabase[string, string]("myDirectory")

    let db2 = db.initDatabase[:string, string]("myName")

    db["foo"] = "bar"
    db2["foo"] = "another bar

Database objects created from other database objects do not differ from ones created directly from a filename.

Only one database may be initialized from the same storage location, additional ones can be created from it.

.. note ::
    Note the use of `[: ]` notation for the types when creating another database in the same directory
    using method-call notation. You can call `initDatabase[string, string](db, "myName")` instead of
    `db.initDatabase[:string, string]("myName")` if you prefer.

.. caution::
    If you use named databases, their names will appear as keys in the default database,
    The one named empty string `""`.
    In this case it is usually best not to use the default database for anything else,
    and iterate over the default databases' keys to get a list of named databases.


Data Types
##########

So far, we have only been using strings for keys and values. But you can use any system data type you like except references.

You can create several databases in the same directory with different data types.

.. code-block:: nim
    import limdb
    let db = initDatabase[int, float]("myDirectory", "aDatabaseWithNumbers")

    db[3] = 3.3

    type
      Foo = object
        a: int
        b: float

    let db2 = db.initDatabase[: array[2, int], Foo ]("aDatabaseWithArraysAndObjects")
    with db:
      t[ [1, 2] ] = Foo(a: 1, b: 2.2)
      t[ [3, 4] ] = Foo(a: 3, b: 4.4)


    let db3 = db.initDatabase[: (int, int), tuple[a: int, b: float] ]("aDatabaseWithTuples")

    db3[ (1, 2) ] = (a: 1, b: 2.2)
    db3[ (3, 4) ] = (a: 3, b: 4.4)

.. note::
    All supported data types are binary-copied in and out of the database, so their performance characteristics are the same. As usual with Nim, seq and string are copied once.

.. caution::
    It is recommended to hard-code the data types and the database name to make sure each database is only used with the data types
    that were already written to it. Opening a database with the wrong types can lead to unpredictable behavior, and writing to a
    database with the wrong types can lead to data loss.

Custom data types
#################

If you need different data types, the simplest way is to convert them to a supported
data type before entering them and after retrieving them.

.. code-block:: nim
   import datetime
   let db = initDatabase[string, float]("myDirectory")
   db["now'] = now().toUnixTime

   echo db["now"].fromUnixTime  # prints datetime

If you have complex data structures, you can also use your favorite serialization library to serialize
them to string before saving them as key or value.

.. code-block:: nim
   # requires flatty package
   import flatty 
   type
     Foo:
       seq[ seq[int] ]
     Bar = object
       a: ref string
       b: seq[ref Foo]
   let db = initDatabase[string, string]("myDirectory")
   db["foo"] = Bar().toFlatty
   let foo = db["foo"].fromFlatty(Bar)

If you want to have more syntactic convenience, you can add your own types to LimDB by
implementing `toBlob`, `fromBlob` as `proc` or `template`.

The safe-and-easy way is to pre-process your type into one of the data types supported by LimDB.
This is mainly for convenience, it doesn't run any faster than converting manually.

.. code-block:: nim
    import datetime

    template toBlob(d: DateTime): Blob
      d.toUnixTime.toBlob
    
    template fromBlob(b: Blob): DateTime
      b.fromBlob(float).fromUnixTime
    
    template compare(a, b: DateTime): DateTime
      b.fromBlob(float).fromUnixTime

    let db = initDatabase[string, DateTime]("myDirectory")
    db["now'] = now()

    echo db["now"].fromUnixTime  # prints datetime

You can also implement your type manually for more speed and control. In this case, you also need
to supply a `compare` template or procedure that returns `1` if the `b` argument is larger, `-1` if
the `a` argument is larger, or `0` if they are equal.

.. code-block:: nim

    template toBlob(a: MyType): Blob
      Blob(mvSize: sizeof(a), mvData: cast[pointer](a.addr))
    
    proc fromBlob(b: Blob): DateTime
      result = cast[ptr T](b.mvData)[]

    proc compare(a, b: MyType): int =
      # assuming here that <, > and == are implemented for MyType
      if a < b:
        -1
      elif a > b:
        1
      else:
        0

    let db = initDatabase[string, DateTime]("myDirectory")
    db["now'] = now()

    echo db["now"].fromUnixTime  # prints datetime

.. caution::
    You are responsible for ensuring memory safety if you work with `Blob` types directly

Manual transactions
###################

If you want

Grouped reads and writes use a process called database transactions under the hood. They are quite
common and most databases support them. At the beginning of a grouped read and write, a transaction `t` is created. At the end of the block, it is reset if there are only read operations like `[]` in the block. If there is at least one write such as `[]=` or `del`, it is committed.

If you would like to have more control, at the expense of having to be more careful, a transaction is started manually using `initTransaction`, and stopped with either `reset` or `commit`. Use `reset` if
you only read data, or you want to throw away all writes. Use `commit` to actually perform all the writes.

.. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")
    let t = db.initTransaction
    t["foo"] = "bar"
    t["fuz"] = "buz"se
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


Improvement Areas Of Interest
#############################

* Use Nim views to provide an alternative interface allowing safe zero-copy data access in with Nim data types (lmdb itself does not copy data when accessing)
* Useful iterators: `keysFrom`, `keysBetween`, other common usage of lmdb cursors
* Map lmdb multipe values per key feature to something Nimish, perhaps iterators or seqs

Migrating from 0.2
##################

This version 0.3 breaks backwards compatibility with 0.2 in order to support the normal Nim generic syntax.

You can `requires limdb=0.2` in your myProject.nimble file to keep the functionality you are used to, or make the following replacements to your code to upgrade:

Replace

    initDatabase("myDir")

with
    
    initDatabase[string, string]("path")

And

    db.initDatabase("dbname")

with
    
    db.initDatabase[:string, string]("dbname")

If you would like to stay at 0.2, the `0.2 documentation <0.2/limdb.html>`_ is still available.

Why is it called LimDB?
#######################

LimDB was originally named LimrodDB after the ancient king Nimrod's younger sibling,
Limrod, who didn't make it into the history books because he was short.
It was later renamed LimDB for marketing reasons.

By a wild coincidence, it also sounds a little like a vaguely pleasing jumble of Nim and LMDB.


