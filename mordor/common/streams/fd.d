module mordor.common.streams.fd;

import tango.stdc.posix.unistd;
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
    
    result_t close(CloseType type)
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
        return 0;
    }
    
    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    
    result_t read(Buffer b, size_t len)
    {
        iovec[] iov = makeIovec(b.writeBufs(len));
        int rc = readv(_fd, iov.ptr, iov.length);
        if (rc > 0) {
            b.produce(rc);
        }
        return rc;
    }
    
    result_t write(Buffer b, size_t len)
    {
        iovec[] iov = makeIovec(b.readBufs(len));
        return writev(_fd, iov.ptr, iov.length);
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
