module mordor.kalypso.examples.watcher;

import tango.io.Stdout;
import tango.stdc.posix.sys.types;
import tango.util.log.AppendConsole;

import mordor.common.config;
import mordor.common.exception;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.stringutils;
import mordor.kalypso.vfs.manager;


void tmain(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    IOManager ioManager = new IOManager(1);

    IVFS vfs = cast(IVFS)VFSManager.get.find("native");
    assert(vfs !is null);
    auto watchableVFS = cast(IWatchableVFS)vfs;
    if (watchableVFS is null) {
        Stderr.formatln("Native VFS is not watchable!");
        return;
    }

    IWatcher watcher = watchableVFS.getWatcher(ioManager,
        delegate void(tstring filename, IWatcher.Events events) {
            Stdout.formatln("File: {} Events: 0x{:x}", filename, events);
        });

    args = args[1..$];
    foreach(arg; args) {
        try {
            auto object = vfs.find(arg);
            watcher.watch(object, IWatcher.Events.All);
        } catch (PlatformException ex) {
            Stderr.formatln("{} - {}", arg, ex);
        }
    }

    ioManager.start(true);
}
