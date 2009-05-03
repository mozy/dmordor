module mordor.common.http.pool;

import mordor.common.http.client;

class ConnectionPool
{
    this(ClientConnection delegate() dg, size_t maxConns = 10)
    {
        _dg = dg;
        _maxConns = maxConns;
    }
    
    ClientConnection get(size_t maxDepth = 10)
    {
        if (maxDepth > 0) {
            synchronized (this) {
                foreach(c; _conns) {
                    if (c.requestDepth + c.responseDepth < maxDepth)
                        return c;
                }
                if (_conns.length < _maxConns) {
                    _conns ~= _dg();
                    return _conns[$-1];
                }
            }
        } else {
            synchronized (this) {
                //if (_conns.length < _maxConns) {
                    _conns ~= _dg();
                    return _conns[$-1];
                //}
            }
        }
        // TODO: suspend this fiber until a conn is available
        assert(false);
    }
    
private:
    ClientConnection delegate() _dg;
    size_t _maxConns;
    ClientConnection[] _conns;
}
