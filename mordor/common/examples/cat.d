module mordor.common.examples.cat;

import tango.io.Stdout;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.scheduler;
import mordor.common.streams.file;
import mordor.common.streams.std;
import mordor.common.streams.transfer;
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
            if (arg == "-")
                inStream = new StdinStream;
            else
                inStream = new FileStream(arg, FileStream.Flags.READ);

            result_t result = transferStream(inStream, stdout);
            if (FAILED(result)) {
                Stderr.formatln("Unable to read {}", arg);
            }
        }
        pool.stop();
    }));
    pool.start(true);
}
