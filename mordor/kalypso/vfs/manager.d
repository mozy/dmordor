module mordor.kalypso.vfs.manager;

version (Posix) import mordor.kalypso.vfs.posix;
version (Windows) import mordor.kalypso.vfs.win32;

import mordor.common.stringutils;
public import mordor.kalypso.vfs.model;

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
    
private:
    static VFSManager _singleton;
    IVFS[] _vfss;
}
