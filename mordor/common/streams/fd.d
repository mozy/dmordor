module mordor.common.streams.fd;

import tango.stdc.posix.unistd;
import tango.stdc.posix.sys.stat;
import tango.stdc.posix.sys.uio;

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
    
    result_t close(CloseType type = CloseType.BOTH)
    in
    {
        assert(type == CloseType.BOTH);
    }
    body
    {
        if (_fd != 0 && _own) {
            .close(_fd);
            _fd = 0;
        }
        return S_OK;
    }
    
    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    bool supportsSeek() { return true; }
    bool supportsSize() { return true; }
    bool supportsTruncate() { return true; }
    
    result_t read(Buffer b, size_t len)
    {
        iovec[] iov = makeIovec(b.writeBufs(len));
        int rc = readv(_fd, iov.ptr, iov.length);
        if (rc > 0) {
            b.produce(rc);
        }
        return RESULT_FROM_LASTERROR(rc);
    }
    
    result_t write(Buffer b, size_t len)
    {
        iovec[] iov = makeIovec(b.readBufs(len));
        return RESULT_FROM_LASTERROR(writev(_fd, iov.ptr, iov.length));
    }
    
    result_t seek(long offset, Anchor anchor, out long pos)
    {
        pos = lseek(_fd, offset, cast(int)anchor);
        if (pos == -1)
            return RESULT_FROM_LASTERROR();
        return S_OK;
    }
    
    result_t size(out long size)
    {
        stat_t statbuf;
        int rc = fstat(_fd, &statbuf);
        size = statbuf.st_size;
        return RESULT_FROM_LASTERROR(rc);
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
