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

If you have more than one read or write to do, it is usually a good idea to group them all into a
so-called "transaction", because:

- Your data will not change between different reads, even if there are unrelated writes going on
- All writes will be done if successful, none if there is an error

This ensures consistency.

Transactions in LimDB are done using a simple block structure.

.. code-block:: nim
    import limdb
    let db = initDatabase[string, string]("myDirectory")
    db.withTransaction as t:
      t["foo"] = "bar"
      echo t["foo"]

If there is an exception raised in your code, the writes in the block don't happen at all.

.. code-block:: nim
    import limdb
    let db = initDatabase[string, string]("myDirectory")
    with db:
      t["foo"] = "bar"
   
      # triggers a KeyError, program exits and
      # t["foo"] = "bar" does not end up in the database
      echo t["fuz"] 

You can use that on purpose if you're not sure if everything you are going to write will be valid,
for example when interacting with a user through a form.

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


Data Types
##########

By default, keys and values are strings, but you can use any Nim system data type except `ref`.

Add a tuple for seperate types for the keys and values


.. code-block:: nim
    import limdb
    let db = initDatabase("myDirectory", (int, float))

    db[3] = 3.3

Or just a type if both are the same.

   .. code-block:: nim
    import limdb
    let db = initDatabase("myDirectory", int)

    db[3] = 3

Objects and named or unnamed tuples work fine as long as they don't contain a ref.

.. code-block:: nim
    type
      Foo = object
        a: int
        b: float

    let db = db.initDatabase("myDirectory", (Foo, (int, string, float)))
    with db:
      t[ Foo(a: 1, b: 2.2) ] = (5, "foo", 1.1)
      t[ Foo(a: 3, b: 4.4) ] = (10, "bar", 2.2)

It's also possible to serialize objects to string and store them like that, if you prefer.

See *Custom Data Types* below if you want to natively add your own.

.. caution::
    It is recommended to hard-code the data types and the database if possible, making sure
    each database is only used with the data types that were already written to it. Confusing
    them can lead to garbage output or data loss.

Named Databases
###############

If you need more than one database, you can put many in the same directory and refer to the by names.

The default database, the one used in the examples above, also has a name, an empty string `""`, but
it should only be used if it's the only one.

Use a named tuple to provide names and types for the databases you want. You will get back a named
tuple with the same keys containing your database objects.

.. code-block:: nim

    import limdb

    let db = initDatabase("myDirectory", (foo: int, bar: float, string))

    db.foo[1] = 15
    db.bar[5.5] = "fuz"

.. note::
   If you already stored data in the default database, and now want to use named databases,
   migrate your data to a named database before adding more because the default database
   is used internally in this case.

Multi-Database Transactions
###########################

If you need to make consistent reads and/or writes to several databases, you can give
`withTransaction` a tuple containing database objects. It can be one you got from
`initDatabase`, or you can make your own.

A tuple containing a transaction object for each database will be placed into the transaction
variable that you can use in the block to make changes, just like with the single database
transaction above.

.. code-block:: nim

    import limdb

    let db = initDatabase("myDirectory", (foo: int, bar: int, string, fuz: float))

    db.withTransaction t:
      t.foo[1] = 12
      t.bar[2] = "buz"
      t.fuz[3.3] = 4.4

    (db.foo, db.fuz).withTransaction t:
      t[0][2] = 3
      t[1][4.4] = 5.5

    (a: db.bar, b: db.buz).withTransaction t:
      t.a[3] = "fizz"
      t.b[6.6] = 8.8

Ultra-Shorthand
###############

If you want to use a quick shorthand at the expense of some code readability, call `tx`
instead of `withTransaction t`. Your transaction or transactions will be placed into a `tx` variable.

.. code-block:: nim

    import limdb

    let db = initDatabase("myDirectory")

    db.tx:
      tx["foo"] = "bar"
      tx["fuz"] = "buz"
      echo tx["foo"]
    
    db.tx:
      echo tx["bar"]

.. note::
    The LimDB author recommends using this for quick throwaway code and exploratory
    programming, renaming to the more verbose `withTransaction` as programs
    get longer and mature.

Explicit Read/Write
###################

By default, LimDB looks into your `withTransaction` or `tx` block and checks if
there are any write calls in there, chosing `readwrite` or `readonly` modes accordingly.

If you want to make it clear a code block will not make any database changes, you can use
an explicit `readonly` transaction.

.. code-block:: nim

    import limdb

    let db = initDatabase("myDirectory")
    db["foo"] = "bar"

    db.withTransaction readonly as t:
      echo t["foo"]
      t["fuz"] = "buz"  # raises IOError
    
    db.tx ro:
      echo tx["foo"]
      tx["fuz"] = "buz"  # raises IOError

If you really want a readwrite transaction that doesn't write for some reason, you can have it.

.. code-block:: nim
    import limdb

    let db = initDatabase("myDirectory")
    db["foo"] = "bar"
    
    # a bit slower but works fine

    db.withTransaction readwrite as t:
      echo t["foo"]  
    
    db.tx rw:
      echo tx["foo"]

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

Derived database
#########################

For many use cases, using only one centralized call to initDatabase in the whole
program gives a nice, readable and safe way setting up your read and write needs and may
be all you need.

Sometimes you might still prefer or need to open databases as you go along.

You can get more database objects (or tuples of several) from existing ones by calling
initDatabase again, passing an existing database instead of a directory on disk.

.. code-block:: nim
    let db = initDatabase("myDirectory", "someDbName")
    let db2 = db.initDatabase("anotherDbName")

    # You can derive several at once.

    let moreDbs = db.initDatabase (yadn: int, yyadn, float)
    moreDbs.yadn[1] = 10
      t2["fuz"] = "buz"
    
    # You can still run multi-database-transactions over combinations of these

    (db, moreDbs.yadn1).withTransaction t:
      t[0]["foo"] = "bar"
      t[0][5] = 10

.. caution::
    It's harder to make sure you open each named database with the right types
    when deriving databases, especially programmatically or at run-time. This
    can cause garbage output or data corruption- use with care.

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

If you want more control, you can begin, commit and reset transactions manually.

If you call `initTransaction` and then `reset` it later, that's equivalent to calling
a `withTransaction` block in `readonly` mode.

If you call `initTransaction` and then `commit` it later, that's equivalent to calling
a `withTransaction` block in `readwrite` mode.

Transactions are in `readwrite` mode by default, but can be set `readonly` for much
better performance.

.. code-block:: nim

    import limdb
    let db = initDatabase("myDirectory")
    let t = db.initTransaction
    t["foo"] = "bar"
    t["fuz"] = "buz"se
    t.commit()
    
    # readwrite can be set explicitly
    let t = db.initTransaction readwrite
    t["foo"] = "another bar"
    t["fuz"] = "another buz"
    t.reset()  # foo and bar remain unchanged

    # readonly transaction
    let t = db.initTransaction readonly
    echo t["foo"]
    echo t["bar"]
    t.reset()  # Reset Read-only transactions when done 

.. caution::
    You need to reset or commit readwrite transactions immediately
    after writing or all further ones will block forever.

    Readonly transactions are more forgiving but still eventually
    need to be reset to avoid resource leak.

    It's usually safer and more convenient to use the `withTransaction`
    syntax instead.

Improvement Areas Of Interest
#############################

* Allow auto-unpacking of multi-database transaction variables, e.g. (db1, db2).withTransaction t1, t2 readonly
* Use Nim views to provide an alternative interface allowing safe zero-copy data access in with Nim data types (lmdb itself does not copy data when accessing) - this might be already the case
* Useful iterators: `keysFrom`, `keysBetween`, other common usage of lmdb cursors
* Map lmdb multipe values per key feature to something Nimish, perhaps iterators or seqs

Migrating from 0.2
##################

0.2 code works unchanged.

Why is it called LimDB?
#######################

LimDB was originally named LimrodDB after the ancient king Nimrod's younger sibling,
Limrod, who didn't make it into the history books because he was short.
It was later renamed LimDB for marketing reasons.

By a wild coincidence, it also sounds a little like a vaguely pleasing jumble of Nim and LMDB.


