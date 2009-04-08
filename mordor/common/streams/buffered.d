module mordor.common.streams.buffered;

import tango.math.Math;
import tango.util.log.Log;

import mordor.common.config;
import mordor.common.exception;
public import mordor.common.streams.filter;

private ConfigVar!(size_t) _defaultBufferSize;
private ConfigVar!(size_t) _getDelimitedSanitySize;

private Logger _log;

static this()
{
    _defaultBufferSize =
        Config.lookup!(size_t)("stream.buffered.defaultbuffersize",
        cast(size_t)(64 * 1024), "Default buffer size for BufferedStream");
    _getDelimitedSanitySize = 
        Config.lookup!(size_t)("stream.buffered.getdelimitedsanitysize",
        cast(size_t)(16 * 1024 * 1024),
        "Maximum amount to buffer before failing a getDelimited call");
    
    _log = Log.lookup("mordor.common.streams.buffered");
}

class BufferedStream : FilterStream
{
public:
    this(Stream parent, bool ownsParent = true)
    {
        super(parent, ownsParent);
        _bufferSize = _defaultBufferSize.val;
        _allowPartialReads = false;
        _readBuffer = new Buffer;
        _writeBuffer = new Buffer;
    }

    size_t bufferSize() { return _bufferSize; }
    size_t bufferSize(size_t bufferSize) { return _bufferSize = bufferSize; }

    bool allowPartialReads() { return _allowPartialReads; }
    bool allowPartialReads(bool allowPartialReads) { return _allowPartialReads = allowPartialReads; }

    size_t read(Buffer b, size_t len)
    {
        size_t remaining = len;

        size_t buffered = min(_readBuffer.readAvailable, remaining);
        b.copyIn(_readBuffer, buffered);
        _readBuffer.consume(buffered);
        remaining -= buffered;
        
        if (remaining == 0) {
            _log.trace("Read {} from buffer", len);
            return len;
        }
        _log.trace("Read {}/{} from buffer", len - remaining, len);

        if (buffered == 0 || !_allowPartialReads) {
            do {
                // Read enough to satisfy this request, plus up to a multiple of the buffer size 
                size_t todo = ((remaining - 1) / _bufferSize + 1) * _bufferSize;
                size_t result;
                try {
                    result = super.read(_readBuffer, todo);
                    _log.trace("Read {}/{} from parent", result, todo);
                } catch(PlatformException ex){
                    if (remaining == len) {
                        throw ex;
                    } else {
                        return len - remaining;
                    }
                }
    
                buffered = min(_readBuffer.readAvailable, remaining);
                b.copyIn(_readBuffer, buffered);
                _readBuffer.consume(buffered);
                remaining -= buffered;
            } while (remaining > 0 && !_allowPartialReads)
        }

        return len - remaining;
    }

    size_t write(Buffer b, size_t len)
    out (result)
    {
        // Partial writes not allowed
        assert(result == len);
    }
    body
    {
        _writeBuffer.copyIn(b, len);
        return flushWrite(len);
    }

    size_t write(void[] b)
    out (result)
    {
        // Partial writes not allowed
        assert(result == b.length);
    }
    body
    {
        _writeBuffer.reserve(_bufferSize);
        _writeBuffer.copyIn(b);
        return flushWrite(b.length);        
    }
    
    private size_t flushWrite(size_t len)
    {
        while(_writeBuffer.readAvailable > _bufferSize)
        {
            size_t result;
            try {
                result = super.write(_writeBuffer, _writeBuffer.readAvailable);
            } catch (PlatformException ex) {
                // If this entire write is still in our buffer,
                // back it out, and report an error
                if (_writeBuffer.readAvailable >= len) {
                    scope Buffer tempBuffer;
                    tempBuffer.copyIn(_writeBuffer, _writeBuffer.readAvailable - len);
                    _writeBuffer.clear();
                    _writeBuffer.copyIn(tempBuffer);
                    throw ex;
                } else {
                    // Otherwise we have to say we succeeded,
                    // because we're not allowed to have a partial
                    // write, and we can't report an error because
                    // the caller will think he needs to repeat
                    // the entire write
                    return len;
                }
            }
            
            _writeBuffer.consume(result);
        }
        return len;
    }

    long seek(long offset, Anchor anchor)
    out (result)
    {
        assert(_readBuffer.readAvailable == 0);
        assert(_writeBuffer.readAvailable == 0);
    }
    body
    {
        flush(); 
        if (anchor == Anchor.CURRENT) {
            // adjust for the buffer having modified the actual stream position
            offset -= _readBuffer.readAvailable;
        }
        _readBuffer.clear();
        return super.seek(offset, anchor);
    }
    
    long size()
    {
        long size = super.size();
        if (supportsSeek) {
            long pos;
            try {
                pos = seek(0, Anchor.CURRENT);
            } catch (PlatformException ex) {
                return size + _writeBuffer.readAvailable;
            }
            size = max(pos + _writeBuffer.readAvailable, size);
        } else {
            // not a seekable stream; we can only write to the end
            size += _writeBuffer.readAvailable;
        }
        return size;
    }
    
    void truncate(long size)
    {
        flush();
        // TODO: truncate _readBuffer at the end
        super.truncate(size);
    }
    
    void flush()
    out
    {
        assert(_writeBuffer.readAvailable == 0);
    }
    body
    {
        while (_writeBuffer.readAvailable)
        {
            size_t result = super.write(_writeBuffer, _writeBuffer.readAvailable);
            if (result == 0) {
                // TODO: throw MORDOR_E_ZEROLENGTHWRITE;
            }
            _writeBuffer.consume(result);
        }
        
        super.flush();
    }
    
    size_t findDelimited(char delim)
    {
        while(true) {
            size_t readAvailable = _readBuffer.readAvailable;
            if (readAvailable >= _getDelimitedSanitySize.val) {
                throw new BufferOverflowException;
            }
            if (readAvailable > 0) {
                ptrdiff_t result = _readBuffer.findDelimited(delim);
                _log.trace("Found delim '{}' on stream {} at location {}", delim, cast(void*)this, result);
                if (result != -1) {
                    return result;
                }
            }

            size_t result = super.read(_readBuffer, _bufferSize);
            if (result == 0) {
                // EOF
                throw new UnexpectedEofException();
            }
        }
    }

    void unread(Buffer b, size_t len)
    {
        scope buf = new Buffer;
        buf.copyIn(b, len);
        buf.copyIn(_readBuffer);
        _readBuffer.clear();
        _readBuffer.copyIn(buf);
    }

private:
    size_t _bufferSize;
    bool _allowPartialReads;
    Buffer _readBuffer;
    Buffer _writeBuffer;
}
