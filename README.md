LimDB
=====

Fast, in-process key-value store with a table-like interface persisted to disk using lmdb.

Why?
----

Memory-mapped files are one of the fastest ways to store data but are not safe to
access concurrently. Lmdb is a proven and mature to solution to that problem,
offering full compliance to ACID3, a common standard for database reliability, while
keeping most of the speed.

Leveraging the excellent nim-lmdb interface, LimDB makes a larg-ish sub-set of lmdb features
available in an interface familiar to Nim users who have experience with a table.

While programming with LimDB feels like using a table, it is still very much lmdb.
Some common boilerplate is automated and LimDB is clever about bundling lmdb's moving
parts, but there are no bolted-on bits or obscuring of lmdb's behavior.

Installation
------------

    nimble install https://github.com/capocasa/limdb

Simple Usage
------------

Provide LimDB with a local storage directory and then use it like you would use a table. After
inserting the element, it's on disk an can be accessed even after the program is restarted,
or concurrently by different threads or processes.

    import limdb
    let db = initDatabase("myDirectory")
    db["foo"] = "bar"  # that's it, foo -> bar is now on disk
    echo db["foo"]     # prints bar

Now if you comment out the write, you can run the program again and read the value off disk
    
    import limdb
    let db = initDatabase("myDirectory")
    # db["foo"] = "bar"
    echo db["foo"]  # also prints "bar"

That's it. If you just need to quickly save some data, you can stop reading here and start programming.

[API Documentation](https://capocasa.github.io/limdb/limdb.html)

