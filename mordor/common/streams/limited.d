module mordor.common.streams.limited;

import tango.math.Math;

public import mordor.common.streams.filter;

class LimitedStream : FilterStream
{
public:
    this(Stream parent, long size, bool ownsParent = true)
    {
        super(parent, ownsParent);
        _pos = 0;
        _size = size;
    }
    
    bool supportsSize() { return true; }
    bool supportsTruncate() { return false; }
    
    result_t read(Buffer b, size_t len)
    {
        if (_pos >= _size) {
            return 0;
        }
        len = min(len, _size - _pos);
        result_t result = super.read(b, len);
        if (SUCCEEDED(result)) {
            _pos += result;
        }
        return result;
    }
    
    result_t write(Buffer b, size_t len)
    {
        if (_pos >= _size) {
            return E_FAIL;
        }
        len = min(len, _size - _pos);
        result_t result = super.write(b, len);
        if (result > 0) {
            _pos += result;
        }
        return result;
    }
    
    result_t seek(long offset, Anchor anchor, out long pos)
    {
        switch(anchor) {
            case Anchor.BEGIN:
                if (offset < 0) {
                    return E_INVALIDARG;
                }
                break;
            case Anchor.CURRENT:
                if (offset + _pos < 0) {
                    return E_INVALIDARG;
                }
                break;
            case Anchor.END:
                long s;
                result_t result = size(s);
                if (result != 0)
                    return result;
                offset = s + offset;
                anchor = Anchor.BEGIN;
                if (offset < 0) {
                    return E_INVALIDARG;
                }
                break;
            default:
                return -1;
        }
        result_t result = super.seek(offset, anchor, pos);
        if (result == 0)
            _pos = pos;
        return result;
    }
    
    result_t size(out long size)
    {
        if (!super.supportsSize) {
            size = _size;
            return S_OK;
        }
        result_t result = super.size(size);
        if (result == 0) {
            size = min(size, _size);
        }
        return result;
    }
    
    result_t truncate(long size) { assert(false); return E_NOTIMPL; }
    
private:
    long _pos, _size;
}
