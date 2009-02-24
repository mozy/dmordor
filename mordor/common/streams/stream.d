module mordor.common.streams.stream;

public import mordor.common.result;
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

    ~this() { close(); }

    bool supportsRead() { return false; }
    bool supportsWrite() { return false; }
    bool supportsSeek() { return false; }
    bool supportsSize() { return false; }
    bool supportsTruncate() { return false; }
    bool supportsEof() { return supportsSeek() && supportsSize(); }
    
    result_t close(CloseType type = CloseType.BOTH) { return S_OK; }
    result_t read(Buffer b, size_t len) { assert(false); return E_NOTIMPL; }
    result_t write(Buffer b, size_t len) { assert(false); return E_NOTIMPL; }
    result_t seek(long offset, Anchor anchor, out long pos) { assert(false); return E_NOTIMPL; }
    result_t size(out long size) { assert(false); return E_NOTIMPL; }
    result_t truncate(long size) { assert(false); return E_NOTIMPL; }
    result_t flush() { return S_OK; }
    result_t eof()
    {
        assert(supportsSeek() && supportsSize());
        long curPos, curSize;
        result_t result = seek(0, Anchor.CURRENT, curSize);
        if (result < 0)
            return result;
        result = size(curSize);
        if (result < 0)
            return result;

        return curPos >= curSize ? S_OK : S_FALSE;
    }
    
    // convenience function
    result_t write(void[] b)
    {
        scope Buffer buf;
        buf.copyIn(b);
        return write(buf, b.length);
    }
}
