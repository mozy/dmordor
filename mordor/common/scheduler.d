module mordor.common.scheduler;

import tango.core.Atomic;
public import tango.core.Thread;
import tango.core.sync.Condition;

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

    void start(bool useCaller)
    {
        foreach (i, t; _threads) {
            if (useCaller && i == 0) {
                t = Thread.getThis;
                t.name = _name;
                continue;
            }
            t = new Thread(_proc);
            t.name = _name;
            t.start();
        }

        if (useCaller) {
            _proc();
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
    }

    this(char[] name, int threads = 1)
    {
        _fibers = new LinkedList!(Fiber)();
        _threads = new ThreadPool(name, &run, threads);
    }

    static Scheduler
    getThis()
    {
        assert(t_scheduler.val);
        return t_scheduler.val;
    }

    void start(bool useCaller = false)
    {
        atomicStore(_stopping, false);
        _threads.start(useCaller);
    }
    
    void stop()
    {
        atomicStore(_stopping, true);
        tickle();
    }
    
    bool stopping()
    {
        return atomicLoad(_stopping);
    }

    void
    schedule(Fiber f)
    {
        assert(f);
        synchronized (_fibers) {
            _fibers.append(f);
            if (_fibers.size == 1) {
                tickle();
            }
        }
    }

    void switchTo()
    {
        if (_threads.contains(Thread.getThis)) {
            return;
        }
        schedule(Fiber.getThis);
        Fiber.yield();
    }

    ThreadPool
    threads()
    {
        return _threads;
    }

protected:
    abstract void idle();
    abstract void tickle();
private:
    void
    run()
    {
        t_scheduler.val = this;
        Fiber idleFiber = new Fiber(&idle);
        while (true) {
            Fiber f;
            synchronized (_fibers) {
                for (auto it = _fibers.begin; it != _fibers.end; ++it) {
                    f = it.val;
                    if (f.state == Fiber.State.EXEC) {
                        continue;
                    }
                    _fibers.erase(it);
                    break;
                }
            }
            if (f) {
                if (f.state != Fiber.State.TERM) {
                    f.call();
                }
                continue;
            }
            if (idleFiber.state == Fiber.State.TERM) {
                return;
            }
            idleFiber.call();
        }
    }

private:

    static ThreadLocal!(Scheduler) t_scheduler;
    ThreadPool                     _threads;
    LinkedList!(Fiber)             _fibers;
    bool                           _stopping;
}

class WorkerPool : Scheduler
{
public:
    this(char[] name, int threads = 1)
    {
        m_mutex = new Mutex();
        m_cond = new Condition(m_mutex);
        super(name, threads);
    }

protected:
    void idle()
    {
        while (true) {
            if (stopping) {
                return;
            }
            synchronized (m_mutex) {
                m_cond.wait();
            }
            Fiber.yield();
        }
    }
    void tickle()
    {
        synchronized (m_mutex) {
            m_cond.notifyAll();
        }
    }

private:
    Mutex m_mutex;
    Condition m_cond;
}

void
parallel_do(void delegate()[] dgs ...) {
    size_t executed = 0;
    size_t completed = 0;
    Fiber current = Fiber.getThis;

    foreach(dg; dgs) {
        Fiber f = new Fiber(delegate void() {
            // can't use dg(), because this doesn't get executed until
            // the Fiber.yield() below, and dg will be out of scope
            dgs[atomicIncrement(executed) - 1]();
            if (atomicIncrement(completed) == dgs.length) {
                Scheduler.getThis.schedule(current);
            }
        });
        Scheduler.getThis.schedule(f);
    }
    Fiber.yield();
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
