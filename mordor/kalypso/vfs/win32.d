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
import mordor.common.streams.handle;
import mordor.common.streams.stream;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;
import mordor.kalypso.vfs.readdirectorychangesw;

private Logger _log, _canonicalizeLog;

private DWORD[string] _attributes;         
private size_t[string] _timestamps;


static this()
{
    _log = Log.lookup("mordor.kalypso.vfs.win32");
    _canonicalizeLog = Log.lookup("mordor.kalypso.vfs.win32.canonicalize");
    
    _attributes["archive"] = FILE_ATTRIBUTE_ARCHIVE;
    _attributes["compressed"] = FILE_ATTRIBUTE_COMPRESSED;
    _attributes["encrypted"] = FILE_ATTRIBUTE_ENCRYPTED;
    _attributes["hidden"] = FILE_ATTRIBUTE_HIDDEN;
    _attributes["not_content_indexed"] = FILE_ATTRIBUTE_NOT_CONTENT_INDEXED;
    _attributes["read_only"] = FILE_ATTRIBUTE_READONLY;
    _attributes["system"] = FILE_ATTRIBUTE_SYSTEM;
    _attributes["temporary"] = FILE_ATTRIBUTE_TEMPORARY;
    _timestamps["access_time"] = WIN32_FILE_ATTRIBUTE_DATA.ftLastAccessTime.offsetof;
    _timestamps["creation_time"] = WIN32_FILE_ATTRIBUTE_DATA.ftCreationTime.offsetof;
    _timestamps["modification_time"] = WIN32_FILE_ATTRIBUTE_DATA.ftLastWriteTime.offsetof;
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

private Time convert (long time)
{
    time *= 100 / TimeSpan.NanosecondsPerTick;
    return Time.epoch1601 + TimeSpan(time);
}

private FILETIME convertToFileTime(Time t)
{
    long time = (t - Time.epoch1601).ticks;
    time /= 100 / TimeSpan.NanosecondsPerTick;
    return *cast(FILETIME*)&time;
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

private DWORD attributesFromProperties(Variant[string] properties, DWORD* containedAttributes = null)
{
    DWORD result;
    foreach (p, v; properties) {
        foreach (a, av; _attributes) {
            if (p == a) {
                if (containedAttributes !is null)
                    *containedAttributes |= av;
                if (v.get!(bool))
                    result |= av;
            }
        }
    }
    return result;
}

private IObject createObject(wstring parent, Variant[string] properties, bool okIfExists, Stream* stream)
in
{
    assert("name" in properties);
    assert("type" in properties);
    assert(properties["name"].isA!(string));
    assert(properties["type"].isA!(string));
}
body
{
    BY_HANDLE_FILE_INFORMATION findData;
    string filename = properties["name"].get!(string);
    wstring path = parent ~ r"\" ~ toString16(filename) ~ "\0";
    IObject object;
    switch(properties["type"].get!(string)) {
        case "directory":
            _log.trace("Creating new directory {}", path[0..$-1]);
            if (!CreateDirectoryW(path.ptr, null)) {
                if (!okIfExists || GetLastError() != ERROR_ALREADY_EXISTS) {
                    throw exceptionFromLastError();
                }
            }
            if (!GetFileAttributesExW(path.ptr, GET_FILEEX_INFO_LEVELS.GetFileExInfoStandard, &findData)) {
                throw exceptionFromLastError();
            }
            object = new Win32Directory(path[0..$-1], cast(WIN32_FILE_ATTRIBUTE_DATA*)&findData, filename);
            object[] = properties;
            break;
        case "file":
            DWORD attributes = attributesFromProperties(properties);
            bool compressed = !!(attributes & FILE_ATTRIBUTE_COMPRESSED);
            attributes &= ~FILE_ATTRIBUTE_COMPRESSED;
            _log.trace("Creating new file {}", path[0..$-1]);
            HANDLE hFile = CreateFileW(path.ptr,
                GENERIC_ALL,
                FILE_SHARE_READ,
                NULL,
                okIfExists ? CREATE_ALWAYS : CREATE_NEW,
                attributes,
                NULL);
                
            if (hFile == INVALID_HANDLE_VALUE) {
                throw exceptionFromLastError();
            }
            if (stream !is null) {
                *stream = new HandleStream(hFile);
            }
            scope (exit) if (stream is null) CloseHandle(hFile);
            // TODO: set compressed
            // TODO: set timestamps
            if (!GetFileInformationByHandle(hFile, &findData))
                throw exceptionFromLastError();
            // We're going to pass a WIN32_FILE_ATTRIBUTE_DATA struct to the next function,
            // but BYHANDLE_FILE_INFORMATION has an extra field in the middle; move things
            // up before we do the cast
            findData.dwVolumeSerialNumber = findData.nFileSizeHigh;
            findData.nFileSizeHigh = findData.nFileSizeLow;
            
            object = new Win32File(path[0..$-1], cast(WIN32_FILE_ATTRIBUTE_DATA*)&findData, filename);
            break;
    }
    return object;
}

private struct PropertyDetails
{
    bool creatable;
    bool settable;
}

class Win32VFS : IVFS, IWatchableVFS
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }

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
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }

    Variant opIndex(string property)
    {
        switch (property) {
            case "name":
                return Variant(cast(string)"win32");
            case "type":
                return Variant("vfs");
            default:
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }
    
    void opIndexAssign(Variant value, string property)
    {}
    
    void opSliceAssign(Variant[string] properties)
    {}
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }
    
    IObject find(string path) {
        return .find(toString16(path));
    }
    
    IWatcher getWatcher(IOManager ioManager, void delegate(string, IWatcher.Events) dg)
    {
        return new ReadDirectoryChangesWWatcher(ioManager, dg);
    }

private:
    static PropertyDetails[string] _properties;
}

class Win32Volume : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["absolute_path"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }

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
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
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
    Variant[string] opSlice()
    {
        return getProperties(this);
    }
    
    void opIndexAssign(Variant value, string property)
    {}
    
    void opSliceAssign(Variant[string] properties)
    {}
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    {
        return createObject(_volume[0..47], properties, okIfExists, stream);
    }

private:
    static PropertyDetails[string] _properties;

private:
    wstring _volume;
}

class Win32Drive : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, true);
        _properties["absolute_path"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
        _properties["target"] = PropertyDetails(false, true);
    }

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

    int properties(int delegate(ref string, ref bool, ref bool) dg)
    {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        return 0;
    }
    
    Variant opIndex(string property)
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
    
    Variant[string] opSlice()
    {
        return getProperties(this);
    }
    
    void opIndexAssign(Variant value, string property)
    {
        switch (property) {
            case "name":
                // TODO: change this drive letter; will need to delete and re-create
                break;
            case "target":
                // TODO: change where a drive letter points to; will need to delete and re-create
                break;
            default:
                break;
        }
    }
    
    void opSliceAssign(Variant[string] properties)
    {
        foreach(p, v; properties)
            this[p] = v;
    }
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }

    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }
    
private:
    static PropertyDetails[string] _properties;
    wstring _drive;
    wstring _target;
}

class Win32UNCShare : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, false);
        _properties["absolute_path"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }

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
    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
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
    Variant[string] opSlice()
    {
        return getProperties(this);
    }
    
    void opIndexAssign(Variant value, string property)
    {}
    void opSliceAssign(Variant[string] properties)
    {}
    
    void _delete()
    { assert(false); }
    
    Stream open()
    { return null; }
    
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    {
        return createObject(_serverAndShare[0..$-1], properties, okIfExists, stream);
    }

private:
    static PropertyDetails[string] _properties;
    wstring _serverAndShare;    
}

class Win32Object : IObject
{
    static this() {
        _properties["name"] = PropertyDetails(false, true);
        _properties["absolute_path"] = PropertyDetails(false, false);
        _properties["type"] = PropertyDetails(false, false);
    }

    this(WIN32_FILE_ATTRIBUTE_DATA* findData, wstring name)
    {
        _findData = *findData;
        _name = tango.text.convert.Utf.toString(name);
    }
    
    this(WIN32_FILE_ATTRIBUTE_DATA* findData, string name)
    {
        _findData = *findData;
        _name = name;
    }

    IObject parent()
    {
        return .find(abspath[0..locatePrior(abspath, cast(wchar)'\\')]);
    }
    abstract int children(int delegate(ref IObject) dg);
    abstract int references(int delegate(ref IObject) dg);

    int properties(int delegate(ref string, ref bool, ref bool) dg) {
        int ret;
        foreach(p, d; _properties) {
            if ( (ret = dg(p, d.creatable, d.settable)) != 0) return ret;
        }
        bool _true = true;
        foreach(a, v; _attributes) {
            if ( (ret = dg(a, _true, _true)) != 0) return ret;
        }
        foreach(t, o; _timestamps) {
            if (timestamp(o) != 0)
                if ( (ret = dg(t, _true, _true)) != 0) return ret;
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
            default:
                foreach (a, v; _attributes)
                {
                    if (property == a)
                        return Variant(!!(_findData.dwFileAttributes & v));
                }
                foreach (t, o; _timestamps)
                {
                    if (property == t)
                        return Variant(convert(timestamp(o)));
                }
                return Variant.init;
        }
    }
    Variant[string] opSlice()
    {
        return getProperties(this);
    }
    
    private void handleProperty(string property,
                                Variant value,
                                ref DWORD newAttributes,
                                ref FILETIME newAtime,
                                ref FILETIME newMtime,
                                ref FILETIME newCtime,
                                ref FILETIME* pNewAtime,
                                ref FILETIME* pNewMtime,
                                ref FILETIME* pNewCtime)
    {
        foreach(a, av; _attributes) {
            if (property == a) {
                if (value.get!(bool)) {
                    newAttributes |= av;
                } else {
                    newAttributes &= ~av;
                }
            }
        }
        switch (property) {
            case "name":
                if (value.get!(string) != _name) {
                    // TODO: rename it (does this need to be done by the subclass?
                    _name = value.get!(string);
                    // TODO: update the absolute path
                }
                break;
            case "compressed":
                if (value.get!(bool) != !!(_findData.dwFileAttributes & FILE_ATTRIBUTE_COMPRESSED)) {
                    // TODO: compress it
                    _findData.dwFileAttributes |= FILE_ATTRIBUTE_COMPRESSED;
                }
                break;
            case "encrypted":
                if (value.get!(bool) != !!(_findData.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED)) {
                    // TODO: encrypt it
                    _findData.dwFileAttributes |= FILE_ATTRIBUTE_ENCRYPTED;
                }
                break;
            case "access_time":
                newAtime = convertToFileTime(value.get!(Time));
                pNewAtime = &newAtime;
                break;
            case "creation_time":
                newCtime = convertToFileTime(value.get!(Time));
                pNewCtime = &newCtime;
                break;
            case "modification_time":
                newMtime = convertToFileTime(value.get!(Time));
                pNewMtime = &newMtime;
                break;
            default:
                break;
        }
    }
    
    private void commitProperties(DWORD newAttributes,
                                  FILETIME newAtime,
                                  FILETIME newMtime,
                                  FILETIME newCtime,
                                  FILETIME* pNewAtime,
                                  FILETIME* pNewMtime,
                                  FILETIME* pNewCtime)
    {
        if (newAttributes != _findData.dwFileAttributes) {
            if (!SetFileAttributesW(toString16z(abspath), newAttributes))
                throw exceptionFromLastError();
            _findData.dwFileAttributes = newAttributes;
        }
        if (pNewAtime !is null || pNewCtime !is null || pNewMtime !is null) {
            HANDLE hFile = CreateFileW(toString16z(abspath),
                FILE_WRITE_ATTRIBUTES,
                FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                NULL,
                OPEN_EXISTING,
                FILE_FLAG_BACKUP_SEMANTICS,
                NULL);
            if (hFile == INVALID_HANDLE_VALUE)
                throw exceptionFromLastError();
            scope (exit) CloseHandle(hFile);
            if (!SetFileTime(hFile, pNewCtime, pNewAtime, pNewMtime))
                throw exceptionFromLastError();
        }
    }

    void opIndexAssign(Variant value, string property)
    {
        DWORD newAttributes = _findData.dwFileAttributes;
        FILETIME newAtime, newMtime, newCtime;
        FILETIME* pNewAtime, pNewMtime, pNewCtime;
        handleProperty(property, value, newAttributes, newAtime, newMtime, newCtime,
            pNewAtime, pNewMtime, pNewCtime);
        commitProperties(newAttributes, newAtime, newMtime, newCtime,
            pNewAtime, pNewMtime, pNewCtime);
    }

    void opSliceAssign(Variant[string] properties)
    {
        DWORD newAttributes = _findData.dwFileAttributes;
        FILETIME newAtime, newMtime, newCtime;
        FILETIME* pNewAtime, pNewMtime, pNewCtime;
        foreach(p, v; properties) {
            handleProperty(p, v, newAttributes, newAtime, newMtime, newCtime,
                pNewAtime, pNewMtime, pNewCtime);
        }
        commitProperties(newAttributes, newAtime, newMtime, newCtime,
            pNewAtime, pNewMtime, pNewCtime);
    }
    
    abstract void _delete();
    abstract Stream open();
    abstract IObject create(Variant[string] properties, bool okIfExists, Stream* stream);
    
protected:
    wstring abspath() { return _abspath; }
    
private:
    long timestamp(size_t offset)
    {
        return (cast(LARGE_INTEGER*)(cast(void*)&_findData + offset)).QuadPart;
    }
    void timestamp(size_t offset, long value)
    {
        (cast(LARGE_INTEGER*)(cast(void*)&_findData + offset)).QuadPart = value;
    }

private:
    static PropertyDetails[string] _properties;

protected:
    string _name;
    WIN32_FILE_ATTRIBUTE_DATA _findData;
    wstring _abspath;
}

class Win32Directory : Win32Object, IOrderedEnumerateObject
{
    this(wstring parent, WIN32_FILE_ATTRIBUTE_DATA* findData, wstring name)
    {
        super(findData, name);
        _abspath = parent ~ r"\" ~ name ~ r"\*";
    }
    
    this(wstring abspath, WIN32_FILE_ATTRIBUTE_DATA* findData, string name)
    {
        super(findData, name);
        _abspath = abspath ~ r"\*";
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
                return Variant(cast(string)"directory");
            default:
                return super[property];
        }
    }
    
    void _delete()
    {
        _log.trace("Deleting directory {}", abspath);
        foreach(child; &children) {
            child._delete();
        }
        if (!RemoveDirectoryW(toString16z(abspath))) {
            throw exceptionFromLastError();
        }
    }
    
    Stream open()
    { return null; }
    
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    {
        return createObject(abspath, properties, okIfExists, stream);
    }

protected:
    wstring abspath() { return _abspath[0..$-2]; }
}

class Win32File : Win32Object
{
    static this() {
        _properties["size"] = PropertyDetails(false, false);
    }

    this(wstring parent, WIN32_FILE_ATTRIBUTE_DATA* findData, wstring name)
    {
        super(findData, name);
        _abspath = parent ~ r"\" ~ name;
    }
    
    this(wstring abspath, WIN32_FILE_ATTRIBUTE_DATA* findData, string name)
    {
        super(findData, name);
        _abspath = abspath;
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
                return Variant((cast(long)_findData.nFileSizeHigh << 32) | cast(long)_findData.nFileSizeLow);
            case "type":
                return Variant(cast(string)"file");
            default:
                return super[property];
        }
    }
    
    void _delete()
    {
        _log.trace("Deleting {}", abspath);
        if (!DeleteFileW(toString16z(_abspath))) {
            throw exceptionFromLastError();
        }
    }

    Stream open()
    {
        return new FileStream(_abspath);
    }
    
    IObject create(Variant[string] properties, bool okIfExists, Stream* stream)
    { assert(false); }

private:
    static PropertyDetails[string] _properties;
}
