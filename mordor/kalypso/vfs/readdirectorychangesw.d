module mordor.kalypso.vfs.readdirectorychangesw;

import tango.stdc.stringz;
import tango.text.convert.Utf;
import tango.util.log.Log;
import win32.winbase;
import win32.winnt;

import mordor.common.exception;
import mordor.common.iomanager;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;

class ReadDirectoryChangesWWatcher : IWatcher
{
    this(IOManager ioManager, void delegate(string, Events) dg)
    {
        _ioManager = ioManager;
        _dg = dg;
    }
    
    ~this()
    {
        foreach(worker; _handleToWorker) {
            CloseHandle(worker.hDir);
        }
    }
    
    Events supportedEvents() {
        return Events.AccessTime | Events.Attributes | Events.Create |
            Events.CreationTime | Events.Delete | Events.Metadata |
            Events.ModificationTime | Events.MovedFrom | Events.MovedTo |
            Events.Security | Events.Size | Events.EventsDropped |
            Events.Files | Events.Directories | Events.OneShot |
            Events.Recursive;
    }
    
    private class Worker
    {
        HANDLE hDir;
        string path;
        Events events;
        void[64 * 1024] buffer = void;
        AsyncEvent event;
        
        void run()
        {
            BOOL watchSubtree = (events & Events.Recursive) ? TRUE : FALSE;
            DWORD filter;
            if ((events & (Events.Files | Events.Directories)) == 0)
                events |= Events.Files | Events.Directories;
            if (events & (Events.Create | Events.MovedFrom | Events.MovedTo | Events.Delete)) {
                if (events & Events.Files)
                    filter |= FILE_NOTIFY_CHANGE_FILE_NAME;
                if (events & Events.Directories)
                    filter |= FILE_NOTIFY_CHANGE_DIR_NAME;
            }
            if (events & Events.Attributes)
                filter |= FILE_NOTIFY_CHANGE_ATTRIBUTES;
            if (events & Events.Size)
                filter |= FILE_NOTIFY_CHANGE_SIZE;
            if (events & Events.ModificationTime)
                filter |= FILE_NOTIFY_CHANGE_LAST_WRITE;
            if (events & Events.AccessTime)
                filter |= FILE_NOTIFY_CHANGE_LAST_ACCESS;
            if (events & Events.CreationTime)
                filter |= FILE_NOTIFY_CHANGE_CREATION;
            if (events & Events.Security)
                filter |= FILE_NOTIFY_CHANGE_SECURITY;
            if (events & Events.Metadata)
                filter |= FILE_NOTIFY_CHANGE_ATTRIBUTES | FILE_NOTIFY_CHANGE_LAST_ACCESS | FILE_NOTIFY_CHANGE_CREATION |
                    FILE_NOTIFY_CHANGE_SECURITY;
            while (true) {
                _ioManager.registerEvent(&event);
                if (!ReadDirectoryChangesW(hDir, buffer.ptr, buffer.length, watchSubtree, filter, NULL, &event.overlapped, NULL)) {
                    if (GetLastError() == ERROR_NOTIFY_ENUM_DIR) {
                        _dg("", Events.EventsDropped);
                        continue;
                    } else if (GetLastError() != ERROR_IO_PENDING) {
                        throw exceptionFromLastError();
                    }
                }
                Fiber.yield();
                if (!event.ret) {
                    if (event.lastError == ERROR_NOTIFY_ENUM_DIR) {
                        _dg("", Events.EventsDropped);
                        continue;
                    } else {
                        throw exceptionFromLastError(event.lastError);
                    }
                }
                assert(event.numberOfBytes >= FILE_NOTIFY_INFORMATION.sizeof);
                FILE_NOTIFY_INFORMATION* pNotification = cast(FILE_NOTIFY_INFORMATION*)buffer.ptr;
                while (true) {
                    Events events;
                    switch (pNotification.Action) {
                        case FILE_ACTION_ADDED:
                            events = Events.Create;
                            break;
                        case FILE_ACTION_REMOVED:
                            events = Events.Delete;
                            break;
                        case FILE_ACTION_MODIFIED:
                            events = Events.Metadata;
                            break;
                        case FILE_ACTION_RENAMED_OLD_NAME:
                            events = Events.MovedFrom;
                            break;
                        case FILE_ACTION_RENAMED_NEW_NAME:
                            events = Events.MovedTo;
                            break;
                    }
                    // TODO: normalize path (it may not be in the correct case)
                    string absPath = path ~ tango.text.convert.Utf.toString(pNotification.FileName[0..pNotification.FileNameLength / wchar.sizeof]);
                    _dg(absPath, events);
                    if (pNotification.NextEntryOffset == 0)
                        break;
                    pNotification = cast(FILE_NOTIFY_INFORMATION*)(cast(void*)pNotification + pNotification.NextEntryOffset);
                }
                if (events & Events.OneShot)
                    break;
            }
        }
    }
    
    bool isReliable(IObject object)
    {
        return object["absolute_path"].get!(wstring)[0..8] != r"\\?\UNC\";
    }

    void watch(IObject object, Events events)
    in
    {
        assert(object["type"].isA!(string));
        assert(object["type"].get!(string) == "directory" ||
               object["type"].get!(string) == "volume");
    }
    body
    {
        wstring path = object["absolute_path"].get!(wstring);
        HANDLE hDir = CreateFileW(toString16z(path),
                                  FILE_LIST_DIRECTORY,
                                  FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                  NULL,
                                  OPEN_EXISTING,
                                  FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
                                  NULL);
        if (hDir == INVALID_HANDLE_VALUE)
            throw exceptionFromLastError();
        _ioManager.registerFile(hDir);
        auto worker = new Worker();
        worker.hDir = hDir;
        worker.path = getFullPath(object) ~ "/";
        worker.events = events;
        _ioManager.schedule(new Fiber(&worker.run));
    }
    
private:    
    IOManager _ioManager;
    Worker[HANDLE] _handleToWorker;
    HANDLE[string] _pathToHandle;
    void delegate(string, Events) _dg;
}
