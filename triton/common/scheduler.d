module triton.common.scheduler;

import tango.core.Atomic;
import tango.core.Thread;
import tango.core.sync.Condition;
import tango.util.container.CircularList;

class ThreadPool
{
public:
    this(char[] name, void delegate() proc, int threads = 1)
    {
        m_name = name;
        m_proc = proc;
        m_threads = new Thread[threads];
    }

    void start(bool useCaller)
    {
        foreach (i, t; m_threads) {
            if (useCaller && i == 0) {
                t = Thread.getThis;
                t.name = m_name;
                continue;
            }
            t = new Thread(m_proc);
            t.name = m_name;
            t.start();
        }

        if (useCaller) {
            m_proc();
        }
    }

    bool
    contains(Thread t)
    {
        synchronized (this) {
            foreach (m_t; m_threads) {
                if (m_t == t) {
                    return true;
                }
            }
        }
        return false;
    }

    size_t
    size()
    {
        synchronized (this) return m_threads.length;
    }

    char[] name()
    {
        return m_name;
    }

private:
    char[] m_name;
    void delegate() m_proc;
    Thread[] m_threads;
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
        m_fibers = new CircularList!(FiberAndThread)();
        m_threads = new ThreadPool(name, &run, threads);
    }

    static void
    autoschedule(Fiber f)
    {
        assert(t_scheduler.val);
        t_scheduler.val.schedule(f);
    }

    static Scheduler
    current()
    {
        assert(t_scheduler.val);
        return t_scheduler.val;
    }

    void start(bool useCaller = false)
    {
        m_threads.start(useCaller);
    }

    void
    schedule(Fiber f, Thread t = null)
    {
        assert(t is null || m_threads.contains(t));
        synchronized (m_fibers) {
            m_fibers.append(FiberAndThread(f, t));
            if (m_fibers.size() == 1) {
                tickle();
            }
        }
    }

    void
    switchTo(Thread t = null)
    {
        /*if (Thread.getThis == t ||
            t is null && m_threads.contains(Thread.getThis)) {
            return;
        }*/
        schedule(Fiber.getThis, t);
        Fiber.yield();
    }

    ThreadPool
    threads()
    {
        return m_threads;
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
            synchronized (m_fibers) {
                if (m_fibers.size() != 0) {
                    foreach(ft; m_fibers) {
                        if (ft.t is null || ft.t == Thread.getThis) {
                            f = ft.f;
                            if (f.state == Fiber.State.EXEC) {
                                continue;
                            }
                            m_fibers.remove(ft, false);
                            break;
                        }
                    }
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
    struct FiberAndThread {
        Fiber f;
        Thread t;
    }

    static ThreadLocal!(Scheduler) t_scheduler;
    ThreadPool                     m_threads;
    CircularList!(FiberAndThread)  m_fibers;
}

class IOManager : Scheduler
{
public:
    this()
    {
        super("IOManager", 1);
    }

protected:
    void idle()
    {}
    void tickle()
    {}
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

/*
class Server
{
public:
    void run() {
        while (true) {
            IOHandle handle = m_listen.accept();
            Connection c = new Connection(handle);
            {
                scope lock (m_connections);
                m_connections.insert(c);
            }
            schedule(new Fiber(c.run));
        }
    }
}
*/


void
parallel_do(void delegate()[] todo) {
    int completed = 0;
    Fiber current = Fiber.getThis;

    foreach(d; todo) {
        Fiber f = new Fiber(delegate void() {
            d();
            if (atomicIncrement(completed) == todo.length) {
                Scheduler.autoschedule(current);
            }
        });
        Scheduler.autoschedule(f);
        Fiber.yield();
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
        this(Scheduler.current);
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
