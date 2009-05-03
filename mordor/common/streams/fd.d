module mordor.common.streams.fd;

import tango.stdc.errno;
import tango.stdc.posix.fcntl;
import tango.stdc.posix.unistd;
import tango.stdc.posix.sys.stat;
import tango.stdc.posix.sys.uio;
version(linux) import tango.sys.linux.epoll;

import mordor.common.exception;
import mordor.common.iomanager;
public import mordor.common.streams.stream;

class FDStream : Stream
{
public:
    this(int fd, bool ownFd = true)
    in
    {
        assert(fd >= 0);
    }
    body
    {
        _fd = fd;
        _own = ownFd;
    }

    this(IOManager ioManager, int fd, bool ownFd = true)
    in
    {
        assert(fd >= 0);
        assert(ioManager !is null);
    }
    body
    {
        _ioManager = ioManager;
        _fd = fd;
        _own = ownFd;
        if (fcntl(_fd, F_SETFL, O_NONBLOCK) < 0)
            throw exceptionFromLastError();
        version (linux) {
            _readEvent.event.events = EPOLLIN;
            _writeEvent.event.events = EPOLLOUT;
        } else version (darwin) {
            _readEvent.event.filter = EVFILT_READ;
            _writeEvent.event.filter = EVFILT_WRITE;
        }
        version (linux) {
            _readEvent.event.data.fd = _fd;
            _writeEvent.event.data.fd = _fd;
        } else version (darwin) {
            _readEvent.event.ident = _fd;
            _writeEvent.event.ident = _fd;
        }
    }
    ~this() { close(); } 
    
    void close(CloseType type = CloseType.BOTH)
    in
    {
        assert(type == CloseType.BOTH);
    }
    body
    {
        if (_fd != 0 && _own) {
            if (.close(_fd) == -1) {
                throw exceptionFromLastError();
            }
            _fd = 0;            
        }
    }
    
    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    bool supportsSeek() { return true; }
    bool supportsSize() { return true; }
    bool supportsTruncate() { return true; }
    
    size_t read(Buffer b, size_t len)
    {
        iovec[] iov = makeIovec(b.writeBufs(len));
        int rc = readv(_fd, iov.ptr, iov.length);
        while (rc < 0 && errno == EAGAIN && _ioManager !is null) {
            _ioManager.registerEvent(&_readEvent);
            Scheduler.getThis().yieldTo();
            rc = readv(_fd, iov.ptr, iov.length);
        }
        if (rc < 0) {
            throw exceptionFromLastError();
        }
        b.produce(rc);
        return rc;
    }
    
    size_t write(Buffer b, size_t len)
    {
        iovec[] iov = makeIovec(b.readBufs(len));
        int rc = writev(_fd, iov.ptr, iov.length);
        while (rc < 0 && errno == EAGAIN && _ioManager !is null) {
            _ioManager.registerEvent(&_writeEvent);
            Scheduler.getThis().yieldTo();
            rc = writev(_fd, iov.ptr, iov.length);
        }
        if (rc == 0) {
            throw new ZeroLengthWriteException();
        }
        if (rc < 0) {
            throw exceptionFromLastError();
        }
        return rc;
    }
    
    long seek(long offset, Anchor anchor)
    {
        long pos = lseek(_fd, offset, cast(int)anchor);
        if (pos < 0)
            throw exceptionFromLastError();
        return pos;
    }
    
    long size()
    {
        stat_t statbuf;
        int rc = fstat(_fd, &statbuf);
        if (rc != 0)
            throw exceptionFromLastError();
        return statbuf.st_size;
    }
    
    protected static iovec[] makeIovec(void[][] bufs)
    {
        iovec[] array = new iovec[bufs.length];
        foreach (i, buf; bufs) {
            array[i].iov_base = cast(char*)buf.ptr;
            array[i].iov_len = buf.length;
        }
        return array;
    }
    
private:
    IOManager _ioManager;
    AsyncEvent _readEvent;
    AsyncEvent _writeEvent;
    int _fd;
    bool _own;
}
