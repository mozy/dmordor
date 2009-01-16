module triton.common.examples.fibers;

import tango.core.Thread;
import tango.io.Stdout;
import tango.util.container.CircularList;

import triton.common.scheduler;

WorkerPool poolA;
WorkerPool poolB;

void main(char[][] args)
{
    CircularList!(int) list = new CircularList!(int);
    Stdout.formatln("I'm running2");

    Fiber f = new Fiber(&fiberProc2);
    f.call();

    Stdout.formatln("I'm running");

    poolA = new WorkerPool("PoolA", 5);
    poolB = new WorkerPool("PoolB", 5);

    poolA.schedule(new Fiber(&fiberProc));

    poolB.start();
    poolA.start();
}

void fiberProc2()
{
    Stdout.formatln("Sup?");
    Fiber.yield();
}

void fiberProc()
{
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolB.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolA.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolB.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolA.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolB.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolA.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolB.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
    poolA.switchTo();
    Stdout.formatln("In pool {0}", Thread.getThis.name);
}
