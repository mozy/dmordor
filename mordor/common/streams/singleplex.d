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
    
    result_t read(Buffer b, size_t len)
    {
        if (_type == Type.WRITE) {
            assert(_type == Type.READ);
            return E_NOTIMPL;
        }
        return super.read(b, len);  
    }
    
    result_t write(Buffer b, size_t len)
    {
        if (_type == Type.READ) {
            assert(_type == Type.WRITE);
            return E_NOTIMPL;
        }
        return super.write(b, len);
    }
    
    result_t truncate(long size)
    {
        if (_type == Type.READ) {
            assert(_type == Type.WRITE);
            return E_NOTIMPL;
        }
        return super.truncate(size);
    }
    
    result_t flush()
    {
        if (_type == Type.READ) {
            return S_OK;
        }
        return super.flush();
    }
    
    result_t findDelimited(char delim)
    {
        if (_type == Type.WRITE) {
            assert(_type == Type.READ);
            return E_NOTIMPL;
        }
        return super.findDelimited(delim);
    }

private:
    Type _type;
}
