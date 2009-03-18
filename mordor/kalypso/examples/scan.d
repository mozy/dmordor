module mordor.kalypso.examples.scan;

import tango.core.Variant;
import tango.util.log.AppendConsole;
import tango.io.Stdout;

import mordor.common.config;
import mordor.common.exception;
import mordor.common.log;
import mordor.common.stringutils;
import mordor.kalypso.vfs.manager;

void main()
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();
    long files, dirs;
    
    void recurse(IObject object, int level) {
        /*for(int i = 0; i < level * 4; ++i)
            Stdout.format(" ");
        Stdout.formatln("{}", object["name"].get!(tstring));
        foreach(p; &object.properties) {
            if (p == "name")
                continue;
            for(int i = 0; i < (level + 1) * 4; ++i)
                Stdout.format(" ");
            Variant v = object[p];
            if (v.isA!(tstring))
                Stdout.formatln("@{} = {}", p, v.get!(tstring));
            else if (v.isA!(bool))
                Stdout.formatln("@{} = {}", p, v.get!(bool));                
        }
        foreach(r; &object.references) {
            for(int i = 0; i < (level + 1) * 4; ++i)
                Stdout.format(" ");
            Stdout.formatln("#{}", r["name"].get!(tstring));
        }*/
        Variant directory = object["directory"];
        if (directory.isA!(bool) && directory.get!(bool)) {
            if (++dirs % 1000 == 0) {
                Stdout.formatln("{} dirs", dirs);
            }
        } else {
            if (++files % 1000 == 0) {
                Stdout.formatln("{} files", files);
            }
        }
        //if (level >= 2)
        //    return;
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
    Stdout.formatln("{} dirs {} files", dirs, files);
}
