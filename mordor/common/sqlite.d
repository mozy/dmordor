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
//version = OpenV2;

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
    
    ResultSet execute(string sql)
    {
        sqlite3_stmt* stmt;
        int rc = sqlite3_prepare_v2(_db, sql.ptr, sql.length, &stmt, null);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db, rc);
        return new ResultSet(this, stmt);
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
    
    void createFunction(string name, int nArgs, void function(Result, Value[]) fn)
    {
        _scalarFunctions.length = _scalarFunctions.length + 1;
        scope (failure) _scalarFunctions.length = _scalarFunctions.length - 1;
        ScalarFunction* func = &_scalarFunctions[$-1];
        func._fn = fn;
        int rc = sqlite3_create_function(_db, toStringz(name), nArgs, SQLITE_ANY,
            func, &ScalarFunction.xFunc, null, null);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db, rc);        
    }
    
    void createFunction(string name, int nArgs, void delegate(Result, Value[]) dg)
    {
        _scalarFunctions.length = _scalarFunctions.length + 1;
        scope (failure) _scalarFunctions.length = _scalarFunctions.length - 1;
        ScalarFunction* func = &_scalarFunctions[$-1];
        func._dg = dg;
        int rc = sqlite3_create_function(_db, toStringz(name), nArgs, SQLITE_ANY,
            func, &ScalarFunction.xFunc, null, null);
        if (rc != SQLITE_OK)
            throw new SqliteException(_db, rc);        
    }
    
private:
    sqlite3* _db;
    ScalarFunction[] _scalarFunctions;
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
        int rc;
        scope (exit) {
            rc = sqlite3_reset(_stmt);
            if (rc != SQLITE_OK)
                throw new SqliteException(_db._db, rc);
        }
        rc = sqlite3_step(_stmt);
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
    import tango.io.Stdout;
    void opIndexAssign(T)(T v, int i)
    {
        int rc;
        static if (is(T : wstring)) {
            rc = sqlite3_bind_text16(_stmt, i, v.ptr, v.length * wchar.sizeof, SQLITE_TRANSIENT);
        } else static if (is(T : string)) {
            Stdout.formatln("binding string '{}'", v);
            rc = sqlite3_bind_text(_stmt, i, v.ptr, v.length, SQLITE_TRANSIENT);
        } else static if(is(T : void[])) {
            rc = sqlite3_bind_blob(_stmt, i, v.ptr, v.length, SQLITE_TRANSIENT);
        } else static if(is(T : void*)) {
            assert(v is null);
            rc = sqlite3_bind_null(_stmt, i);
        } else static if (is(T : long)) {
            rc = sqlite3_bind_int64(_stmt, i, v);
        } else static if (is(T : int)) {
            rc = sqlite3_bind_int(_stmt, i, v);
        } else static if (is(T : double)) {
            rc = sqlite3_bind_double(_stmt, i, v);
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
        _db = stmt._db;
        _stmt = stmt._stmt;
        _preparedStatement = stmt;
    }
    
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
        if (_stmt !is null) {
            int rc;
            if (_preparedStatement !is null) {
                rc = sqlite3_reset(_stmt);
            } else {
                rc = sqlite3_finalize(_stmt);
            }
            if (rc != SQLITE_OK)
                throw new SqliteException(_db._db, rc);
        }
    }
    
    bool next()
    {
        int rc = sqlite3_step(_stmt);
        switch (rc) {
            case SQLITE_ROW:
                return true;
            case SQLITE_DONE:
                if (_preparedStatement !is null) {
                    rc = sqlite3_reset(_stmt);
                } else {
                    rc = sqlite3_finalize(_stmt);
                }
                if (rc != SQLITE_OK)
                    throw new SqliteException(_db._db, rc);
                _stmt = null;
                _preparedStatement = null;
                return false;
            default:
                throw new SqliteException(_db._db, rc);
        }
    }
    
    T opIndex(T)(int i)
    {       
        static if (is(T : string)) {
            char* ptr = sqlite3_column_text(_stmt, i);
            auto len = sqlite3_column_bytes(_stmt, i);
            return ptr[0..len];
        } else static if (is(T : wstring)) {
            wchar* ptr = sqlite3_column_text16(_stmt, i);
            auto len = sqlite3_column_bytes16(_stmt, i);
            return ptr[0..len / wchar.sizeof];
        } else static if (is(T : void[])) {
            void* ptr = sqlite3_column_blob(_stmt, i);
            auto len = sqlite3_column_bytes(_stmt, i);
            return ptr[0..len];
        } else static if (is(T : long)) {
            return sqlite3_column_int64(_stmt, i);
        } else static if (is(T : int)) {
            return sqlite3_column_int(_stmt, i);
        } else static if (is(T : double)) {
            return sqlite3_column_double(_stmt, i);
        } else {
            static assert(false);
        }
    }    

private:
    Database _db;
    sqlite3_stmt* _stmt;
    PreparedStatement _preparedStatement;
}

struct Result
{
    void opAssign(T)(T v)
    {
        static if (is(T : wstring)) {
            sqlite3_result_text16(_ctx, v.ptr, v.length * wchar.sizeof, SQLITE_TRANSIENT);
        } else static if (is(T : string)) {
            sqlite3_result_text(_ctx, v.ptr, v.length, SQLITE_TRANSIENT);
        } else static if(is(T : void[])) {
            sqlite3_result_blob(_ctx, v.ptr, v.length, SQLITE_TRANSIENT);
        } else static if(is(T : void*)) {
            assert(v is null);
            sqlite3_result_null(_ctx);
        } else static if (is(T : long)) {
            sqlite3_result_int64(_ctx, v);
        } else static if (is(T : int)) {
            sqlite3_result_int(_ctx, v);
        } else static if (is(T : double)) {
            sqlite3_result_double(_ctx, v);
        } else {
            static assert(false);
        }
    }
    
private:
    sqlite3_context* _ctx;
}

struct Value
{
    T get(T)()
    {       
        static if (is(T : string)) {
            char* ptr = sqlite3_value_text(_value);
            auto len = sqlite3_value_bytes(_value);
            return ptr[0..len];
        } else static if (is(T : wstring)) {
            wchar* ptr = sqlite3_value_text16(_value);
            auto len = sqlite3_value_bytes16(_value);
            return ptr[0..len / wchar.sizeof];
        } else static if (is(T : void[])) {
            void* ptr = sqlite3_value_blob(_value);
            auto len = sqlite3_value_bytes(_value);
            return ptr[0..len];
        } else static if (is(T : long)) {
            return sqlite3_value_int64(_value);
        } else static if (is(T : int)) {
            return sqlite3_value_int(_value);
        } else static if (is(T : double)) {
            return sqlite3_value_double(_value);
        } else {
            static assert(false);
        }
    }

private:
    sqlite3_value* _value;
}

private struct ScalarFunction
{
    static extern (C) void xFunc(sqlite3_context* ctx, int nargs, sqlite3_value** args)
    {
        auto obj = cast(ScalarFunction*)sqlite3_user_data(ctx);
        obj.func(ctx, args[0..nargs]);
    }
    
    void func(sqlite3_context* ctx, sqlite3_value*[] args)
    {
        if (_fn !is null)
            _fn (*cast(Result*)&ctx, cast(Value[])args);
        else
            _dg (*cast(Result*)&ctx, cast(Value[])args);        
    }

    void function(Result result, Value args[]) _fn;
    void delegate(Result result, Value args[]) _dg;
}
