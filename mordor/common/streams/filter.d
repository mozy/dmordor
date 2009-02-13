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
    bool supportsEof() { return _parent.supportsEof; }
    
    result_t close(CloseType type = CloseType.BOTH)
    {
        if (ownsParent)
            return _parent.close(type);
        else
            return 0;
    }
    result_t read(Buffer b, size_t len) { return _parent.read(b, len); }
    result_t write(Buffer b, size_t len) { return _parent.write(b, len); }
    result_t seek(long offset, Anchor anchor, out long pos) { return _parent.seek(offset, anchor, pos); }
    result_t size(out long size) { return _parent.size(size); }
    result_t truncate(long size) { return _parent.truncate(size); }
    result_t flush() { return _parent.flush(); }
    result_t eof() { return _parent.eof(); }
    
protected:
    Stream parent(Stream parent) { return _parent = parent; }
    void ownsParent(bool ownsParent) { _ownsParent = ownsParent; }
    
private:
    Stream _parent;
    bool _ownsParent;
}
