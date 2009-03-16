module mordor.kalypso.examples.watcher;

import tango.io.Stdout;
import tango.stdc.posix.sys.types;
import tango.sys.linux.inotify;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.log;
import mordor.common.stringutils;
import mordor.kalypso.vfs.inotify;

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    scope inotify = new InotifyWatcher(delegate void(tstring filename, uint events) {
        Stdout.formatln("File: {} Events: 0x{:x}", filename, events);
    });

    args = args[0..$];
    foreach(arg; args) {
        string path = arg;
        uint events = IN_ALL_EVENTS;
        if (path.length > 0 && path[$ - 1] == '/') {
            path.length = path.length - 1;
        }
        inotify.watch(path, events);
    }
    inotify.run();
}
