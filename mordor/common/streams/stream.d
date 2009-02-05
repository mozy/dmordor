module mordor.common.streams.stream;

public import mordor.common.streams.buffer;

alias int result_t;

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
    
    result_t close(CloseType type = CloseType.BOTH) { return 0; }
    result_t read(Buffer b, size_t len) { assert(false); return -1; }
    result_t write(Buffer b, size_t len) { assert(false); return -1; }
    result_t seek(long offset, Anchor anchor, ref long size) { assert(false); return -1; }
    result_t size(ref long size) { assert(false); return -1; }
    result_t truncate(long size) { assert(false); return -1; }
    result_t flush() { return 0; }
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

        return curPos >= curSize ? 0 : 1;
    }
}
