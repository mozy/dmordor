module mordor.common.examples.cat;

import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.scheduler;
import mordor.common.streams.std;
import mordor.common.streams.streamtostream;

void main()
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    Stream stdin = new StdinStream;
    Stream stdout = new StdoutStream;
    
    WorkerPool pool = new WorkerPool("pool", 2);

    pool.schedule(new Fiber(delegate void() {
        streamToStream(stdin, stdout);
        pool.stop();
    }));
    pool.start(true);
}
