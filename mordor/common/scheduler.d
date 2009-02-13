module mordor.common.scheduler;

import tango.core.Atomic;
import tango.core.Thread;
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
private:
    struct FiberAndTicket
    {
        Fiber  fiber;
        size_t ticket;
    }

public:
    static this()
    {
        t_scheduler = new ThreadLocal!(Scheduler)();
    }

    this(char[] name, int threads = 1)
    {
        _fibers = new LinkedList!(FiberAndTicket)();
        _threads = new ThreadPool(name, &run, threads);
        _ticket = 1;
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
    schedule(Fiber f, size_t ticket = 0)
    {
        assert(f);
        synchronized (_fibers) {
            _fibers.append(FiberAndTicket(f, ticket));
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
    
    size_t ticket()
    {
        return atomicIncrement(_ticket);
    }
    
    void wait(size_t ticket)
    {
        synchronized (_fibers) {
            assert((Fiber.getThis in _waiters) is null);
            _waiters[Fiber.getThis] = ticket;
        }
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
                    
                    if (it.ptr.fiber.state == Fiber.State.EXEC) {
                        continue;
                    }
                    size_t* ticket = it.ptr.fiber in _waiters;
                    // Nobody's waiting for this ticket yet
                    if (ticket is null && it.ptr.ticket != 0) {
                        continue;
                    }
                    // Somebody's waiting on a ticket, but it's not this one
                    if (ticket !is null && *ticket != it.ptr.ticket) {
                        continue;
                    }
                    if (ticket !is null) {
                        _waiters.remove(it.ptr.fiber);
                    }
                    f = it.ptr.fiber;
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
    LinkedList!(FiberAndTicket)    _fibers;
    bool                           _stopping;
    size_t                         _ticket;
    size_t[Fiber]                  _waiters;
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
parallel_do(void delegate()[] todo) {
    int completed = 0;
    Fiber current = Fiber.getThis;

    foreach(d; todo) {
        Fiber f = new Fiber(delegate void() {
            d();
            if (atomicIncrement(completed) == todo.length) {
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
