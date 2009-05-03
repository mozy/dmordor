module mordor.common.coroutine;

import tango.core.Thread;

class Coroutine(Result, ParamsTuple...)
{
    static if (ParamsTuple.length == 0) {
        alias void Params;
    } else static if (ParamsTuple.length == 1) {
        alias ParamsTuple[0] Params;
    } else {
        struct Params
        {
            ParamsTuple params;
        }
    }

    this(Result delegate(Coroutine!(Result, ParamsTuple), ParamsTuple) dg)
    {
        _dg = dg;
        _fiber = new Fiber(&run);
    }
    
    Result call(ParamsTuple params) {
        static if (ParamsTuple.length == 1) {
            _params = params[0];
        } else static if (ParamsTuple.length > 1) {
            _params.params = params;
        }
        _fiber.call();
        static if(!is(Result : void)) {
            return _result;
        }
    }
    
    static if(is(Result : void)) {
        Params yield() {
            _fiber.yield();
            static if (ParamsTuple.length > 0) {
                return _params;
            }
        }
    } else {
        Params yield(Result result) {
            _result = result;
            _fiber.yield();
            static if (ParamsTuple.length > 0) {
                return _params;
            }
        }
    }
    
    static if(ParamsTuple.length <= 1) {
        Params yieldTo()(Coroutine!(Params) other)
        {
            other._fiber.yieldTo();
            static if (ParamsTuple.length > 0) {
                return _params;
            }
        }

        Params yieldTo(OtherParam)(Coroutine!(Params, OtherParam) other, OtherParam otherParams)
        {
            other._params = otherParams;
            other._fiber.yieldTo();
            static if (ParamsTuple.length > 0) {
                return _params;
            }
        }
    }

    Fiber.State state()
    {
        return _fiber.state;
    }

private:
    void run()
    {
        static if (!is(Result : void)) {
            static if (ParamsTuple.length > 0) {
                _result = _dg(this, _params);
            } else {
                _result = _dg(this);
            }
        } else {
            static if (ParamsTuple.length == 0) {
                _dg(this);
            } else static if (ParamsTuple.length == 1) {
                _dg(this, _params);
            } else {
                _dg(this, _params.params);
            }
        }
    }
    
private:
    Result delegate (Coroutine!(Result, ParamsTuple), ParamsTuple) _dg;
    static if (!is(Result : void)) {
        Result _result;
    }
    static if (ParamsTuple.length > 0) {
        Params _params;
    }
    Fiber _fiber;
}

import tango.io.Stdout;

unittest
{
    int countTo5(Coroutine!(int) self) {
        self.yield(1);
        self.yield(2);
        self.yield(3);
        self.yield(4);
        return 5;
    }
    
    auto coro = new Coroutine!(int)(&countTo5);
    while (coro.state != Fiber.State.TERM) {
        Stdout.formatln("{}", coro.call());
    }
}

unittest
{
    void tellMe5(Coroutine!(void, int) self, int n) {
        while (n < 5) {
            Stdout.formatln("{}", n);
            n = self.yield();
        }
    }
    
    auto coro = new Coroutine!(void, int)(&tellMe5);
    for(int i = 0; i < 6; ++i) {
        assert(coro.state == Fiber.State.HOLD);
        coro.call(i);        
    }
    assert(coro.state == Fiber.State.TERM);
}

unittest
{
    void countToTen(Coroutine!(void, int, int) self, int num1, int num2)
    {
        while (num1 < 5) {
            Stdout.formatln("{}, {}", num1, num2);
            auto ret = self.yield();
            num1 = ret.params[0];
            num2 = ret.params[1];
        }
    }
    
    auto coro = new Coroutine!(void, int, int)(&countToTen);
    for(int i = 0; i < 6; ++i) {
        assert(coro.state == Fiber.State.HOLD);
        coro.call(i, i + 5);
    }
    assert(coro.state == Fiber.State.TERM);
}

unittest
{
    Coroutine!(int) producerCoro;
    Coroutine!(void, int) consumerCoro;

    int producer(Coroutine!(int) self) {
        for (int i = 0; i < 5; ++i)
            self.yieldTo!(int)(consumerCoro, i);
        return 0;
    }
    
    producerCoro = new Coroutine!(int)(&producer);
    
    void consumer(Coroutine!(void, int) self, int val) {
        while (true) {
            Stdout.formatln("{}", val);
            val = self.yieldTo(producerCoro);
        }
    }
    
    consumerCoro = new Coroutine!(void, int)(&consumer);
    
    producerCoro.call();
    Stdout.formatln("done");
}

void main()
{
}
