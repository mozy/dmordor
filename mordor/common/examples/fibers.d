module mordor.common.examples.fibers;

import tango.io.Stdout;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.scheduler;
import mordor.common.log;

WorkerPool poolA;
WorkerPool poolB;
extern (C) int printf(char* format, ...);
void main(char[][] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    poolA = new WorkerPool("PoolA", 1, true);
    poolB = new WorkerPool("PoolB", 1, false);

    try {
        Stdout.formatln("In pool {0}", Thread.getThis.name);
        poolB.switchTo();
        Stdout.formatln("In pool {0}", Thread.getThis.name);
        poolA.switchTo();
        Stdout.formatln("In pool {0}", Thread.getThis.name);
        poolB.switchTo();
        Stdout.formatln("In pool {0}", Thread.getThis.name);
        poolA.switchTo();
        Stdout.formatln("In pool {0}", Thread.getThis.name);
        Stdout.formatln("done!");
        int x = 0;
        while (true) {
            if ((x++ % 2) == 0)
                poolA.switchTo();
            else
                poolB.switchTo();
            printf("In pool %.*s\n", Thread.getThis.name);
        }
    } catch (Object o) {
        Stderr.formatln("exception {}", o);
    }
    poolB.stop();
}
