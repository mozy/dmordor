module mordor.common.streams.fd;

import tango.stdc.posix.unistd;
import tango.stdc.posix.sys.stat;
import tango.stdc.posix.sys.uio;

import mordor.common.exception;
public import mordor.common.streams.stream;

class FDStream : Stream
{
public:
    this(int fd, bool ownFd = true)
    {
        _fd = fd;
        _own = ownFd;
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
    int _fd;
    bool _own;
}
