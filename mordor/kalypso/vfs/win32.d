module mordor.kalypso.vfs.win32;

import tango.core.Variant;
import tango.stdc.stringz;
import tango.text.convert.Utf;
import tango.text.Util;
import tango.time.Time;
import tango.util.log.Log;
import win32.winbase;
import win32.windef;
import win32.lmapibuf;
import win32.lmcons;
import win32.lmuse;

import mordor.common.exception;
import mordor.common.iomanager;
import mordor.common.streams.file;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;
import mordor.kalypso.vfs.readdirectorychangesw;

private Logger _log, _canonicalizeLog;

static this()
{
    _log = Log.lookup("mordor.kalypso.vfs.win32");
    _canonicalizeLog = Log.lookup("mordor.kalypso.vfs.win32.canonicalize");
}

// Helper functions
private IObject createObject(wstring parent, WIN32_FILE_ATTRIBUTE_DATA* findData, wstring filename)
{
    if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
        if (filename == "." || filename == "..")
            return null;
        return new Win32Directory(parent, findData, filename);
    } else {
        return new Win32File(parent, findData, filename);
    }
    return null;    
}

private Time convert (FILETIME time)
{
    auto t = *cast(long*) &time;
    t *= 100 / TimeSpan.NanosecondsPerTick;
    return Time.epoch1601 + TimeSpan(t);
}

private wstring resolveDrive(wstring drive)
in
{
    assert(drive.length == 2);
    assert(drive[1] == ':');
}
body
{
    wchar[] targetBuf;
    targetBuf.length = MAX_PATH;
    if (!QueryDosDeviceW(toString16z(drive), targetBuf.ptr, targetBuf.length))
        throw exceptionFromLastError();
    wstring target = fromString16z(targetBuf.ptr);
    _canonicalizeLog.trace("Resolved {} to {}", drive, target);
    if (target.length >= 4 && target[0..4] == r"\??\") {
        target[1] = '\\';
        return target;
    } else {
        if (target.length >= 25 && target[0..25] == r"\Device\LanmanRedirector\") {
            wstring serverAndShare = target[25..$];
            if (serverAndShare.length > 4 && serverAndShare[2] == ':') {
                serverAndShare = serverAndShare[locate(serverAndShare, cast(wchar)'\\')..$];
            }
            return r"\\?\UNC" ~ serverAndShare;
        } else {
            wstring volume;
            volume.length = 50;
            if (!GetVolumeNameForVolumeMountPointW(toString16z(drive ~ r"\"), volume.ptr, volume.length))
                throw exceptionFromLastError();
            volume.length = 49;
            return volume;
        }
    }    
}

private wstring canonicalizePath(wstring path)
{
    _canonicalizeLog.trace("Canonicalizing {}", path);
    // Make sure we're using \\?\ notation to support ultra-long paths
    if (path.length <= 2) {
        // super-short path... can only be a drive letter, so prepend \\?\
        path = r"\\?\" ~ path;
    } else if (path.length >= 4 && path[0..4] == r"\??\") {
        // Device notation, switch to \\?\ notation
        path[1] = '\\';
    } else if (path.length >= 4 && path[0..4] == r"\\?\") {
        // Correct notation, leave it alone
    } else if (path.length >= 2 && path[0..2] == r"\\") {
        // "regular" UNC path; prepend \\?\UNC\, dropping \\
        path = r"\\?\UNC\" ~ path[2..$];
    } else {
        // Something else, blindly prepend \\?\
        path = r"\\?\" ~ path;
    }
    // Check for DOS drive
    if (path.length == 6 && path[5] == ':') {
        _canonicalizeLog.trace("Found drive {}", path[4..6]);
        return path[4..6];
    }
        
    while (true) {
        // UNC share
        if (path.length >= 8 && path[0..8] == r"\\?\UNC\") {
            _canonicalizeLog.trace("Found UNC share {}", path);
            return path;
        }
        // Local volume
        if (path.length >= 48 && path[0..11] == r"\\?\Volume{") {
            if (path.length == 48) {
                // Volumes only require a trailing backslash
                path ~= r"\";
            } else if (path.length >= 50) {
                // Directories do *not* have a trailing backslash
                if (path[$-1] == '\\') {
                    path = path[0..$-1];
                }
            }
            _canonicalizeLog.trace("Returning {}", path);
            return path;
        }
        
        // Not rooted in a recognized volume, find the volume path it is mounted on
        wchar[] volumePath;
        volumePath.length = path.length + 1;
        if (!GetVolumePathNameW(toString16z(path), volumePath.ptr, volumePath.length))
            throw exceptionFromLastError();
        volumePath = fromString16z(volumePath.ptr);
        _canonicalizeLog.trace("{} is on volume mounted at {}", path, volumePath);
        
        wchar[] volume;
        if (volumePath.length == 7 && volumePath[5] == ':') {
            volume = resolveDrive(volumePath[4..6]);      
            if (volume[$-1] != '\\')
                volume ~= r"\";
        } else {
            volume.length = 50;
            if (!GetVolumeNameForVolumeMountPointW(volumePath.ptr, volume.ptr, volume.length))
                throw exceptionFromLastError();
            volume.length = 49;
            _canonicalizeLog.trace("{} is volume mounted at {}", volume, volumePath);
        }
        path = volume ~ path[volumePath.length..$];
        _canonicalizeLog.trace("Resolved path {}", path);
    }
}

private IObject find(wstring path)
{
    if (path.length == 0)
        return new Win32VFS();
    
    path = canonicalizePath(path);

    // Drive
    if (path.length == 2 && path[1] == ':')
        return new Win32Drive(path);
    // Volume
    if (path.length == 49 && path[0..11] == r"\\?\Volume{")
        return new Win32Volume(path);
    // TODO: normalize path
    // UNC share path
    if (path.length > 8 && path[0..8] == r"\\?\UNC\") {
        auto slash = locate(path, cast(wchar)'\\', 9);
        slash = locate(path, cast(wchar)'\\', slash + 1);
        if (slash == path.length) {
            return new Win32UNCShare(path);
        } else if (slash == path.length - 1) {
            return new Win32UNCShare(path[0..$-1]);
        }
    }
    // Strip any trailing slash
    if (path[$-1] == '\\')
        path = path[0..$-1];
    WIN32_FILE_ATTRIBUTE_DATA findData;
    if (!GetFileAttributesExW(toString16z(path), GET_FILEEX_INFO_LEVELS.GetFileExInfoStandard, &findData)) {
        throw exceptionFromLastError();
    }
    uint lastSlash = locatePrior(path, cast(wchar)'\\');
    return createObject(path[0..lastSlash], &findData, path[lastSlash+1..$]);
}

class Win32VFS : IVFS, IWatchableVFS
{
    IObject parent() { return null; }

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
            IObject driveObject = new Win32Drive(currentDrive[0..2]);
            if ( (ret = dg(driveObject)) != 0) return ret;
        }
        USE_INFO_0 *sharesBuf;
        DWORD read, total;
        auto lmret = NetUseEnum(null, 0, cast(ubyte**)&sharesBuf, MAX_PREFERRED_LENGTH, &read, &total, null);
        if (lmret != 0)
            throw exceptionFromLastError(lmret);
        scope (exit) NetApiBufferFree(sharesBuf);
        foreach(share; sharesBuf[0..read]) {
            IObject shareObject = new Win32UNCShare(r"\\?\UNC\" ~ fromString16z(share.ui0_remote)[2..$]);
            if ( (ret = dg(shareObject)) != 0) return ret;            
        }
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string) dg) {
        int ret;
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return 0;
    }

    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant("win32");
            case "type":
                return Variant("vfs");
            default:
                return Variant.init;
        }
    }
    
    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    
    IObject find(string path) {
        return .find(toString16(path));
    }
    
    IWatcher getWatcher(IOManager ioManager, void delegate(string, IWatcher.Events) dg)
    {
        return new ReadDirectoryChangesWWatcher(ioManager, dg);
    }

private:
    static string[] _properties = ["name",
                                   "type"];
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
    
    IObject parent() { return new Win32VFS(); }

    int children(int delegate(ref IObject) dg) {
        WIN32_FIND_DATAW findData;
        int ret;
        HANDLE hFind = FindFirstFileW(toString16z(_volume ~ "*"), &findData);
        if (hFind == INVALID_HANDLE_VALUE)
            throw exceptionFromLastError();
        scope (exit) FindClose(hFind);
        do {
            IObject object = createObject(_volume, cast(WIN32_FILE_ATTRIBUTE_DATA*)&findData,
                fromString16z(findData.cFileName.ptr).dup);
            if (object is null)
                continue;
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string) dg) {
        int ret;
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(tango.text.convert.Utf.toString(_volume[4..48]));
            case "absolute_path":
                return Variant(_volume);
            case "type":
                return Variant("volume");
            default:
                return Variant.init;            
        }
    }
    
    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }

private:
    static string[] _properties = ["name",
                                    "absolute_path",
                                    "type"];
    wstring _volume;
}

class Win32Drive : IObject
{
    this(wstring drive)
    in
    {
        assert(drive.length == 2);
        assert(drive[1] == ':');     
    }
    body
    {
        _drive = drive;
    }
    
    IObject parent() { return new Win32VFS(); }
    
    int children(int delegate(ref IObject) dg) { return 0; }
    int references(int delegate(ref IObject) dg)
    {
        if (_target.length == 0) {
            _target = resolveDrive(_drive);
        }
        IObject targetObject = .find(_target);
        return dg(targetObject);
    }

    int properties(int delegate(ref string) dg)
    {
        int ret;
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(string property)
    body
    {
        switch (property) {
            case "name":
            case "absolute_path":
                return Variant(tango.text.convert.Utf.toString(_drive));
            case "type":
                return Variant("link");
            case "target":
                if (_target.length == 0) {
                    _target = resolveDrive(_drive);
                }
                return Variant(getFullPath(.find(_target)));
            default:
                return Variant.init;
        }
    }
    
    void opIndexAssign(Variant value, string property)
    {
        assert(false);
    }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    
private:
    static string[] _properties = ["name",
                                   "absolute_path",
                                   "type",
                                   "target"];
    wstring _drive;
    wstring _target;
}

class Win32UNCShare : IObject
{
    this(wstring serverAndShare)
    in
    {
        assert(serverAndShare.length >= 8);
        assert(serverAndShare[0..8] == r"\\?\UNC\");
        assert(serverAndShare[$-1] != '\\');
    }
    body
    {
        _serverAndShare = serverAndShare ~ r"\*";
    }
    
    IObject parent() { return new Win32VFS(); }

    int children(int delegate(ref IObject) dg) {
        WIN32_FIND_DATAW findData;
        int ret;
        HANDLE hFind = FindFirstFileW(toString16z(_serverAndShare), &findData);
        if (hFind == INVALID_HANDLE_VALUE)
            throw exceptionFromLastError();
        scope (exit) FindClose(hFind);
        do {
            IObject object = createObject(_serverAndShare[0..$-2], cast(WIN32_FILE_ATTRIBUTE_DATA*)&findData,
                fromString16z(findData.cFileName.ptr).dup);
            if (object is null)
                continue;
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
            throw exceptionFromLastError();
        return 0;
    }
    int references(int delegate(ref IObject) dg) { return 0; }
    int properties(int delegate(ref string) dg) {
        int ret;
        foreach(p; _properties) {
            if ( (ret = dg(p)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(tango.text.convert.Utf.toString(_serverAndShare[8..$-2]));
            case "absolute_path":
                return Variant(_serverAndShare[0..$-1]);
            case "type":
                return Variant("volume");
            default:
                return Variant.init;            
        }
    }
    
    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }

private:
    static string[] _properties = ["name",
                                   "absolute_path",
                                   "type"];
    wstring _serverAndShare;    
}

class Win32Object : IObject
{
    this(WIN32_FILE_ATTRIBUTE_DATA* findData, wstring name)
    {
        _findData = *findData;
        _name = tango.text.convert.Utf.toString(name);
    }

    IObject parent()
    {
        return .find(abspath[0..locatePrior(abspath, cast(wchar)'\\')]);
    }
    abstract int children(int delegate(ref IObject) dg);
    abstract int references(int delegate(ref IObject) dg);

    int properties(int delegate(ref string) dg) {
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
    
    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(_name);
            case "absolute_path":
                return Variant(abspath);
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
    
    void opIndexAssign(Variant value, string property)
    { assert(false); }
    
    abstract void _delete();
    abstract Stream open();
    
protected:
    wstring abspath() { return _abspath; }

private:
    static string[] _properties = ["name",
                                   "absolute_path",
                                   "type"];
    static string[] _dynamicProperties = 
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
    string _name;
    WIN32_FILE_ATTRIBUTE_DATA _findData;
    wstring _abspath;
}

class Win32Directory : Win32Object
{
    this(wstring parent, WIN32_FILE_ATTRIBUTE_DATA* findData, wstring name)
    {
        super(findData, name);
        _abspath = parent ~ r"\" ~ name ~ r"\*";
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
            IObject object = createObject(abspath, cast(WIN32_FILE_ATTRIBUTE_DATA*)&findData,
                fromString16z(findData.cFileName.ptr).dup);
            if (object is null)
                continue;
            if ( (ret = dg(object)) != 0) return ret;
        } while (FindNextFileW(hFind, &findData))
        if (GetLastError() != ERROR_NO_MORE_FILES)
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
        if (!RemoveDirectoryW(toString16z(_abspath))) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return null; }

protected:
    wstring abspath() { return _abspath[0..$-2]; }
}

class Win32File : Win32Object
{
    this(wstring parent, WIN32_FILE_ATTRIBUTE_DATA* findData, wstring name)
    {
        super(findData, name);
        _abspath = parent ~ r"\" ~ name;
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
                return Variant((cast(long)_findData.nFileSizeHigh << 32) | cast(long)_findData.nFileSizeLow);
            case "type":
                return Variant("file");
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
    static string[] _properties = ["size"];
}
