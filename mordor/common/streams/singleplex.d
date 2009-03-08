module mordor.common.streams.singleplexer;

public import mordor.common.streams.filter;

class SingleplexStream : FilterStream
{
public:
    enum Type {
        READ,
        WRITE
    }
    
    this(Stream parent, Type type, bool ownsParent = true)
    in
    {
        assert(type == Type.READ || type == Type.WRITE);
        if (type == Type.READ)
            assert(parent.supportsRead);
        if (type == Type.WRITE)
            assert(parent.supportsWrite);        
    }
    body
    {
        super(parent, ownsParent);
        _type = type;
    }
    
    bool supportsRead() { return _type == Type.READ; }
    bool supportsWrite() { return _type == Type.WRITE; }
    bool supportsTruncate() { return _type == Type.WRITE && super.supportsTruncate; }
    
    size_t read(Buffer b, size_t len)
    in
    {
        assert(_type == Type.READ);
    }
    body
    {
        return super.read(b, len);  
    }
    
    size_t write(Buffer b, size_t len)
    in
    {
        assert(_type == Type.WRITE);
    }
    body
    {
        return super.write(b, len);
    }
    
    void truncate(long size)
    in
    {
        assert(_type == Type.WRITE);
    }
    body
    {
        return super.truncate(size);
    }
    
    void flush()
    {
        if (_type == Type.READ) {
            return;
        }
        super.flush();
    }
    
    size_t findDelimited(char delim)
    in
    {
        assert(_type == Type.READ);
    }
    body
    {
        return super.findDelimited(delim);
    }

private:
    Type _type;
}
