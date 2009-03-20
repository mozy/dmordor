module mordor.kalypso.vfs.manager;

import tango.text.Util;

import mordor.common.exception;
import mordor.common.stringutils;
public import mordor.kalypso.vfs.model;
version (Posix) import mordor.kalypso.vfs.posix;
version (Windows) import mordor.kalypso.vfs.win32;

class VFSManager
{
private:
    this() {
        version (Posix) _vfss ~= new PosixVFS();
        version (Windows) _vfss ~= new Win32VFS();
    }

public:
    static this() {
        _singleton = new VFSManager();
    }
    
    static VFSManager get() { return _singleton; }
    
    int opApply(int delegate(ref IVFS) dg) {
        int ret;
        foreach(vfs; _vfss) {
            if ( (ret = dg(vfs)) != 0) return ret;
        }
        return 0;
    }
    
    IObject find(string path)
    {
        if (path.length == 0)
            return null;
        if (path[0] == '/')
            path = path[1..$];
        if (path.length >=6 && path[0..6] == "native") {
            version (Windows) {
                path = "win32" ~ path[6..$];
            } else version (Posix) {
                path = "posix" ~ path[6..$];
            }
        }

        string firstComponent = path[0..locate(path, '/')];
        string remainder = path[firstComponent.length..$];
        foreach(vfs; _vfss) {
            if (vfs["name"].get!(string) == firstComponent) {
                if (remainder.length == 0)
                    return vfs;
                else
                    return vfs.find(remainder);
            }
        }
        
        throw new FileNotFoundException();
    }
    
private:
    static VFSManager _singleton;
    IVFS[] _vfss;
}
