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
    
    size_t read(Buffer b, size_t len)
    {
        return 0;
    }
    
    size_t write(Buffer b, size_t len)
    {
        return len;
    }
    
    size_t write(void[] b)
    {
        return b.length;
    }
    
    long seek(long offset, Anchor anchor)
    {
        return 0;
    }
    
    long size()
    {
        return 0;
    }
    
    void truncate(long size)
    {}
    
    void flush()
    {}
    
private:
    static NilStream _singleton;
}

