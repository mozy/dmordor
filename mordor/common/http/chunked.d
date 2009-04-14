module mordor.common.http.chunked;

import tango.math.Math;
import Integer = tango.text.convert.Integer;

public import mordor.common.streams.filter;

class ChunkedStream : FilterStream
{
    this(Stream parentStream, bool ownStream = true)
    {
        super(parentStream, ownStream);
        _nextChunk = ~0;
    }
    
    void close(CloseType type)
    {
        if (supportsWrite) {
            parent.write("0\r\n");
        }
        super.close(type);        
    }
    
    size_t read(Buffer b, size_t len)
    {
        if (_nextChunk == ~0) {
            char[] chunk;
            parent.getDelimited(chunk);
            _nextChunk = Integer.parse(chunk, 16);
        }
        if (_nextChunk == 0)
            return 0;
        size_t toRead = min(len, _nextChunk);
        size_t result = super.read(b, toRead);
        _nextChunk -= result;
        if (_nextChunk == 0) {
            char[] chunk;
            parent.getDelimited(chunk);
            _nextChunk = ~0;
        }
        return result;
    }
    
    size_t write(Buffer b, size_t len)
    {
        parent.write(Integer.toString(len, "x") ~ "\r\n");
        scope copy = new Buffer();
        copy.copyIn(b, len);
        while (copy.readAvailable > 0) {
            size_t result = super.write(copy, copy.readAvailable);
            copy.consume(result);
        }
        parent.write("\r\n");
        return len;
    }
    
private:
    ulong _nextChunk;
}
