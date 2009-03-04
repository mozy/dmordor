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

    bool supportsRead() { return false; }
    bool supportsWrite() { return false; }
    bool supportsSeek() { return false; }
    bool supportsSize() { return false; }
    bool supportsTruncate() { return false; }
    
    result_t close(CloseType type = CloseType.BOTH) { return S_OK; }
    result_t read(Buffer b, size_t len)
    out (result)
    {
        assert(FAILED(result) || b.readAvailable >= result);
    }
    body
    { assert(false); return E_NOTIMPL; }
    result_t write(Buffer b, size_t len) { assert(false); return E_NOTIMPL; }
    result_t seek(long offset, Anchor anchor, out long pos) { assert(false); return E_NOTIMPL; }
    result_t size(out long size) { assert(false); return E_NOTIMPL; }
    result_t truncate(long size) { assert(false); return E_NOTIMPL; }
    result_t flush() { return S_OK; }
    result_t findDelimited(char delim) { assert(false); return E_NOTIMPL; }
    
    // convenience functions - do *not* implement in FilterStream, so that
    // filters do not need to implement these
    result_t write(void[] b)
    {
        Buffer buf = new Buffer();
        buf.copyIn(b);
        return write(buf, b.length);
    }
    
    result_t getDelimited(out char[] buf, char delim = '\n')
    {
        result_t result = findDelimited(delim);
        // TODO: check for MORDOR_E_UNEXPECTEDEOF, and read the rest of the stream
        if (FAILED(result))
            return result;
        if (result == 0)
            return S_OK;
        scope Buffer b = new Buffer();
        result_t readResult = read(b, result);
        if (FAILED(readResult))
            return readResult;
        assert(readResult == result);
        // Don't copyOut the delimiter itself
        buf.length = readResult - 1;
        b.copyOut(buf, readResult - 1);
        return S_OK;
    }
}
