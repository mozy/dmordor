module mordor.common.streams.notify;

public import mordor.common.streams.filter;

class NotifyStream : FilterStream
{
    this(Stream parent, bool ownsParent = true)
    {
        super(parent, ownsParent);
    }
    
    void delegate() notifyOnClose() { return _closeDg; }
    void notifyOnClose(void delegate() dg) { _closeDg = dg; }
    
    void delegate() notifyOnEof() { return _eofDg; }
    void notifyOnEof(void delegate() dg) { _eofDg = dg; }
    
    void close(CloseType type)
    {
        super.close(type);
        if (_closeDg !is null)
            _closeDg();
    }
    
    size_t read(Buffer b, size_t len)
    {
        size_t result = super.read(b, len);
        if (result == 0 && _eofDg !is null) {
            _eofDg();
        }
        return result;
    }
    
private:
    void delegate() _closeDg, _eofDg;
}
