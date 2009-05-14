module mordor.common.streams.stream;

public import mordor.common.streams.buffer;

class Stream
{
public:
    enum CloseType {
        READ,
        WRITE,
        BOTH
    }

    enum Anchor {
        BEGIN,
        CURRENT,
        END
    }

    bool supportsRead() { return false; }
    bool supportsWrite() { return false; }
    bool supportsSeek() { return false; }
    bool supportsSize() { return false; }
    bool supportsTruncate() { return false; }
    
    void close(CloseType type = CloseType.BOTH) { }
    size_t read(Buffer b, size_t len)
    out (result)
    {
        assert(b.readAvailable >= result);
    }
    body
    { assert(false); return 0; }
    size_t write(Buffer b, size_t len)
    out (result)
    {
        assert(result > 0);
    }
    body
    { assert(false); return 0; }
    long seek(long offset, Anchor anchor) { assert(false); }
    long size() { assert(false); }
    void truncate(long size) { assert(false); }
    void flush() { }
    size_t findDelimited(char delim) { assert(false); }
    
    // convenience functions - do *not* implement in FilterStream, so that
    // filters do not need to implement these
    size_t write(void[] b)
    {
        Buffer buf = new Buffer();
        buf.copyIn(b);
        return write(buf, b.length);
    }
    
    void getDelimited(out char[] buf, char delim = '\n')
    {
        size_t offset = findDelimited(delim);
        if (offset == 0)
            return;
        scope Buffer b = new Buffer();
        size_t readResult = read(b, offset);
        assert(readResult == offset);
        // Don't copyOut the delimiter itself
        buf.length = readResult - 1;
        // Reset the buf to zero length if the copyOut fails
        scope (failure) buf.length = 0;
        b.copyOut(buf, readResult - 1);
    }
}
