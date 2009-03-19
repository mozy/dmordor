module mordor.kalypso.vfs.win32;

import tango.core.Variant;
import tango.stdc.stringz;
import tango.text.Util;
import tango.time.Time;
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

private IObject createObject(wstring parent, WIN32_FIND_DATAW* findData)
{
    if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        if (findData.cFileName[0..2] == ".\0" || findData.cFileName[0..3] == "..\0")
            return null;
        return new Win32Directory(parent, findData);
    } else {
        return new Win32File(parent, findData);
    }
    return null;    
}

private Time convert (FILETIME time)
{
    auto t = *cast(long*) &time;
    t *= 100 / TimeSpan.NanosecondsPerTick;
    return Time.epoch1601 + TimeSpan(t);
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
    
    IObject find(wstring path) {
        if (path.length == 0)
            return new Win32VFS();
        if (path.length < 4 || path[0..4] != r"\\?\")
            path = r"\\?\" ~ path;
        // TODO: figure out the volume it's mounted on, so we open just like
        // we enumerate them
        // TODO: canonicalize
        WIN32_FIND_DATAW findData;
        if (!GetFileAttributesExW(toString16z(path), GET_FILEEX_INFO_LEVELS.GetFileExInfoStandard, &findData)) {
            throw exceptionFromLastError();
        }
        uint lastSlash = locatePrior(path, cast(wchar)'\\');
        findData.cFileName[0..path.length-lastSlash] = path[lastSlash+1..$];
        return createObject(path[0..lastSlash], &findData);
    }
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
            IObject object = createObject(_volume, &findData);
            if (object is null)
                continue;
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
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
                return Variant(_volume[4..48]);
            case "absolute_path":
                return Variant(_volume);
            case "type":
                return Variant("volume"w);
            default:
                return Variant.init;            
        }
    }
    
    void opIndexAssign(Variant value, wstring property)
    { assert(false); }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }

private:
    static wstring[] _properties = ["name",
                                    "absolute_path",
                                    "type"];
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
    int references(int delegate(ref IObject) dg)
    {
        if (_volume.length == 0)
            return 0;
        IObject volumeObject = new Win32Volume(_volume);
        return dg(volumeObject);
    }
    int properties(int delegate(ref wstring) dg)
    {
        int ret;
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(wstring property)
    body
    {
        switch (property) {
            case "name":
                return Variant(_root[0..$ - 1]);
            case "type":
                return Variant("mount"w);
            default:
                return Variant.init;
        }
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
    static wstring[] _properties = ["name",
                                    "type"];
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
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE)
            if ( (ret = dg(_dynamicProperties[0])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_COMPRESSED)
            if ( (ret = dg(_dynamicProperties[1])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED)
            if ( (ret = dg(_dynamicProperties[2])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN)
            if ( (ret = dg(_dynamicProperties[3])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_NOT_CONTENT_INDEXED)
            if ( (ret = dg(_dynamicProperties[4])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_READONLY)
            if ( (ret = dg(_dynamicProperties[5])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM)
            if ( (ret = dg(_dynamicProperties[6])) != 0) return ret;
        if (_findData.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY)
            if ( (ret = dg(_dynamicProperties[7])) != 0) return ret;
        if ((cast(LARGE_INTEGER)_findData.ftLastAccessTime).QuadPart != 0)
            if ( (ret = dg(_dynamicProperties[8])) != 0) return ret;
        if ((cast(LARGE_INTEGER)_findData.ftCreationTime).QuadPart != 0)
            if ( (ret = dg(_dynamicProperties[9])) != 0) return ret;
        if ((cast(LARGE_INTEGER)_findData.ftLastWriteTime).QuadPart != 0)
            if ( (ret = dg(_dynamicProperties[10])) != 0) return ret;
        return 0;
    }
    
    Variant opIndex(wstring property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "absolute_path":
                return Variant(_abspath);
            case "archive":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE ? Variant(true) : Variant.init;
            case "compressed":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_COMPRESSED ? Variant(true) : Variant.init;
            case "encrypted":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED ? Variant(true) : Variant.init;
            case "hidden":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN ? Variant(true) : Variant.init;
            case "not_content_indexed":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_NOT_CONTENT_INDEXED ? Variant(true) : Variant.init;
            case "read_only":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_READONLY ? Variant(true) : Variant.init;
            case "system":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_SYSTEM ? Variant(true) : Variant.init;
            case "temporary":
                return _findData.dwFileAttributes & FILE_ATTRIBUTE_TEMPORARY ? Variant(true) : Variant.init;
            case "access_time":
                return (cast(LARGE_INTEGER)_findData.ftLastAccessTime).QuadPart != 0 ? Variant(convert(_findData.ftLastAccessTime)) : Variant.init;
            case "creation_time":
                return (cast(LARGE_INTEGER)_findData.ftCreationTime).QuadPart != 0 ? Variant(convert(_findData.ftCreationTime)) : Variant.init;
            case "modification_time":
                return (cast(LARGE_INTEGER)_findData.ftLastWriteTime).QuadPart != 0 ? Variant(convert(_findData.ftLastWriteTime)) : Variant.init;
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
                                    "absolute_path",
                                    "type"];
    static wstring[] _dynamicProperties = 
                                   ["archive",
                                    "compressed",
                                    "encrypted",
                                    "hidden",
                                    "not_content_indexed",
                                    "read_only",
                                    "system",
                                    "temporary",
                                    "access_time",
                                    "creation_time",
                                    "modification_time"];
protected:
    wstring _name;
    WIN32_FIND_DATAW _findData;
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
            IObject object = createObject(_abspath[0..$-1], &findData);
            if (object is null)
                continue;
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    
    Variant opIndex(wstring property)
    {
        switch (property) {
            case "type":
                return Variant("directory"w);
            case "absolute_path":
                return Variant(_abspath[0..$-1]);
            default:
                return super[property];
        }
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
    
    int children(int delegate(ref IObject) dg)
    {
        // TODO: enum ADS
        return 0;
    }
    int references(int delegate(ref IObject) dg)
    {
        return children(dg);
    }
    int properties(int delegate(ref wstring) dg)
    {
        int ret;
        foreach (p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return super.properties(dg);
    }
    
    Variant opIndex(wstring property)
    {
        switch (property) {
            case "size":
                return Variant((cast(long)_findData.nFileSizeHigh << 32) | cast(long)_findData.nFileSizeLow);
            case "type":
                return Variant("file"w);
            default:
                return super[property];
        }
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

private:
    static wstring[] _properties = ["size"];
}
