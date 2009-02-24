module mordor.utils.sha0sum;

import tango.io.digest.Sha0;
import tango.io.Stdout;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.scheduler;
import mordor.common.streams.digest;
import mordor.common.streams.nil;
import mordor.common.streams.std;
import mordor.common.streams.transfer;

void main()
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    Stream stdin = new StdinStream;
    DigestStream digest = new DigestStream(stdin, new Sha0);
    
    WorkerPool pool = new WorkerPool("pool", 1);

    pool.schedule(new Fiber(delegate void() {
        transferStream(digest, NilStream.get);
        Stdout.formatln("{}", digest.hexDigest());
        pool.stop();
    }));
    pool.start(true);
}
