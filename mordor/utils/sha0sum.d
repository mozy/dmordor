module mordor.utils.sha0sum;

import tango.io.digest.Sha0;
import tango.io.Stdout;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.scheduler;
import mordor.common.streams.digest;
import mordor.common.streams.file;
import mordor.common.streams.nil;
import mordor.common.streams.std;
import mordor.common.streams.transfer;
import mordor.common.stringutils;

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();
        
    WorkerPool pool = new WorkerPool("pool", 1, true);

    if (args.length == 1)
        args ~= "-";
    foreach(string arg; args[1..$]) {
        Stream inStream;
        if (arg == "-")
            inStream = new StdinStream;
        else {
            try {
                inStream = new FileStream(arg, FileStream.Flags.READ);
            } catch (Exception ex) {
                Stderr.formatln("{}  {}", arg, ex);
                continue;
            }
        }

        scope DigestStream digest = new DigestStream(inStream, new Sha0);

        try {
            transferStream(digest, NilStream.get);
            Stdout.formatln("{}  {}", digest.hexDigest(), arg);
        } catch (Exception ex) {
            Stderr.formatln("{}  {}", arg, ex);
        }
    }
}
