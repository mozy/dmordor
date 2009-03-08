module mordor.common.streams.filter;

public import mordor.common.streams.stream;

class FilterStream : Stream
{
protected:
    this(Stream parent, bool ownsParent = true)
    {
        _parent = parent;
        _ownsParent = ownsParent;
    }
    
public:
    Stream parent() { return _parent; }
    bool ownsParent() { return _ownsParent; }
    
    bool supportsRead() { return _parent.supportsRead; }
    bool supportsWrite() { return _parent.supportsWrite; }
    bool supportsSeek() { return _parent.supportsSeek; }
    bool supportsSize() { return _parent.supportsSize; }
    bool supportsTruncate() { return _parent.supportsTruncate; }
    
    void close(CloseType type = CloseType.BOTH)
    {
        if (ownsParent)
            _parent.close(type);
    }
    size_t read(Buffer b, size_t len) { return _parent.read(b, len); }
    size_t write(Buffer b, size_t len) { return _parent.write(b, len); }
    long seek(long offset, Anchor anchor) { return _parent.seek(offset, anchor); }
    long size() { return _parent.size(); }
    void truncate(long size) { _parent.truncate(size); }
    void flush() { _parent.flush(); }
    size_t findDelimited(char delim) { return _parent.findDelimited(delim); }
    
protected:
    Stream parent(Stream parent) { return _parent = parent; }
    void ownsParent(bool ownsParent) { _ownsParent = ownsParent; }
    
private:
    Stream _parent;
    bool _ownsParent;
}
