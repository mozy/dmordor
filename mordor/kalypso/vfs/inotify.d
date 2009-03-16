module mordor.kalypso.vfs.inotify;

import tango.core.Thread;
import tango.stdc.posix.unistd;
import tango.stdc.stringz;
import tango.sys.linux.inotify;

import mordor.common.exception;
import mordor.common.streams.buffered;
import mordor.common.streams.fd;
import mordor.common.stringutils;

class InotifyWatcher
{
private:
    this()
    {
        _fd = inotify_init();
        if (_fd < 0)
            throw exceptionFromLastError();
        _inotifyStream = new BufferedStream(new FDStream(_fd));
    }
public:
    this(void delegate(string, uint) dg)
    {
        this();
        _dg = dg;
    }
    
    this(void function(string, uint) fn)
    {
        this();
        _fn = fn;
    }
    // no ~this; FDStream owns the fd
    
    void watch(string path, uint events)
    {
        int wd = inotify_add_watch(_fd, toStringz(path), events);
        if (wd < 0)
            throw exceptionFromLastError();
        _wdToPath[wd] = path;
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
                if (_dg !is null)
                    _dg("", event.mask);
                if (_fn !is null)
                    _fn("", event.mask);
                continue;
            }
            
            string absPath = _wdToPath[event.wd];
            if (event.mask & IN_IGNORED) {
                _wdToPath.remove(event.wd);
                _pathToWd.remove(absPath);
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

            if (filename.length > 0)
                absPath ~= '/' ~ filename;
            if (_dg !is null)
                _dg(absPath, event.mask);
            if (_fn !is null)
                _fn(absPath, event.mask);
        }
    }
    
    
private:
    int _fd = -1;
    string[int] _wdToPath;
    int[string] _pathToWd;
    Stream _inotifyStream;
    void delegate(string, uint) _dg;
    void function(string, uint) _fn;
}
