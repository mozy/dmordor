module mordor.common.streams.duplex;

public import mordor.common.streams.stream;

class DuplexStream : Stream
{
public:
    this(Stream readStream, Stream writeStream, bool ownReadStream = true, bool ownWriteStream = true)
    in
    {
        assert(readStream.supportsRead);
        assert(writeStream.supportsWrite);
    }
    body
    {
        _readStream = readStream;
        _writeStream = writeStream;
        _ownsReadStream = ownReadStream;
        _ownsWriteStream = ownWriteStream;
    }
    
    Stream readStream() { return _readStream; }
    Stream writeStream() { return _writeStream; }
    bool ownsReadStream() { return _ownsReadStream; }
    bool ownsWriteStream() { return _ownsWriteStream; }

    bool supportsRead() { return true; }
    bool supportsWrite() { return true; }
    bool supportsSeek() { return _readStream.supportsSeek; }
    bool supportsSize() { return _readStream.supportsSize; }
    bool supportsTruncate() { return _writeStream.supportsTruncate; }
    
    void close(CloseType type = CloseType.BOTH)
    {
        if ((type == CloseType.READ || type == CloseType.BOTH) && _ownsReadStream) {
            _readStream.close(CloseType.READ);
        }
        if ((type == CloseType.WRITE || type == CloseType.BOTH) && _ownsWriteStream) {
            _writeStream.close(CloseType.WRITE);
        }
    }
    
    size_t read(Buffer b, size_t len) { return _readStream.read(b, len); }
    size_t write(Buffer b, size_t len) { return _writeStream.write(b, len); }
    long seek(long offset, Anchor anchor) { return _readStream.seek(offset, anchor); }
    long size() { return _readStream.size(); }
    void truncate(long size) { _writeStream.truncate(size); }
    void flush() { _writeStream.flush(); }
    size_t findDelimited(char delim) { return _readStream.findDelimited(delim); }
    
protected:
    void readStream(Stream newStream) { _readStream = newStream; }
    void writeStream(Stream newStream) { _writeStream = newStream; }
    void ownsReadStream(bool own) { _ownsReadStream = own; }
    void ownsWriteStream(bool own) { return _ownsWriteStream = own; }

private:
    Stream _readStream, _writeStream;
    bool _ownsReadStream, _ownsWriteStream;    
}
