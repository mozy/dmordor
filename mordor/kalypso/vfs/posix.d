module mordor.kalypso.vfs.posix;

import tango.stdc.errno;
import tango.stdc.posix.dirent;
import tango.stdc.posix.unistd;
import tango.stdc.stringz;

import mordor.common.exception;
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
    
    string opIndex(string property)
    {
        if (property == "name")
            return "posix";
        return super[property];
    }
    void opIndexAssign(string value, string property)
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
        static string name = "name";
        return dg(name);
    }
    
    string opIndex(string property)
    in
    {
        assert(property == "name");
    }
    body
    {
        return _name;
    }
    
    void opIndexAssign(string value, string property)
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
