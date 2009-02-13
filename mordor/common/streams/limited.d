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
        if (result > 0) {
            _pos += result;
        }
        return result;
    }
    
    result_t write(Buffer b, size_t len)
    {
        if (_pos >= _size) {
            return -1;
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
                    return -1;
                }
                break;
            case Anchor.CURRENT:
                if (offset + _pos < 0) {
                    return -1;
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
                    return -1;
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
            return 0;
        }
        result_t result = super.size(size);
        if (result == 0) {
            size = min(size, _size);
        }
        return result;
    }
    
    result_t truncate(long size) { assert(false); return -1; }
    
private:
    long _pos, _size;
}
