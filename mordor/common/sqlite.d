module mordor.common.sqlite;

import tango.core.Exception;
import tango.stdc.stringz;

import sqlite3;

import mordor.common.stringutils;

class SqliteException : PlatformException
{
    this(sqlite3* db, int rc)
    {
        rc = rc & 0xff;
        extendedrc = rc >> 8;
        if (db !is null) {
            super(fromStringz(sqlite3_errmsg(db)));
        } else {
            super("");
        }
    }
    
    int rc;
    int extendedrc;
}

class Database
{
    version (OpenV2) {
        enum OpenFlags
        {
            READONLY         = 0x00000001,
            READWRITE        = 0x00000002,
            CREATE           = 0x00000004,
            NOMUTEX          = 0x00008000,
            FULLMUTEX        = 0x00010000,
        }
    
        this(string path, OpenFlags flags = OpenFlags.READWRITE | OpenFlags.CREATE)
        {
            int rc = sqlite3_open_v2(toStringz(path), &_db, cast(int)flags, null);
            if (rc != SQLITE_OK)
                throw new SqliteException(null, rc);
        }
    } else {
        this(string path)
        {
            int rc = sqlite3_open(toStringz(path), &_db);
            if (rc != SQLITE_OK)
                throw new SqliteException(null, rc);
        }
    }
    
    ~this()
    {
        int rc = sqlite3_close(_db);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db, rc);
    }
    
    PreparedStatement prepare(string sql)
    {
        sqlite3_stmt* stmt;
        int rc = sqlite3_prepare_v2(_db, sql.ptr, sql.length, &stmt, null);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db, rc);
        return new PreparedStatement(this, stmt);
    }
    
    int executeUpdate(string sql)
    {
        sqlite3_stmt* stmt;
        int rc = sqlite3_prepare_v2(_db, sql.ptr, sql.length, &stmt, null);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db, rc);
        scope (exit) {
            rc = sqlite3_finalize(stmt);
            if (rc != SQLITE_OK)
                throw new SqliteException(_db, rc);
        }
        rc = sqlite3_step(stmt);
        switch (rc) {
            case SQLITE_ROW:
                assert(false);
            case SQLITE_DONE:
                break;
            default:
                throw new SqliteException(_db, rc);
        }
        return sqlite3_changes(_db);
    }
    
    void begin()
    {
        executeUpdate("BEGIN");
    }
    void commit()
    {
        executeUpdate("COMMIT");
    }
    void rollback()
    {
        executeUpdate("ROLLBACK");
    }
    
    long lastInsertRowId()
    {
        return sqlite3_last_insert_rowid(_db);
    }
    
private:
    sqlite3* _db;
}

class PreparedStatement
{
private:
    this(Database db, sqlite3_stmt* stmt)
    in
    {
        assert(db !is null);
        assert(stmt !is null);
    }
    body
    {
        _db = db;
        _stmt = stmt;
    }

public:
    ~this()
    {
        int rc = sqlite3_finalize(_stmt);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db._db, rc);
    }

    ResultSet execute()
    {
        return new ResultSet(this);        
    }
    
    int executeUpdate()
    {
        scope (exit) {
            rc = sqlite3_reset(_stmt);
            if (rc != SQLITE_OK)
                throw new SqliteException(_db._db, rc);
        }
        int rc = sqlite3_step(_stmt);
        switch (rc) {
            case SQLITE_ROW:
                assert(false);
            case SQLITE_DONE:
                break;
            default:
                throw new SqliteException(_db._db, rc);
        }
        return sqlite3_changes(_db._db);
    }
    
    void opIndexAssign(T)(T v, int i)
    {
        int rc;
        static if(is(T : void*)) {
            assert(v is null);
            rc = sqlite3_bind_null(_stmt, i);
        } else static if(is(T : void[])) {
            rc = sqlite3_bind_blob(_stmt, i, v.ptr, v.length, SQLITE_TRANSIENT);
        } else static if (is(T : double)) {
            rc = sqlite3_bind_double(_stmt, i, v);
        } else static if (is(T : int)) {
            rc = sqlite3_bind_int(_stmt, i, v);
        } else static if (is(T : long)) {
            rc = sqlite3_bind_int64(_stmt, i, v);
        } else static if (is(T : string)) {
            rc = sqlite3_bind_text(_stmt, i, v.ptr, v.length, SQLITE_TRANSIENT);
        } else static if (is(T : wstring)) {
            rc = sqlite3_bind_text16(_stmt, i, v.ptr, v.length * wchar.sizeof, SQLITE_TRANSIENT);
        } else {
            static assert(false);
        }
        if (rc != SQLITE_OK)
            throw new SqliteException(_db._db, rc);
    }
    
    void opIndexAssign(T)(T v, string param)
    {
        int rc = sqlite3_bind_parameter_index(_stmt, toStringz(param));
        assert(rc != 0);

        return opIndexAssign(T)(v, rc);
    }

private:
    Database _db;
    sqlite3_stmt* _stmt;
}

class ResultSet
{
private:
    this(PreparedStatement stmt)
    in
    {
        assert(stmt !is null);
    }
    body
    {
        _stmt = stmt;
    }

public:
    ~this()
    {
        if (_stmt !is null) {
            int rc = sqlite3_reset(_stmt._stmt);
            if (rc != SQLITE_OK)
                throw new SqliteException(_stmt._db._db, rc);
        }
    }
    
    bool next()
    {
        int rc = sqlite3_step(_stmt._stmt);
        switch (rc) {
            case SQLITE_ROW:
                return true;
            case SQLITE_DONE:
                rc = sqlite3_reset(_stmt._stmt);
                if (rc != SQLITE_OK)
                    throw new SqliteException(_stmt._db._db, rc);
                _stmt = null;
                return false;
            default:
                throw new SqliteException(_stmt._db._db, rc);
        }
    }
    
    T opIndex(T)(int i)
    {
        static if (is(T : void[])) {
            void* ptr = sqlite3_column_blob(_stmt._stmt, i);
            auto len = sqlite3_column_bytes(_stmt._stmt, i);
            return ptr[0..len];
        } else static if (is(T : string)) {
            char* ptr = sqlite3_column_text(_stmt._stmt, i);
            auto len = sqlite3_column_bytes(_stmt._stmt, i);
            return ptr[0..len];
        } else static if (is(T : wstring)) {
            wchar* ptr = sqlite3_column_text16(_stmt._stmt, i);
            auto len = sqlite3_column_bytes16(_stmt._stmt, i);
            return ptr[0..len / wchar.sizeof];
        } else static if (is(T : double)) {
            return sqlite3_column_double(_stmt._stmt, i);
        } else static if (is(T : int)) {
            return sqlite3_column_int(_stmt._stmt, i);
        } else static if (is(T : long)) {
            return sqlite3_column_int64(_stmt._stmt, i);
        } else {
            static assert(false);
        }
    }    

private:
    Database _db;
    PreparedStatement _stmt;
}
