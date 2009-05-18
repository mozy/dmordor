module mordor.common.streams.buf;

import tango.math.Math;
import tango.util.log.Log;

public import mordor.common.streams.stream;

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.common.streams.buf");
}

class BufStream : Stream
{
    this()
    {
        _orig = new Buffer();
        _buf = new Buffer();
    }

    size_t read(Buffer buf, size_t len)
    {
        auto todo = min(len, _buf.readAvailable);
        buf.copyIn(_buf, todo);
        _buf.consume(todo);
        _off += todo;
        return todo;
    }

    size_t write(Buffer buf, size_t len)
    {
        return writeInternal(buf, len);
    }

    size_t write(void[] buf)
    {
        return writeInternal(buf, buf.length);
    }

    private size_t writeInternal(T)(T buf, size_t len)
    {
        auto size = _orig.readAvailable();
        if(_off == size) {
            _log.trace("write at EOF {} {}", _off, len);
            static if (is (T : void[])) {
                _orig.copyIn(buf[0..len], true);
            } else {
                _orig.copyIn(buf, len);
            }
            _off += len;
        } else if (_off > size) {
            _log.trace("write beyond EOF {} {}", _off, len);
            // extend the stream, then write
            truncate(_off);
            static if (is(T : void[])) {
                _orig.copyIn(buf[0..len], true);
            } else {
                _orig.copyIn(buf, len);
            }
            _off += len;
        } else {
            _log.trace("write midstream {} {} {}", _off, size, len);
            // write at offset
            scope orig = new Buffer();
            orig.copyIn(_orig, _orig.readAvailable);
            // Re-copy in to orig all data before the write
            _orig.clear();
            _orig.copyIn(orig, _off);
            orig.consume(_off);
            // copy in the write, advancing the stream pointer
            static if (is(T : void[])) {
                _orig.copyIn(buf[0..len], true);
            } else {
                _orig.copyIn(buf, len);
            }
            _off += len;
            if (_off < size) {
                orig.consume(len);        
                // Copy in any remaining data beyond the write
                _orig.copyIn(orig, orig.readAvailable);
            }
            // Reset our read buffer to the current stream pos
            _buf.clear();
            _buf.copyIn(_orig, _orig.readAvailable);
            _buf.consume(_off);
        }
        return len;
    }

    long seek(long offset, Anchor anchor)
    in
    {
        switch(anchor) {
            case Anchor.BEGIN:
                assert(offset >= 0);
                break;
            case Anchor.CURRENT:
                assert(_off + offset >= 0);
                break;
            case Anchor.END:
                assert(_orig.readAvailable + offset >= 0);
                break;
        }
    }
    body
    {
        auto size = _orig.readAvailable;
    
        switch(anchor) {
            case Anchor.BEGIN:
                // Change this into a from current to try and catch an optimized
                // forward seek
                return seek(_off - offset, Anchor.CURRENT);
            case Anchor.CURRENT:
                if(offset < 0) {
                    _off += offset;
                    _buf.clear();
                    _buf.copyIn(_orig, _orig.readAvailable);
                    _buf.consume(min(offset, size));
                    return _off;
                } else {
                    // Optimized forward seek
                    if (_off < size) {
                        _buf.consume(min(offset, size - _off));
                    } else {
                        _buf.clear();
                    }
                    return _off += offset;
                }
            case Anchor.END:
                // Change this into a FromCurrent to try and catch an optimized
                // forward seek
                return seek(size + offset - _off, Anchor.CURRENT);
        }
    }

    long size()
    {
        // The readavail is performed on the original buffer because it
        // represents the real size of the stream, regardless of how much
        // we may have already consumed.
        return _orig.readAvailable;
    }

    void truncate(long len)
    out
    {
        assert(size == len);
    }
    body
    {
        auto size = _orig.readAvailable();
    
        if (size >= len) {
            scope orig = new Buffer();
            orig.copyIn(_orig);
            _orig.clear();
    
            _orig.copyIn(orig, len);
    
            _buf.clear();
            _buf.copyIn(_orig, len);
            _buf.consume(min(_off, len));
        } else {
            char[] buf;
            buf.length = len - size;
    
            _orig.copyIn(buf, false);
            _buf.copyIn(buf, false);
        }
    }

private:
    Buffer _buf, _orig;
    size_t _off;
}
