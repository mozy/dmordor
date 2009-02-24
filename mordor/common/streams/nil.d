module mordor.common.streams.nil;

public import mordor.common.streams.stream;

class NilStream : Stream
{
private:
    this() {}
public:
    static this() {
        _singleton = new NilStream;
    }
    
    static NilStream get() {
        return _singleton;
    }

    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    bool supportsSeek() { return true; }
    bool supportsSize() { return true; }
    bool supportsTruncate() { return true; }
    bool supportsEof() { return true; }
    
    result_t read(Buffer b, size_t len)
    {
        return 0;
    }
    
    result_t write(Buffer b, size_t len)
    {
        return len;
    }
    
    result_t write(void[] b)
    {
        return b.length;
    }
    
    result_t seek(long offset, Anchor anchor, out long pos)
    {
        pos = 0;
        return 0;
    }
    
    result_t size(out long size)
    {
        size = 0;
        return 0;
    }
    
    result_t truncate()
    {
        return 0;
    }
    
    result_t flush()
    {
        return 0;
    }
    
    result_t eof()
    {
        return 0;
    }
    
private:
    static NilStream _singleton;
}

