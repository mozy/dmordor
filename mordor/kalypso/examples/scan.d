module mordor.kalypso.examples.scan;

import tango.util.log.AppendConsole;
import tango.io.Stdout;

import mordor.common.config;
import mordor.common.exception;
import mordor.common.log;
import mordor.kalypso.vfs.manager;

void main()
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();
    
    void recurse(IObject object, int level) {
        for(int i = 0; i < level * 4; ++i)
            Stdout.format(" ");
        Stdout.formatln("{}", object["name"]);
        if (level >= 2)
            return;
        try {
            foreach (child; &object.children) {
                recurse(child, level + 1);
            }
        } catch (PlatformException ex) {
            Stderr.formatln("{}", ex);
        }
    }
    
    foreach(vfs; VFSManager.get) {
        recurse(vfs, 0);        
    }    
}
