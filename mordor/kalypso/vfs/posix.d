module mordor.kalypso.vfs.posix;

import tango.core.Variant;
import tango.stdc.errno;
import tango.stdc.posix.dirent;
import tango.stdc.posix.unistd;
import tango.stdc.posix.sys.stat;
import tango.stdc.stringz;
import tango.text.Util;
import tango.time.Time;

import mordor.common.exception;
version (linux) import mordor.common.iomanager;
import mordor.common.streams.file;
import mordor.common.streams.stream;
import mordor.common.stringutils;
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

private Time convert (time_t time, uint nsec)
{
    long t = time;
    t *= TimeSpan.TicksPerSecond;
    t += nsec / TimeSpan.NanosecondsPerTick;
    return Time.epoch1970 + TimeSpan(t);
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
            assert(false);
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
    
    IObject parent()
    {
        return .find(abspath[0..locatePrior(abspath, '/')]);        
    }
    
    abstract int children(int delegate(ref IObject) dg);
    abstract int references(int delegate(ref IObject) dg);

    int properties(int delegate(ref string) dg) {
        static string hidden = "hidden";
        int ret;
        if (_name.length > 0 && _name[0] == '.')
            if ( (ret = dg(hidden)) != 0) return ret;        
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        foreach(p; _nativeProperties) {
            if ( (ret = dg(p)) != 0) return ret;
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
                return Variant(convert(_stat.st_atime, _stat.st_atimensec));
            case "change_time":
                return Variant(convert(_stat.st_ctime, _stat.st_ctimensec));
version (freebsd) {
            case "creation_time":
                return Variant(convert(_stat.st_birthtimespec.tv_sec, _stat.st_birthtimespec.tv_nsec));
}
            case "modification_time":
                return Variant(convert(_stat.st_mtime, _stat.st_mtimensec));
            default:
                return Variant.init;
        }
    }

    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    abstract void _delete();
    abstract Stream open();

protected:
    void ensureStat()
    {
        if (_isDirent) {
            stat_t buf;
            if (lstat(toStringz(_abspath), &buf) != 0)
                throw exceptionFromLastError();
            _stat = buf;
            _isDirent = false;
        }
    }
    
    string abspath() { return _abspath; }

private:
    static string[] _properties = ["name",
                                   "absolute_path",
                                   "type",
                                   "access_time",
                                   "change_time",
                                   "modification_time"];
    version (freebsd) {
        static string[] _nativeProperties = ["creation_time"];
    } else {
        static string[] _nativeProperties;
    }
protected:
    string _abspath;
    string _name;
    bool _isDirent;
    union {
        dirent _dirent;
        stat_t _stat;
    }
}

class PosixDirectory : PosixObject
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
        if (rmdir(toStringz(_abspath)) != 0) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return null; }
    
protected:
    string abspath() { return _abspath[0..$-1]; }
}

class PosixFile : PosixObject
{    
    this(string parent, dirent* ent)
    {
        super(ent);
        _abspath = parent ~ _name;        
    }
    
    this(string path, stat_t* buf)
    {
        super(path, buf);
    }

    int children(int delegate(ref IObject) dg) { return 0; }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string) dg)
    {
        int ret;
        foreach (p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
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
    
private:
    static string[] _properties = ["size"];
}
