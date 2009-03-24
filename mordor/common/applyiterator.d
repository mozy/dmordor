module mordor.common.applyiterator;

import tango.core.Thread;
import tango.util.log.Log;

private Logger _log;

static this()
{
    _log = Log.lookup("mordor.common.applyiterator");
}

class ApplyIterator(T)
{
    this(int delegate(int delegate(ref T)) dg)
    {
        _dg = dg;
        _fiber = new Fiber(&iterate, 64 * 1024);
        _log.trace("0x{:x}: Starting iteration", cast(void*)_fiber);
        _fiber.call();
    }
    
    ~this()
    {
        if (!_done) {
            _done = true;
            _log.trace("0x{:x}: Aborting iteration", cast(void*)_fiber);
            _fiber.call();
        }
    }
    
    T val() { return *_val; }
    void val(T v) { *_val = v; }
    
    void opAddAssign(size_t delta)
    in
    {
        assert(_skip == 0);
        assert(delta > 0);
        assert(!_done);
    }
    body
    {
        _skip = delta - 1;
        _log.trace("0x{:x}: Continuing iteration", cast(void*)_fiber);
        _fiber.call();
        _log.trace("0x{:x}: Returned from fiber", cast(void*)_fiber);
    }
    
    bool done() { return _done; }
    
private:
    void iterate()
    {
        _log.trace("0x{:x}: Calling opApply", cast(void*)_fiber);
        _dg(delegate int(ref T v) {
            if (_skip > 0) {
                _log.trace("0x{:x}: Skipping", cast(void*)_fiber);
                --_skip;
                return 0;
            }
            _val = &v;
            _log.trace("0x{:x}: Got value, yielding", cast(void*)_fiber);
            Fiber.yield();
            if (_done) {
                _log.trace("0x{:x}: Breaking iteration", cast(void*)_fiber);
                return -1;
            }
            _log.trace("0x{:x}: Returning to opApply", cast(void*)_fiber);
            return 0;
        });
        _log.trace("0x{}: Iteration complete", cast(void*)_fiber);
        _done = true;
    }

private:
    int delegate(int delegate(ref T)) _dg;
    bool _done;
    size_t _skip;
    Fiber _fiber;
    T* _val;
}
