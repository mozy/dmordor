module mordor.kalypso.vfs.inotify;

import tango.core.Thread;
import tango.stdc.posix.unistd;
import tango.stdc.stringz;
import tango.sys.linux.inotify;
import tango.util.log.Log;

import mordor.common.exception;
import mordor.common.iomanager;
import mordor.common.streams.buffered;
import mordor.common.streams.fd;
import mordor.common.stringutils;
import mordor.kalypso.vfs.model;
import mordor.kalypso.vfs.helpers;

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.kalypso.vfs.inotify");
}

class InotifyWatcher : IWatcher
{
public:
    this(IOManager ioManager, void delegate(tstring, Events) dg)
    {
        _dg = dg;
        _fd = inotify_init();
        if (_fd < 0)
            throw exceptionFromLastError();
        _inotifyStream = new BufferedStream(new FDStream(ioManager, _fd));
        ioManager.schedule(new Fiber(&this.run));
    }
    
    // no ~this; FDStream owns the fd
    
    Events supportedEvents()
    {
        return Events.AccessTime | Events.ModificationTime |
            Events.Metadata | Events.CloseWrite | Events.CloseNoWrite |
            Events.Close | Events.Open | Events.MovedFrom | Events.MovedTo |
            Events.Create | Events.Delete | Events.EventsDropped |
            Events.FileDirect | Events.IncludeSelf | Events.Files |
            Events.Directories | Events.OneShot;
    }

    void watch(IObject object, Events events)
    {
        string path = object["absolute_path"].get!(string);
        Events requested = events;
        uint inotifyEvents;
        mapEvents(inotifyEvents, events);
        mapFlags(inotifyEvents, events);
        _log.trace("Watching {} with events 0x{:x} (requested 0x{:x}, really 0x{:x})",
            path, inotifyEvents, requested, events);
        int wd = inotify_add_watch(_fd, toStringz(path), inotifyEvents);
        if (wd < 0)
            throw exceptionFromLastError();
        _wdToDetails[wd] = WatchDetails(getFullPath(object), events);
        _pathToWd[path] = wd;
    }
    
    void unwatch(string path)
    in
    {
        assert(path in _pathToWd);
    }
    body
    {
        int rc = inotify_rm_watch(_fd, _pathToWd[path]);
        if (rc != 0)
            throw exceptionFromLastError();
    }
 
private:
    void run()
    {
        inotify_event event;
        char[] fileBuf, filename;
        scope buffer = new Buffer;

        while (true) {
            _inotifyStream.read(buffer, inotify_event.sizeof);
            buffer.copyOut((&event)[0..1], inotify_event.sizeof);
            buffer.consume(inotify_event.sizeof);
            
            if (event.wd == -1) {
                assert(event.mask == IN_Q_OVERFLOW);
                _dg("", Events.EventsDropped);
                continue;
            }
            
            auto details = _wdToDetails[event.wd];
            if (event.mask & IN_IGNORED) {
                _wdToDetails.remove(event.wd);
                _pathToWd.remove(details.path);
            }
            
            filename.length = 0;
            if (event.len > 0) {
                _inotifyStream.read(buffer, event.len);
                if (fileBuf.length < event.len)
                    fileBuf.length = event.len;
                buffer.copyOut(fileBuf, event.len);
                buffer.consume(event.len);
                filename = fileBuf;
                while (filename.length > 0 && filename[$ - 1] == '\0') filename.length = filename.length - 1;
            }

            if (!(details.events & Events.Files) &&
                !(event.mask & IN_ISDIR)) {
                continue;
            }
            if (!(details.events & Events.Directories) &&
                 (event.mask & IN_ISDIR)) {
                continue;
            }

            Events events = mapInotifyEvents(event.mask);

            string absPath = details.path;
            if (filename.length > 0)
                absPath ~= '/' ~ filename;
            _dg(absPath, events);
        }
    }

    void mapEvents(out uint inotifyEvents, ref Events events)
    {
        inotifyEvents = cast(uint)events & 0x03ff;
        events = cast(Events)((cast(uint)events & 0xffff0000) | inotifyEvents);
        if (events & Events.Close)
            inotifyEvents |= IN_CLOSE_WRITE | IN_CLOSE_NOWRITE;
    }
    void mapFlags(ref uint inotifyEvents, ref Events events)
    {
        if ((events & (events.Files | events.Directories)) == 0)
            events |= Events.Files | Events.Directories;
        if (events & Events.FileDirect) {
            events |= Events.IncludeSelf;
            events &= ~(Events.Files | Events.Directories);
            events |= Events.Files;
        } else
            inotifyEvents |= IN_ONLYDIR;
        if ((events & Events.IncludeSelf) && (events & Events.MovedFrom))
            inotifyEvents |= IN_MOVE_SELF;
        if ((events & Events.IncludeSelf) && (events & Events.Delete))
            inotifyEvents |= IN_DELETE_SELF;  
    }
    Events mapInotifyEvents(uint inotifyEvents) {
        Events events = cast(Events)(inotifyEvents & 0x3ff);
        if (inotifyEvents & IN_DELETE_SELF)
            events |= Events.Delete;
        if (inotifyEvents & IN_MOVE_SELF)
            events |= Events.MovedFrom;
        if (inotifyEvents & (IN_CLOSE_NOWRITE | IN_CLOSE_WRITE))
            events |= Events.Close;
        if (inotifyEvents & IN_ISDIR)
            events |= Events.Directories;
        else
            events |= Events.Files;
        return events;
    }

    struct WatchDetails
    {
        string path;
        Events events;
    }

    int _fd = -1;
    WatchDetails[int] _wdToDetails;
    int[string] _pathToWd;
    Stream _inotifyStream;
    void delegate(string, Events) _dg;
}
