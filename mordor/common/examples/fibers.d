module mordor.common.examples.fibers;

import tango.core.Thread;
import tango.io.Stdout;

import mordor.common.scheduler;

WorkerPool poolA;
WorkerPool poolB;

void main(char[][] args)
{
    poolA = new WorkerPool("PoolA", 5);
    poolB = new WorkerPool("PoolB", 5);

    poolA.schedule(new Fiber(&fiberProc));

    poolB.start();
    poolA.start(true);
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
    poolB.stop();
    poolA.stop();
}
