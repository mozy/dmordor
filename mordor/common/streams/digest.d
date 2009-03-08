module mordor.common.streams.digest;

import tango.io.digest.Digest;

public import mordor.common.streams.filter;

class DigestStream : FilterStream
{
public:
    this(Stream parent, Digest digest, bool ownParent = true)
    {
        super(parent, ownParent);
        _buf = new Buffer;
        _digest = digest;
    }
    
    size_t read(Buffer b, size_t len)
    {
        size_t result = super.read(_buf, len);
        foreach(buf; _buf.readBufs)
        {
            _digest.update(buf);
        }
        b.copyIn(_buf, result);
        _buf.clear();            
        return result;
    }
    
    size_t write(Buffer b, size_t len)
    {
        size_t result = super.write(b, len);
        foreach(buf; _buf.readBufs)
        {
            _digest.update(buf);
        }
        b.copyIn(_buf, result);
        _buf.clear();            
        return result;
    }
    
    ubyte[] binaryDigest (ubyte[] buffer = null)
    {
        return _digest.binaryDigest(buffer);
    }
    
    uint digestSize()
    {
        return _digest.digestSize;
    }
    
    char[] hexDigest (char[] buffer = null)
    {
        return _digest.hexDigest(buffer);
    }
    
private:
    Buffer _buf;
    Digest _digest;
}
