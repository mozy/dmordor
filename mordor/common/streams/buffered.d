module mordor.common.streams.buffered;

import tango.math.Math;

import mordor.common.config;
public import mordor.common.streams.filter;

private ConfigVar!(size_t) _defaultBufferSize;
private ConfigVar!(size_t) _getDelimitedSanitySize;

static this()
{
    _defaultBufferSize =
        Config.lookup!(size_t)("stream.buffered.defaultbuffersize",
        cast(size_t)(64 * 1024), "Default buffer size for BufferedStream");
    _getDelimitedSanitySize = 
        Config.lookup!(size_t)("stream.buffered.getdelimitedsanitysize",
        cast(size_t)(16 * 1024 * 1024),
        "Maximum amount to buffer before failing a getDelimited call");
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

    result_t read(Buffer b, size_t len)
    {
        size_t remaining = len;

        size_t buffered = min(_readBuffer.readAvailable, remaining);
        b.copyIn(_readBuffer, buffered);
        _readBuffer.consume(buffered);
        remaining -= buffered;

        if (buffered == 0 || !_allowPartialReads) {
            do {
                // Read enough to satisfy this request, plus up to a multiple of the buffer size 
                size_t todo = ((remaining - 1) / _bufferSize + 1) * _bufferSize;
                result_t result = super.read(_readBuffer, todo);
                if (result <= 0) {
                    if (remaining == len) {
                        return result;
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

    result_t write(Buffer b, size_t len)
    out (result)
    {
        // Partial writes not allowed
        assert(result == len || result < 0);
    }
    body
    {
        _writeBuffer.copyIn(b, len);
        return flushWrite(len);
    }

    result_t write(void[] b)
    out (result)
    {
        // Partial writes not allowed
        assert(result == b.length || result < 0);
    }
    body
    {
        _writeBuffer.reserve(_bufferSize);
        _writeBuffer.copyIn(b);
        return flushWrite(b.length);        
    }
    
    private result_t flushWrite(size_t len)
    {
        while(_writeBuffer.readAvailable > _bufferSize)
        {
            result_t result = super.write(_writeBuffer, _writeBuffer.readAvailable);
            if (result <= 0) {
                // If this entire write is still in our buffer,
                // back it out, and report an error
                if (_writeBuffer.readAvailable >= len) {
                    scope Buffer tempBuffer;
                    tempBuffer.copyIn(_writeBuffer, _writeBuffer.readAvailable - len);
                    _writeBuffer.clear();
                    _writeBuffer.copyIn(tempBuffer);
                    return result;
                } else {
                    // Otherwise we have to say we succeeded,
                    // because we're not allowed to have a partial
                    // write, and we can't report an error because
                    // the caller will think he needs to repeat
                    // the entire write
                    return len;
                }
            } else {
                _writeBuffer.consume(result);
            }
        }
        return len;
    }

    result_t seek(long offset, Anchor anchor, out long pos)
    out (result)
    {
        assert(result < 0 || _readBuffer.readAvailable == 0);
        assert(result < 0 || _writeBuffer.readAvailable == 0);
    }
    body
    {
        result_t result = flush();
        if (result < 0)
            return result;
        
        if (anchor == Anchor.CURRENT) {
            // adjust for the buffer having modified the actual stream position
            offset -= _readBuffer.readAvailable;
        }
        _readBuffer.clear();
        return super.seek(offset, anchor, pos);
    }
    
    result_t size(out long size)
    {
        result_t result = super.size(size);
        if (result == 0) {
            if (supportsSeek) {
                long pos;
                result = seek(0, Anchor.CURRENT, pos);
                if (result < 0) {
                    size += _writeBuffer.readAvailable;
                    return 0;
                }
                size = max(pos + _writeBuffer.readAvailable, size);
            } else {
                // not a seekable stream; we can only write to the end
                size += _writeBuffer.readAvailable;
            }
        }
        return result;
    }
    
    result_t truncate(long size)
    {
        result_t result = flush();
        if (result < 0)
            return result;
        // TODO: truncate _readBuffer at the end
        return super.truncate(size);
    }
    
    result_t flush()
    out (result)
    {
        assert(_writeBuffer.readAvailable == 0 || result < 0);
    }
    body
    {
        while (_writeBuffer.readAvailable)
        {
            result_t result = super.write(_writeBuffer, _writeBuffer.readAvailable);
            if (result < 0) {
                return result;
            } else if (result == 0) {
                return -1;
            }
            _writeBuffer.consume(result);
        }
        
        return super.flush();
    }
    
    result_t getDelimited(out char[] buf, char delim = '\n')
    {
        while(true) {
            size_t readAvailable = _readBuffer.readAvailable;
            if (readAvailable >= _getDelimitedSanitySize.val) {
                return -1;
            }
            if (readAvailable > 0) {
                bool success = _readBuffer.getDelimited(buf, delim);
                if (success) {
                    return 0;
                }
            }

            result_t result = super.read(_readBuffer, _bufferSize);
            if (result < 0) {
                return result;
            } else if (result == 0) {
                // EOF
                buf.length = readAvailable;
                _readBuffer.copyOut(buf, readAvailable);
                _readBuffer.consume(readAvailable);
                return 1;
            }
        }
    }
    
    void unread(Buffer b, size_t len)
    {
        scope Buffer buf;
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
