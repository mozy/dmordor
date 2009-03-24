module mordor.kalypso.vfs.posix;

import tango.core.Variant;
import tango.stdc.errno;
import tango.stdc.posix.dirent;
import tango.stdc.posix.fcntl;
import tango.stdc.posix.unistd;
import tango.stdc.posix.sys.stat;
import tango.stdc.posix.sys.time;
import tango.stdc.stringz;
import tango.text.Util;
import tango.time.Time;

import mordor.common.exception;
version (linux) import mordor.common.iomanager;
import mordor.common.streams.fd;
import mordor.common.streams.file;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
version (linux) import mordor.kalypso.vfs.inotify;
import mordor.kalypso.vfs.model;

// helper functions
private string nameFromDirent(dirent* ent)
{
    version (linux) {
        return fromStringz(ent.d_name.ptr);
    } else {
        return ent.d_name[0..ent.d_namlen];
    }
}

D to(D, S)(S value)
{
    static if (is(D == Time) && is(S == timespec)) {
        long t = value.tv_sec;
        t *= TimeSpan.TicksPerSecond;
        t += value.tv_nsec / TimeSpan.NanosecondsPerTick;
        return Time.epoch1970 + TimeSpan(t);
    } else static if (is(D == timeval) && is(S == Time)) {
        timeval result;
        long t = (value - Time.epoch1970).ticks;
        result.tv_sec =  t / TimeSpan.TicksPerSecond;
        result.tv_usec = (t / TimeSpan.TicksPerMicrosecond) % 1_000_000;
        return result;
    } else static if (is(D == timeval) && is(S == timespec)) {
        timeval result;
        result.tv_sec = value.tv_sec;
        result.tv_usec = value.tv_nsec / 1000;
        return result;
    } else static if (is(D == timespec) && is(S == timeval)) {
        timespec result;
        result.tv_sec = value.tv_sec;
        result.tv_nsec = value.tv_usec * 1000;
        return result;
    } else {
        static assert(false);
    }
}

version (linux) {
    private alias IWatchableVFS IVFSOnThisPlatform;
} else {
    private alias IVFS IVFSOnThisPlatform;
}

private IObject find(string path)
{
    if (path.length == 0 || path[0] != '/')
        path = '/' ~ path;
    if (path == "/")
        return new PosixVFS();
    // TODO: canonicalize
    stat_t buf;
    if (lstat(toStringz(path), &buf) != 0) {
        throw exceptionFromLastError();
    }
    if (S_ISDIR(buf.st_mode)) {
        return new PosixDirectory(path, &buf);
    } else if (S_ISREG(buf.st_mode)){
        return new PosixFile(path, &buf);
    } else {
        return null;
    }
}

private struct PropertyDetails
{
    bool creatable;
    bool settable;
}

class PosixVFS : PosixDirectory, IVFSOnThisPlatform
{
    this()
    {
        stat_t buf;
        if (lstat("/\0", &buf) != 0) {
            throw exceptionFromLastError();
        }
        super("/", &buf);
    }
    
    IObject parent() { return null; }
    
    int properties(int delegate(ref string, ref bool, ref bool) dg)
    {
        int ret;
        bool _false = false;
        foreach (p, c, s; &super.properties) {
            if (p == "name") {
                if ( (ret = (dg(p, _false, _false))) != 0) return ret;
            } else {
                if ( (ret = (dg(p, c, s))) != 0) return ret;
            }
        }
        return ret;
    }

    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant("posix");
            default:
                return super[property];
        }
    }

    void opIndexAssign(Variant value, string property)
    {
        if (property == "name")
            return;
        super[property] = value;
    }
    
    void _delete()
    { assert(false); }
    
    IObject find(string path)
    {
        return .find(path);
    }
    
    version (linux) {
        IWatcher getWatcher(IOManager ioManager, void delegate(string, IWatcher.Events) dg)
        {
            return new InotifyWatcher(ioManager, dg);
        }
    }
}

class PosixObject : IObject
{
    static this()
    {
        _properties["name"] = PropertyDetails(true, true);
        _properties["absolute_path"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(true, false);
        _properties["access_time"] = PropertyDetails(true, true);
        _properties["change_time"] = PropertyDetails(false, false);
        _properties["modification_time"] = PropertyDetails(true, true);
        _properties["mode"] = PropertyDetails(true, true);
        _properties["uid"] = PropertyDetails(true, true);
        _properties["gid"] = PropertyDetails(true, true);
        version (freebsd) _properties["creation_time"] = PropertyDetails(true, true);
    }

    this(dirent* ent)
    {
        _isDirent = true;
        _dirent = *ent;
        _name = nameFromDirent(&_dirent);        
    }
    
    this(string path, stat_t* buf)
    {
        _isDirent = false;
        _stat = *buf;
        _abspath = path;
        _name = _abspath[locatePrior(_abspath, '/') + 1..$];
    }
    
    this(string path, stat_t* buf, string name)
    {
        _isDirent = false;
        _stat = *buf;
        _abspath = path;
        _name = name;
    }
    
    IObject parent()
    {
        return .find(abspath[0..locatePrior(abspath, '/')]);        
    }
    
    abstract int children(int delegate(ref IObject) dg);
    abstract int references(int delegate(ref IObject) dg);

    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        static string hidden = "hidden";
        int ret;
        bool _false = false;
        if (_name.length > 0 && _name[0] == '.')
            if ( (ret = dg(hidden, _false, _false)) != 0) return ret;        
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "absolute_path":
                return Variant(abspath);
            case "hidden":
                return Variant(_name.length > 0 && _name[0] == '.');
            case "access_time":
                ensureStat();
                return Variant(to!(Time)(*cast(timespec*)&_stat.st_atime));
            case "change_time":
                ensureStat();
                return Variant(to!(Time)(*cast(timespec*)&_stat.st_ctime));
            version (freebsd) {
                case "creation_time":
                    ensureStat();
                    return Variant(to!(Time)(*cast(timespec*)&_stat.st_birthtimespec));
            }
            case "modification_time":
                ensureStat();
                return Variant(to!(Time)(*cast(timespec*)&_stat.st_mtime));
            case "mode":
                ensureStat();
                return Variant(cast(ushort)(_stat.st_mode & 07777));
            case "uid":
                ensureStat();
                return Variant(_stat.st_uid);
            case "gid":
                ensureStat();
                return Variant(_stat.st_gid);
            default:
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }

    void opIndexAssign(Variant value, string property)
    {
        switch (property) {
            case "access_time":
                ensureStat();
                timeval[2] tvs;
                tvs[0] = to!(timeval)(value.get!(Time));
                tvs[1] = to!(timeval)(*cast(timespec*)&_stat.st_mtime);
                if (utimes(toStringz(abspath), tvs) != 0)
                    throw exceptionFromLastError();
                *cast(timespec*)&_stat.st_atime = to!(timespec)(tvs[0]);
                *cast(timespec*)&_stat.st_mtime = to!(timespec)(tvs[1]);
                break;
            case "modification_time":
                ensureStat();
                timeval[2] tvs;
                tvs[0] = to!(timeval)(*cast(timespec*)&_stat.st_atime);
                tvs[1] = to!(timeval)(value.get!(Time));
                if (utimes(toStringz(abspath), tvs) != 0)
                    throw exceptionFromLastError();
                *cast(timespec*)&_stat.st_atime = to!(timespec)(tvs[0]);
                *cast(timespec*)&_stat.st_mtime = to!(timespec)(tvs[1]);
                break;
            case "mode":
                if (chmod(toStringz(abspath), value.get!(ushort)) != 0)
                    throw exceptionFromLastError();
                if (!_isDirent) {
                    _stat.st_mode &= ~07777;
                    _stat.st_mode |= value.get!(ushort);
                }
                break;
            case "uid":
                if (chown(toStringz(abspath), value.get!(uint), -1) != 0)
                    throw exceptionFromLastError();
                if (!_isDirent) {
                    _stat.st_uid = value.get!(uint);
                }
            case "gid":
                if (chown(toStringz(abspath), -1, value.get!(uint)) != 0)
                    throw exceptionFromLastError();
                if (!_isDirent) {
                    _stat.st_gid = value.get!(uint);
                }
            default:
                break;
        }
    }

    void opSliceAssign(Variant[string] properties)
    {
        timeval[2] tvs;
        bool hasTimestamp;
        uint uid = -1, gid = -1;
        foreach(p, v; properties) {
            switch (p) {
                case "access_time":
                    if (!hasTimestamp) {
                        ensureStat();
                        tvs[1] = to!(timeval)(*cast(timespec*)&_stat.st_mtime);
                    }
                    tvs[0] = to!(timeval)(v.get!(Time));
                    hasTimestamp = true;
                    break;
                case "modification_time":
                    if (!hasTimestamp) {
                        ensureStat();
                        tvs[0] = to!(timeval)(*cast(timespec*)&_stat.st_atime);
                    }
                    tvs[1] = to!(timeval)(v.get!(Time));
                    hasTimestamp = true;
                    break;
                case "mode":
                    if (chmod(toStringz(abspath), v.get!(ushort)) != 0)
                        throw exceptionFromLastError();
                    if (!_isDirent) {
                        _stat.st_mode &= ~07777;
                        _stat.st_mode |= v.get!(ushort);
                    }
                case "uid":
                    uid = v.get!(uint);
                    break;
                case "gid":
                    gid = v.get!(uint);
                    break;
                default:
                    break;
            }
        }
        
        if (hasTimestamp) {
            if (utimes(toStringz(abspath), tvs) != 0)
                throw exceptionFromLastError();
            *cast(timespec*)&_stat.st_atime = to!(timespec)(tvs[0]);
            *cast(timespec*)&_stat.st_mtime = to!(timespec)(tvs[1]);
        }
        if (uid != -1 || gid != -1) {
            if (chown(toStringz(abspath), uid, gid) != 0)
                throw exceptionFromLastError();
            if (!_isDirent) {
                _stat.st_uid = uid;
                _stat.st_gid = gid;
            }
        }
    }
    
    abstract void _delete();
    abstract Stream open();
    abstract IObject create(Variant[string] properties, bool okIfExists, Stream* stream);

protected:
    void ensureStat()
    {
        if (_isDirent) {
            // Make sure we're not pointing into storage we're about to corrupt
            if (_name.ptr == _dirent.d_name.ptr) {
                _name = _name.dup;                
            }
            stat_t buf;
            if (lstat(toStringz(abspath), &buf) != 0)
                throw exceptionFromLastError();
            _stat = buf;
            _isDirent = false;
        }
    }
    
    string abspath() { return _abspath; }

private:
    static PropertyDetails[string] _properties;

protected:
    string _abspath;
    string _name;
    bool _isDirent;
    union {
        dirent _dirent;
        stat_t _stat;
    }
}

class PosixDirectory : PosixObject, IOrderedEnumerateObject
{
    this(string parent, dirent* ent)
    {
        super(ent);
        _abspath = parent ~ _name ~ "/";        
    }
    
    this(string path, stat_t* buf)
    {
        super(path, buf);
        if (_abspath[$-1] != '/')
            _abspath ~= '/';
    }
    
    this(string path, stat_t* buf, string name)
    {
        super(path, buf, name);
        _abspath ~= '/';
    }

    int children(int delegate(ref IObject) dg) {
        int ret;
        DIR* dir = opendir(toStringz(_abspath));
        if (dir is null)
            throw exceptionFromLastError();
        scope (exit) closedir(dir);
        dirent *ent;

        while ( (ent = readdir(dir)) !is null) {
            IObject object;
            if (ent.d_type == DT_DIR) {
                string name = nameFromDirent(ent);
                if (name == "." || name == "..")
                    continue;
                object = new PosixDirectory(_abspath, ent);
            } else if (ent.d_type == DT_REG) {
                object = new PosixFile(_abspath, ent);
            } else {
                continue;
            }           
            if ( (ret = dg(object)) != 0) return ret;
        }
        if (errno != 0)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "type":
                return Variant("directory");
            default:
                return super[property];
        }
    }

    void _delete()
    {
        foreach(child; &children) {
            child._delete();
        }
        if (rmdir(toStringz(_abspath)) != 0) {
            throw exceptionFromLastError();
        }
    }

    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    in
    {
        assert("name" in properties);
        assert("type" in properties);
        assert(properties["name"].isA!(string));
        assert(properties["type"].isA!(string));
    }
    body
    {
        stat_t statBuf;
        string filename = properties["name"].get!(string);
        string path = _abspath ~ filename ~ "\0";
        // reset filename to slice into this path, to remove the ref to the
        // string in properties
        filename = path[_abspath.length..$-1];
        mode_t mode = 0777;
        Variant* modeProperty = "mode" in properties;
        if (modeProperty !is null)
            mode = modeProperty.get!(ushort);
        IObject object;
        switch(properties["type"].get!(string)) {
            case "directory":
                if (mkdir(path.ptr, mode) != 0) {
                    if (!okIfExists || errno == EEXIST) {
                        throw exceptionFromLastError();
                    }
                }
                if (lstat(path.ptr, &statBuf) != 0) {
                    throw exceptionFromLastError();
                }
                if (!S_ISDIR(statBuf.st_mode))
                    throw exceptionFromLastError(EEXIST);
                object = new PosixDirectory(path[0..$-1], &statBuf, filename);
                object[] = properties;
                break;
            case "file":
                int flags = O_CREAT | O_TRUNC | O_RDWR;
                if (!okIfExists)
                    flags |= O_EXCL;
                int fd = .open(path.ptr, flags, mode);
                    
                if (fd < 0) {
                    throw exceptionFromLastError();
                }
                if (stream !is null) {
                    *stream = new FDStream(fd);
                }
                scope (exit) if (stream is null) close(fd);
                if (fstat(fd, &statBuf) != 0)
                    throw exceptionFromLastError();
                
                object = new PosixFile(path[0..$-1], &statBuf, filename);
                object[] = properties;
                break;
        }
        return object;
    }
    
protected:
    string abspath() { return _abspath[0..$-1]; }
}

class PosixFile : PosixObject
{
    static this()
    {
        _properties["size"] = PropertyDetails(false, false);
    }

    this(string parent, dirent* ent)
    {
        super(ent);
        _abspath = parent ~ _name;        
    }
    
    this(string path, stat_t* buf)
    {
        super(path, buf);
    }
    
    this(string path, stat_t* buf, string name)
    {
        super(path, buf, name);
    }

    int children(int delegate(ref IObject) dg) { return 0; }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string, ref bool, ref bool) dg)
    {
        int ret;
        foreach (p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return super.properties(dg);
    }

    Variant opIndex(string property)
    {
        switch (property) {
            case "size":
                ensureStat();
                return Variant(_stat.st_size);
            case "type":
                return Variant("file");
            default:
                return super[property];
        }
    }
    
    void _delete()
    {
        if (unlink(toStringz(_abspath)) != 0) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return new FileStream(_abspath); }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }
    
private:
    static PropertyDetails[string] _properties;
}
