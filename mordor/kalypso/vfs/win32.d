module mordor.kalypso.vfs.win32;

import tango.core.Variant;
import tango.stdc.stringz;
import tango.util.log.Log;
import win32.winbase;
import win32.windef;

import mordor.common.exception;
import mordor.common.streams.file;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.kalypso.vfs.model;

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.kalypso.vfs.win32");
}

class Win32VFS : IVFS
{
    int children(int delegate(ref IObject) dg) {
        wchar[50] volume;
        int ret;
        HANDLE hFind = FindFirstVolumeW(volume.ptr, 50);
        if (hFind == INVALID_HANDLE_VALUE)
            throw exceptionFromLastError();
        scope (exit) FindVolumeClose(hFind);
        do {
            IObject volumeObject = new Win32Volume(fromString16z(volume.ptr));
            if ( (ret = dg(volumeObject)) != 0) return ret;            
        } while (FindNextVolumeW(hFind, volume.ptr, 50))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        DWORD dwRet = GetLogicalDriveStringsW(0, null);
        if (dwRet == 0)
            throw exceptionFromLastError();
        wstring logicalDrives;
        logicalDrives.length = dwRet;
        dwRet = GetLogicalDriveStringsW(logicalDrives.length, logicalDrives.ptr);
        if (dwRet == 0 || dwRet > logicalDrives.length)
            throw exceptionFromLastError();
        wchar[] currentDrive;
        size_t offset = 0;
        while (offset < logicalDrives.length - 1) {
            size_t len = strlenz(logicalDrives.ptr + offset);
            currentDrive = logicalDrives[offset..offset+len];
            offset += len + 1;
            IObject logicalDriveObject = new Win32MountPoint(currentDrive);
            if ( (ret = dg(logicalDriveObject)) != 0) return ret;
        }        
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref wstring) dg) {
        static wstring name = "name";
        return dg(name);
    }

    Variant opIndex(wstring property)
    {
        if (property == "name")
            return Variant("win32"w);
        return Variant.init;
    }
    
    void opIndexAssign(Variant value, wstring property)
    { assert(false); }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
}

class Win32Volume : IObject
{
    this(wstring volume)
    in
    {
        assert(volume.length == 49);
        assert(volume[0..4] == r"\\?\");
        assert(volume[48] == '\\');
                
    }
    body
    {
        _log.trace("Creating volume {}", volume);
        _volume = volume.dup;
    }

    int children(int delegate(ref IObject) dg) {
        WIN32_FIND_DATAW findData;
        int ret;
        HANDLE hFind = FindFirstFileW(toString16z(_volume ~ "*"), &findData);
        if (hFind == INVALID_HANDLE_VALUE)
            throw exceptionFromLastError();
        scope (exit) FindClose(hFind);
        do {
            IObject object;
            if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                object = new Win32Directory(_volume, &findData);
            } else {
                object = new Win32File(_volume, &findData);             
            }
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref wstring) dg) {
        static wstring name = "name";
        return dg(name);
    }
    
    Variant opIndex(wstring property)
    {
        if (property == "name")
            return Variant(_volume[4..48]);
        return Variant.init;
    }
    
    void opIndexAssign(Variant value, wstring property)
    { assert(false); }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }

private:
    wstring _volume;
}

class Win32MountPoint : IObject
{
    this(wstring root)
    in
    {
        assert(root.length >= 3);
        assert(root[$ - 1] == '\\');        
    }
    body
    {
        _root = root;
        wchar* rootz = toString16z(_root);
        switch (GetDriveTypeW(rootz)) {
            case DRIVE_FIXED:
                _volume.length = 50;
                if (!GetVolumeNameForVolumeMountPointW(rootz, _volume.ptr, 50))
                    throw exceptionFromLastError();
                _volume.length = 49;
                break;
            default:
                _log.trace("Not determining volume for mount point {}", _root);
                break;
        }
    }
    
    int children(int delegate(ref IObject) dg) { return 0; }
    int references(int delegate(ref IObject) dg) {
        if (_volume.length == 0)
            return 0;
        IObject volumeObject = new Win32Volume(_volume);
        return dg(volumeObject);
    }
    int properties(int delegate(ref wstring) dg) {
        static wstring name = "name";
        return dg(name);
    }
    
    Variant opIndex(wstring property)
    body
    {
        if (property == "name")
            return Variant(_root[0..$ - 1]);
        return Variant.init;
    }
    
    void opIndexAssign(Variant value, wstring property)
    {
        assert(false);
    }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    
private:
    wstring _root;
    wstring _volume;
}

class Win32Object : IObject
{
    this(WIN32_FIND_DATAW* findData)
    {
        _findData = *findData;
        _name = fromString16z(_findData.cFileName.ptr);
    }

    abstract int children(int delegate(ref IObject) dg);
    abstract int references(int delegate(ref IObject) dg);

    int properties(int delegate(ref wstring) dg) {
        int ret;
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(wstring property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "archive":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE));
            case "compressed":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_COMPRESSED));
            case "encrypted":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED));
            case "hidden":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN));
            case "not_content_indexed":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_NOT_CONTENT_INDEXED));
            case "read_only":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_READONLY));
            case "system":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM));
            case "temporary":
                return Variant(!!(_findData.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY));
            default:
                return Variant.init;
        }
    }
    
    void opIndexAssign(Variant value, wstring property)
    { assert(false); }
    
    abstract void _delete();
    abstract Stream open();

private:
    static wstring[] _properties = ["name",
                                    "archive",
                                    "compressed",
                                    "encrypted",
                                    "hidden",
                                    "not_content_indexed",
                                    "read_only",
                                    "system",
                                    "temporary"];
    wstring _name;
    WIN32_FIND_DATAW _findData;
    
protected:
    wstring _abspath;
}

class Win32Directory : Win32Object
{
    this(wstring parent, WIN32_FIND_DATAW* findData)
    {
        super(findData);
        _abspath = parent ~ _name ~ r"\*";
    }
    
    int children(int delegate(ref IObject) dg) {
        WIN32_FIND_DATAW findData;
        int ret;
        _log.trace("Searching {}", _abspath);
        HANDLE hFind = FindFirstFileW(toString16z(_abspath), &findData);
        if (hFind == INVALID_HANDLE_VALUE)
            throw exceptionFromLastError();
        scope (exit) FindClose(hFind);
        do {
            IObject object;
            if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                if (findData.cFileName[0..2] == ".\0" || findData.cFileName[0..3] == "..\0")
                    continue;
                object = new Win32Directory(_abspath[0..$-1], &findData);
            } else {
                object = new Win32File(_abspath[0..$-1], &findData);
            }
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref wstring) dg) {
        int ret;
        static wstring directory = "directory";
        if ( (ret = dg(directory)) != 0) return ret;
        return super.properties(dg);
    }
    
    Variant opIndex(wstring property)
    {
        if (property == "directory")
            return Variant(true);
        return super[property];
    }
    
    void _delete()
    {
        if (!RemoveDirectoryW(toString16z(_abspath))) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return null; }

}

class Win32File : Win32Object
{
    this(wstring parent, WIN32_FIND_DATAW* findData)
    {
        super(findData);
        _abspath = parent ~ _name;
    }
    
    int children(int delegate(ref IObject) dg) {
        // TODO: enum ADS
        return 0;
    }
    int references(int delegate(ref IObject) dg) {
        return children(dg);
    }
    
    void _delete()
    {
        if (!DeleteFileW(toString16z(_abspath))) {
            throw exceptionFromLastError();
        }
    }

    Stream open()
    {
        return new FileStream(_abspath);
    }
}