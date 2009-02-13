module mordor.common.examples.cat;

import tango.core.Thread;
import tango.io.Stdout;

import mordor.common.scheduler;
import mordor.common.streams.fd;
import mordor.common.streams.streamtostream;

void main()
{
    Stream stdin = new FDStream(0, false);
    Stream stdout = new FDStream(1, false);
    
    WorkerPool pool = new WorkerPool("pool", 2);
    
    pool.schedule(new Fiber(delegate void() {
        streamToStream(stdin, stdout);
        pool.stop();
    }));
    pool.start(true);
}
