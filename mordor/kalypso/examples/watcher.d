module mordor.kalypso.examples.watcher;

import tango.io.Stdout;
import tango.stdc.posix.sys.types;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.exception;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.stringutils;
version (linux) import mordor.kalypso.vfs.inotify;
import mordor.kalypso.vfs.model;
version (Windows) import mordor.kalypso.vfs.readdirectorychangesw;

version (Windows) {
    import tango.stdc.stringz;
    import win32.shellapi;
    import win32.winbase;

    void main() {
        int argc;
        wchar** argsPtr = CommandLineToArgvW(GetCommandLineW(), &argc);
        if (argsPtr is null)
            throw exceptionFromLastError();
        wstring[] args;
        args.length = argc;
        foreach(i, arg; argsPtr[0..argc]) {
            args[i] = fromString16z(arg);            
        }
        tmain(args);
    }
} else {
    void main(string[] args) {
        tmain(args);
    }
}

void tmain(tstring[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();
    
    IOManager ioManager = new IOManager(1);
    IWatcher watcher;

    version (linux) watcher = new InotifyWatcher(ioManager,
        delegate void(tstring filename, IWatcher.Events events) {
            Stdout.formatln("File: {} Events: 0x{:x}", filename, events);
        });
    version (Windows) watcher = new ReadDirectoryChangesWWatcher(ioManager,
        delegate void(tstring filename, IWatcher.Events events) {
            Stdout.formatln("File: {} Events: 0x{:x}", filename, events);
        });

    args = args[1..$];
    foreach(arg; args) {
        tstring path = arg;
        watcher.watch(path, IWatcher.Events.All);
    }
    
    ioManager.start(true);
}
