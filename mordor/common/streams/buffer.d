module mordor.common.streams.buffer;

import tango.math.Math;
import tango.stdc.string;

import mordor.common.containers.linkedlist;

class Buffer
{
    struct Data
    {
        static Data opCall(size_t len)
        {
            Data d = {0, new void[len]};
            return d;
        }

        static Data opCall(void[] buf)
        {
            Data d = {buf.length, buf};
            return d;
        }
        
        size_t readAvailable()
        {
            return _writeIndex;
        }
        
        size_t writeAvailable()
        {
            return _buf.length - _writeIndex;
        }
        
        size_t length()
        {
            return _buf.length;
        }
        
        void produce(size_t len)
        in
        {
            assert(len <= writeAvailable);
        }
        body
        {
            _writeIndex += len;
        }
        
        void consume(size_t len)
        in
        {
            assert(len <= readAvailable);
        }
        body
        {
            _writeIndex -= len;
            _buf = _buf[len..$];
        }
        
        void[] readBuf()
        {
            return _buf[0.._writeIndex];
        }
        
        void[] writeBuf()
        {
            return _buf[_writeIndex..$];
        }
        
    private:
        size_t _writeIndex;
        void[] _buf;
 
        invariant()
        {
            assert(_writeIndex <= _buf.length);
        }
    }
    
public:
    this()
    {
        _bufs = new LinkedList!(Data)();
        _writeIt = _bufs.end;
    }
    
    size_t readAvailable()
    {
        return _readAvailable;
    }
    
    size_t writeAvailable()
    {
        return _writeAvailable;
    }
    
    void reserve(size_t len)
    {
        if (writeAvailable < len) {
            // over-reserve to avoid fragmentation
            Data newBuf = { 0, new void[len * 2 - writeAvailable] };
            if (readAvailable == 0) {
                // put the new buffer at the front if possible to avoid
                // fragmentation
                _bufs.prepend(newBuf);
                _writeIt = _bufs.begin;
            } else {
                _bufs.append(newBuf);
                _writeIt = _bufs.end;
                --_writeIt;
            }
            _writeAvailable += newBuf._buf.length;
        }
    }
    
    void compact()
    out
    {
        assert(writeAvailable == 0);
    }
    body
    {
        if (_writeIt != _bufs.end) {
            if (_writeIt.ptr.readAvailable > 0) {
                Data newBuf = Data(_writeIt.ptr.readBuf);
                _bufs.insert(_writeIt, newBuf);
            }
            _bufs.erase(_writeIt, _bufs.end);
            _writeAvailable = 0;
        }
    }
    
    void clear()
    out
    {
        assert(readAvailable == 0);
        assert(writeAvailable == 0);
    }
    body
    {
        _readAvailable = _writeAvailable = 0;
        _bufs.clear();
        _writeIt = _bufs.end;
    }
    
    void produce(size_t len)
    in
    {
        assert(len <= writeAvailable);
    }
    out
    {
        assert(readAvailable >= len);
    }
    body
    {
        _readAvailable += len;
        _writeAvailable -= len;
        while (len > 0)
        {
            Data *buf = _writeIt.ptr;
            size_t toProduce = min(buf.writeAvailable, len);
            buf.produce(toProduce);
            len -= toProduce;
            if (buf.writeAvailable == 0)
                ++_writeIt;
        }
        assert(len == 0);
    }
    
    void consume(size_t len)
    in
    {
        assert(len <= readAvailable);
    }
    body
    {
        _readAvailable -= len;
        while(len > 0)
        {
            Data* buf = _bufs.begin.ptr;
            size_t toConsume = min(buf.readAvailable, len);
            buf.consume(toConsume);
            len -= toConsume;
            if (buf.length == 0) {
                _bufs.erase(_bufs.begin);
            }
        }
        assert(len == 0);
    }
    
    void[][] readBufs(size_t len = ~0)
    in
    {
        assert(len <= readAvailable || len == ~0);
    }
    out (result)
    {
        size_t total = 0;
        foreach(buf; result) {
            total += buf.length;
        }
        assert(total == len);
    }
    body
    {
        void[][] result;
        result.length = _bufs.size;
        if (len == ~0)
            len = readAvailable;
        size_t remaining = len;
        foreach(i, buf; _bufs)
        {
            size_t toConsume = min(buf.readAvailable, remaining);
            result[i] = buf.readBuf[0..toConsume];
            remaining -= toConsume;
            if (remaining == 0) {
                result.length = i + 1;
                break;
            }
        }
        assert(remaining == 0);
        return result;
    }
    
    void[] readBuf(size_t len)
    in
    {
        assert(len <= readAvailable);
    }
    out (result)
    {
        assert(result.length == len);
        assert(len == 0 || result.ptr == _bufs.begin.ptr.readBuf.ptr);
        assert(len == 0 || result.length <= _bufs.begin.ptr.readBuf.length);
    }
    body
    {
        if (readAvailable == 0) {
            void[] result;
            return result;
        }
        // Optimize case where all that is requested is contained in the
        // first buffer
        if (_bufs.begin.ptr.readAvailable >= len) {
            return _bufs.begin.ptr.readBuf[0..len];
        }
        // try to avoid allocation
        if (_writeIt.ptr.writeAvailable >= readAvailable) {
            copyOut(_writeIt.ptr.writeBuf, readAvailable);
            Data newBuf = Data(_writeIt.ptr.writeBuf[0..readAvailable]);
            _bufs.clear();
            _bufs.append(newBuf);
            _writeAvailable = 0;
            _writeIt = _bufs.end;
            return newBuf.readBuf[0..len];
        }
        Data newBuf = Data(readAvailable);
        copyOut(newBuf.writeBuf, readAvailable);
        newBuf.produce(readAvailable);
        _bufs.clear();
        _bufs.append(newBuf);
        _writeAvailable = 0;
        _writeIt = _bufs.end;
        return newBuf.readBuf[0..len];
    }

    void[][] writeBufs(size_t len = ~0)
    out (result)
    {
        assert(writeAvailable >= len);
        size_t total = 0;
        foreach(buf; result) {
            total += buf.length;
        }
        assert(total == len);
    }
    body
    {
        if (len == ~0)
            len = writeAvailable;
        reserve(len);
        void[][] result;
        result.length = _bufs.size;
        size_t i = 0;
        size_t remaining = len;
        auto it = _writeIt;
        while (remaining > 0)
        {
            Data* buf = it.ptr;
            size_t toProduce = min(buf.writeAvailable, remaining);
            result[i] = buf.writeBuf[0..toProduce];
            remaining -= toProduce;
            ++i; ++it;
        }
        result.length = i;
        assert(remaining == 0);
        return result;
    }
    
    void[] writeBuf(size_t len)
    out (result)
    {
        assert(writeAvailable >= len);
        assert(result.length == len);
    }
    body
    {
        // Must allocate just the write buf
        if (writeAvailable == 0) {
            reserve(len);
            assert(_writeIt.ptr.writeAvailable >= len);
            return _writeIt.ptr.writeBuf[0..len];            
        }
        // Can use an existing write buf
        if (writeAvailable > 0 && _writeIt.ptr.writeAvailable >= len) {
            return _writeIt.ptr.writeBuf[0..len];
        }
        // Existing bufs are insufficient... remove thme and reserve anew
        compact();
        reserve(len);
        assert(_writeIt.ptr.writeAvailable >= len);
        return _writeIt.ptr.writeBuf[0..len];
    }
    
    void copyIn(Buffer buf)
    {
        copyIn(buf, buf.readAvailable);
    }
    
    void copyIn(Buffer buf, size_t len)
    in
    {
        assert(buf.readAvailable >= len);
    }
    out
    {
        assert(readAvailable >= len);
    }
    body
    {
        // Split any mixed read/write bufs
        if (_writeIt != _bufs.end && _writeIt.ptr.readAvailable != 0) {
            _bufs.insert(_writeIt, Data(_writeIt.ptr.readBuf));
            _writeIt.ptr.consume(_writeIt.ptr.readAvailable);
        }

        foreach(b; buf._bufs)
        {
            size_t toConsume = min(b.readAvailable, len);
            Data newBuf = Data(b.readBuf[0..toConsume]);
            _bufs.insert(_writeIt, newBuf);
            _readAvailable += toConsume;
            len -= toConsume;
            if (len == 0)
                break;
        }
        
        assert(len == 0);
    }
    
    void copyIn(void[] buf, bool dup = true)
    out
    {
        assert(readAvailable >= buf.length);
    }
    body
    {
        // Split any mixed read/write bufs
        if (_writeIt != _bufs.end && _writeIt.ptr.readAvailable != 0) {
            _bufs.insert(_writeIt, Data(_writeIt.ptr.readBuf));
            _writeIt.ptr.consume(_writeIt.ptr.readAvailable);
        }
        
        Data newBuf;
        if (dup) {
            newBuf = Data(buf.dup);
        } else {
            newBuf = Data(buf);
        }
        _bufs.insert(_writeIt, newBuf);
        _readAvailable += buf.length;
    }
    
    void copyOut(void[] buf, size_t len)
    in
    {
        assert(len <= readAvailable);
        assert(buf.length >= len);
    }
    out
    {
        assert(buf.length == len);
    }
    body
    {
        size_t remaining = len;
        size_t sofar = 0;
        foreach(b; _bufs) {
            size_t todo = min(remaining, b.readAvailable);
            buf[sofar..sofar + todo] = b.readBuf[0..todo];
            remaining -= todo;
            sofar += todo;
            if (remaining == 0)
                break;
        }
    }
    
    ptrdiff_t findDelimited(char delim, size_t len = 0)
    in
    {
        assert(len <= readAvailable);
    }
    body
    {
        if (len == 0)
            len = readAvailable;
        
        size_t totalLength;
        bool success = false;

        foreach(b; _bufs)
        {
            void* start = b.readBuf.ptr;
            size_t toscan = min(len, b.readAvailable);
            void* point = memchr(start, delim, toscan);
            if (point !is null) {
                success = true;
                totalLength += point - start;
                break;
            }
            totalLength += toscan;
            len -= toscan;
            if (len == 0)
                break;   
        }
        if (success) {
            return totalLength + 1;
        }
        return -1;
    }

private:
    LinkedList!(Data) _bufs;
    size_t _readAvailable;
    size_t _writeAvailable;
    _bufs.Iterator _writeIt;
    
    invariant()
    {
        size_t read = 0;
        size_t write = 0;
        bool seenWrite = false;
        for(auto it = _bufs.begin; it != _bufs.end; ++it) {
            Data *buf = it.ptr;
            // Strict ordering
            assert(!seenWrite || seenWrite && buf.readAvailable == 0);
            read += buf.readAvailable;
            write += buf.writeAvailable;
            if (!seenWrite && buf.writeAvailable != 0) {
                seenWrite = true;
                assert(_writeIt == it);
            }
        }
        assert(read == _readAvailable);
        assert(write == _writeAvailable); 
        assert(write != 0 || write == 0 && _writeIt == _bufs.end);
    }
}
