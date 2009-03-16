module mordor.kalypso.vfs.posix;

import tango.core.Variant;
import tango.stdc.errno;
import tango.stdc.posix.dirent;
import tango.stdc.posix.unistd;
import tango.stdc.stringz;

import mordor.common.exception;
import mordor.common.streams.file;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.kalypso.vfs.model;

// helper function
string nameFromDirent(dirent* ent)
{
    version (linux) {
        return fromStringz(ent.d_name.ptr);
    } else {
        return ent.d_name[0..ent.d_namlen];
    }
}

class PosixVFS : PosixDirectory, IVFS
{
    this()
    {
        super("/");
    }
    
    Variant opIndex(string property)
    {
        if (property == "name")
            return Variant("posix");
        return super[property];
    }
    void opIndexAssign(Variant value, string property)
    {
        if (property == "name")
            assert(false);
        super[property] = value;
    }
    
    void _delete()
    { assert(false); }
}

class PosixDirectory : IObject
{
    this(string path)
    {
        _abspath = path;
        // TODO: need to stat
    }
    
    this(string parent, dirent* ent)
    {
        _dirent = *ent;
        _name = nameFromDirent(&_dirent);
        _abspath = parent ~ _name ~ "/";        
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
            } else {
                // TODO: files, symlinks
                continue;
            }
            if ( (ret = dg(object)) != 0) return ret;
        }
        if (errno != 0)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string) dg) {
        static string directory = "directory";
        static string name = "name";
        static string hidden = "hidden";
        int ret;
        if ( (ret = dg(directory)) != 0) return ret;
        if ( (ret = dg(name)) != 0) return ret;
        if (_name.length > 0 && _name[0] == '.')
            if ( (ret = dg(hidden)) != 0) return ret;
        return 0;
    }
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "directory":
                return Variant(true);
            case "hidden":
                return Variant(_name.length > 0 && _name[0] == '.');
            default:
                return Variant.init;
        }
    }
    
    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    void _delete()
    {
        if (rmdir(toStringz(_abspath)) != 0) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return null; }

private:
    string _abspath;
    string _name;
    dirent _dirent;
}

class PosixFile : IObject
{    
    this(string parent, dirent* ent)
    {
        _dirent = *ent;
        _name = nameFromDirent(&_dirent);
        _abspath = parent ~ _name;        
    }

    int children(int delegate(ref IObject) dg) { return 0; }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string) dg) {
        static string name = "name";
        static string hidden = "hidden";
        int ret;
        if ( (ret = dg(name)) != 0) return ret;
        if (_name.length > 0 && _name[0] == '.')
            if ( (ret = dg(hidden)) != 0) return ret;
        return 0;            
    }
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "hidden":
                return Variant(_name.length > 0 && _name[0] == '.');
            default:
                return Variant.init;
        }
    }
    
    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    void _delete()
    {
        if (unlink(toStringz(_abspath)) != 0) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return new FileStream(_abspath); }

private:
    string _abspath;
    string _name;
    dirent _dirent;
}
