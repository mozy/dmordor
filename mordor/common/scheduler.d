module mordor.common.scheduler;

import tango.core.Atomic;
public import tango.core.Thread;
import tango.core.sync.Semaphore;
import tango.util.log.Log;

import mordor.common.containers.linkedlist;

class ThreadPool
{
public:
    this(char[] name, void delegate() proc, int threads = 1)
    {
        _name = name;
        _proc = proc;
        _threads = new Thread[threads];
    }

    void start()
    {
        foreach (i, t; _threads) {
            t = new Thread(_proc);
            t.name = _name;
            t.start();
        }
    }

    bool
    contains(Thread t)
    {
        synchronized (this) {
            foreach (_t; _threads) {
                /*if (_t == t) {
                    return true;
                }*/
            }
        }
        return false;
    }

    size_t
    size()
    {
        synchronized (this) return _threads.length;
    }

    char[] name()
    {
        return _name;
    }

private:
    char[]          _name;
    void delegate() _proc;
    Thread[]        _threads;
}

class Scheduler
{
public:
    static this()
    {
        t_scheduler = new ThreadLocal!(Scheduler)();
        t_fiber = new ThreadLocal!(Fiber)();
        _log = Log.lookup("mordor.common.scheduler");
    }

    this(char[] name, int threads = 1, bool useCaller = true)
    in
    {
        if (useCaller)
            assert(threads >= 1);
    }
    body
    {
        _fibers = new LinkedList!(Fiber)();
        if (useCaller) {
            --threads;
            assert(getThis() is null, "Only one scheduler is allowed to be associated with any thread");
            Thread.getThis().name = name;
            t_scheduler.val = this;
            t_fiber.val = new Fiber(&run, 65536);
        }
        _threads = new ThreadPool(name, &run, threads);
        _threads.start();
    }

    static Scheduler
    getThis()
    {
        return t_scheduler.val;
    }

    void stop()
    {
        atomicStore(_stopping, true);
        // XXX: This is incorrect for useCaller = true threads
        for (auto i = 0; i < _threads.size; ++i) {
            tickle();
        }
    }
    
    bool stopping()
    {
        return atomicLoad(_stopping);
    }

    void
    schedule(Fiber f)
    {
        assert(f);
        _log.trace("Scheduling fiber {} in scheduler {} from thread {}",
            cast(void*)f, _threads.name, cast(void*)Thread.getThis);
        synchronized (_fibers) {
            _fibers.append(f);
            if (_fibers.size == 1) {
                tickle();
            }
        }
    }

    void switchTo()
    in
    {
        assert(Scheduler.getThis() !is null);
    }
    body
    {
        if (Scheduler.getThis() == this) {
            _log.trace("Skipping switch to scheduler {} because we're already on thread {}",
                _threads.name, cast(void*)Thread.getThis);
            return;
        }
        schedule(Fiber.getThis());
        Scheduler.getThis().yieldTo();
    }

    void yieldTo()
    in
    {
        assert(t_fiber.val);
        assert(Scheduler.getThis() is this);
    }
    body
    {
        t_fiber.val.yieldTo(false);
    }

    ThreadPool
    threads()
    {
        return _threads;
    }

    char[] name()
    {
        return _threads.name;
    }

protected:
    abstract void idle();
    abstract void tickle();
private:
    void
    run()
    {
        t_scheduler.val = this;
        t_fiber.val = Fiber.getThis();
        Fiber idleFiber = new Fiber(&idle, 65536 * 4);
        _log.trace("Starting thread {} in scheduler {} on fiber {}", cast(void*)Thread.getThis, _threads.name, cast(void*)Fiber.getThis);
        while (true) {
            Fiber f;
            synchronized (_fibers) {
                while (f is null) {
                    if (_fibers.empty())
                        break;
                    for (auto it = _fibers.begin; it != _fibers.end; ++it) {
                        f = it.val;
                        if (f.state == Fiber.State.EXEC) {
                            f = null;
                            continue;
                        }
                        _fibers.erase(it);
                        break;
                    }
                }
            }
            if (f) {
                if (f.state != Fiber.State.TERM) {
                    _log.trace("Calling fiber {} on thread {} in scheduler {}", cast(void*)f, cast(void*)Thread.getThis, _threads.name);
                    f.yieldTo();
                    _log.trace("Returning from fiber {} on thread {} in scheduler {}", cast(void*)f, cast(void*)Thread.getThis, _threads.name);
                }
                continue;
            }
            if (idleFiber.state == Fiber.State.TERM) {
                _log.trace("Exiting thread {} in scheduler {}", cast(void*)Thread.getThis, _threads.name);
                return;
            }
            _log.trace("Idling on thread {} in scheduler {}", cast(void*)Thread.getThis, _threads.name);
            idleFiber.call();
            _log.trace("Idling complete on thread {} in scheduler {}", cast(void*)Thread.getThis, _threads.name);
        }
    }

private:

    static ThreadLocal!(Scheduler) t_scheduler;
    static ThreadLocal!(Fiber)     t_fiber;
    ThreadPool                     _threads;
    LinkedList!(Fiber)             _fibers;
    bool                           _stopping;
    static Logger                   _log;
}

class WorkerPool : Scheduler
{
public:
    this(char[] name, int threads = 1, bool useCaller = true)
    {
        _semaphore = new Semaphore();
        super(name, threads, useCaller);
    }

protected:
    void idle()
    {
        while (true) {
            if (stopping) {
                return;
            }
            _semaphore.wait();
            Fiber.yield();
        }
    }
    void tickle()
    {
        _semaphore.notify();
    }

private:
    Semaphore _semaphore;
}

void
parallel_do(void delegate()[] dgs ...)
{
    size_t completed = 0;
    Scheduler scheduler = Scheduler.getThis();
    Fiber caller = Fiber.getThis();
    
    if (scheduler is null) {
        foreach(dg; dgs) {
            dg();
        }
        return;
    }

    foreach(dg; dgs) {
        Fiber f = new Fiber({
            auto localdg = dg;
            Fiber.yield();
            localdg();
            if (atomicIncrement(completed) == dgs.length) {
                scheduler.schedule(caller);
            }
        }, 8192);
        // Give the fiber a chance to copy state to local stack
        f.call();
        scheduler.schedule(f);
    }
    scheduler.yieldTo();
}

void
parallel_foreach(C, T)(C collection, int delegate(ref T) dg,
        int parallelism = -1)
{
    if (parallelism == -1)
        parallelism = 4;
    size_t running;
    Scheduler scheduler = Scheduler.getThis();
    Fiber caller = Fiber.getThis();

    foreach(T t; collection) {
        Fiber f = new Fiber({
            T localt = t;
            Fiber.yield();
            dg(localt);
            // This could be improved; currently it waits for
            // parallelism fibers to complete, then schedules
            // parallelism more; it would be better if we get
            // schedule another as soon as one completes, but
            // it's difficult to *not* schedule another if we're
            // already done
            if (atomicDecrement(running) == 0) {
                scheduler.schedule(caller);
            }
        }, 8192);
        // Dynamic closure-ish
        f.call();
        bool yield = (atomicIncrement(running) >= parallelism);
        scheduler.schedule(f);
        if (yield) {
            scheduler.yieldTo();
        }
    }
    if (running > 0) {
        scheduler.yieldTo();
    }
}

struct Aggregator(T) {
public:
    this(ThreadPool tp) {
        foreach(t; tp) {
            m_free[t] = new T;
        }
    }
    this(Scheduler s) {
        this(s.threads);
    }
    this() {
        this(Scheduler.getThis);
    }
    T current() {
        Thread t = Thread.getThis;
        T ret = m_free[t];
        if (ret is null) {
            synchronized (m_locked) {
                ret = m_locked[t];
                if (ret is null) {
                    ret = m_locked[t] = new T();
                }
            }
        }
        return ret;
    }

private:
    T[Thread] m_free;
    T[Thread] m_locked;
}
