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
    
    result_t read(Buffer b, size_t len)
    {
        result_t result = super.read(_buf, len);
        if (result > 0) {
            foreach(buf; _buf.readBufs)
            {
                _digest.update(buf);
            }
            b.copyIn(_buf, result);
            _buf.clear();            
        }
        return result;
    }
    
    result_t write(Buffer b, size_t len)
    {
        result_t result = super.write(b, len);
        if (result > 0) {
            foreach(buf; _buf.readBufs)
            {
                _digest.update(buf);
            }
            b.copyIn(_buf, result);
            _buf.clear();            
        }
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
