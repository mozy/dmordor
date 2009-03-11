module mordor.utils.deflate;

import tango.io.Stdout;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.scheduler;
import mordor.common.streams.file;
import mordor.common.streams.std;
import mordor.common.streams.transfer;
import mordor.common.streams.zlib;
import mordor.common.stringutils;

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    Stream stdout = new StdoutStream;
    
    WorkerPool pool = new WorkerPool("pool", 1);

    pool.schedule(new Fiber(delegate void() {
        Stream stdin = new StdinStream;
        Stream stdout = new StdoutStream;        

        ZlibStream zlibStream = new ZlibStream(stdout, false);
        transferStream(stdin, zlibStream);
        zlibStream.close();
        pool.stop();
    }, 64 * 1024));
    pool.start(true);
}
