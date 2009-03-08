module mordor.common.streams.limited;

import tango.math.Math;

import mordor.common.exception;
public import mordor.common.streams.filter;

class LimitedStream : FilterStream
{
public:
    this(Stream parent, long size, bool ownsParent = true)
    in
    {
        assert(size >= 0);
    }
    body
    {
        super(parent, ownsParent);
        _pos = 0;
        _size = size;
    }
    
    bool supportsSize() { return true; }
    bool supportsTruncate() { return false; }
    
    size_t read(Buffer b, size_t len)
    {
        if (_pos >= _size) {
            return 0;
        }
        len = min(len, _size - _pos);
        size_t result = super.read(b, len);
        _pos += result;
        return result;
    }
    
    size_t write(Buffer b, size_t len)
    {
        if (_pos >= _size) {
            throw new BeyondEofException();
        }
        len = min(len, _size - _pos);
        size_t result = super.write(b, len);
        _pos += result;
        return result;
    }
    
    long seek(long offset, Anchor anchor)
    {
        switch(anchor) {
            case Anchor.BEGIN:
                if (offset < 0) {
                    throw new IllegalArgumentException("offset");
                }
                break;
            case Anchor.CURRENT:
                if (offset + _pos < 0) {
                    throw new IllegalArgumentException("offset");
                }
                break;
            case Anchor.END:
                offset += size();
                anchor = Anchor.BEGIN;
                if (offset < 0) {
                    throw new IllegalArgumentException("offset");
                }
                break;
        }
        return _pos = super.seek(offset, anchor);
    }
    
    long size()
    {
        if (!super.supportsSize) {
            return _size;
        }
        return min(_size, super.size());
    }
    
    void truncate(long size) { assert(false); }
    
private:
    long _pos, _size;
}
