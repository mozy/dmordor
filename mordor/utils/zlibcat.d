module mordor.utils.zlibcat;

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
        if (args.length == 1)
            args ~= "-";
        foreach(string arg; args[1..$]) {
            Stream inStream;
            if (arg == "-") {
                inStream = new StdinStream;
            } else {
                try {
                    inStream = new FileStream(arg, FileStream.Flags.READ);
                } catch (Exception ex) {
                    Stderr.formatln("{}  {}", arg, ex);
                    continue;
                }
            }

            try {
                transferStream(new ZlibStream(inStream, false), stdout);
            } catch (Exception ex) {
                Stderr.formatln("{}  {}", arg, ex);
            }
        }
        pool.stop();
    }, 64 * 1024));
    pool.start(true);
}
