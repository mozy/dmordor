module mordor.common.examples.fibers;

import tango.io.Stdout;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.scheduler;
import mordor.common.log;

WorkerPool poolA;
WorkerPool poolB;

void main(char[][] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

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
