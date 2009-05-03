module mordor.kalypso.examples.scan;

import tango.core.Variant;
import tango.text.convert.TimeStamp;
import tango.time.Time;
import tango.util.log.AppendConsole;
import tango.io.Stdout;

import mordor.common.config;
import mordor.common.exception;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.stringutils;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.manager;
import mordor.kalypso.vfs.triton;

void main(string[] args)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();
    long[string] counts;
    
    void recurse(IObject object, int level) {
        for(int i = 0; i < level * 4; ++i)
            Stdout.format(" ");
        Stdout.formatln("{}", object["name"].get!(string));
        foreach(p, c, s; &object.properties) {
            if (p == "name")
                continue;
            for(int i = 0; i < (level + 1) * 4; ++i)
                Stdout.format(" ");
            Variant v = object[p];
            string cs;
            if (c)
                cs ~= "c";
            if (s)
                cs ~= "s";
            if (v.isA!(string))
                Stdout.formatln("{}@{} = {}", cs, p, v.get!(string));
            else if (v.isA!(bool))
                Stdout.formatln("{}@{} = {}", cs, p, v.get!(bool));
            else if (v.isA!(long))
                Stdout.formatln("{}@{} = {}", cs, p, v.get!(long));
            else if (v.isA!(Time))
                Stdout.formatln("{}@{} = {}", cs, p, toString(v.get!(Time)));
            else if (v.isA!(ushort))
                Stdout.formatln("{}@{} = 0{:o}", cs, p, v.get!(ushort));
            else if (v.isA!(uint))
                Stdout.formatln("{}@{} = {}", cs, p, v.get!(uint));
            else
                Stdout.formatln("{}@{} ({})", cs, p, v);
        }
        foreach(r; &object.references) {
            for(int i = 0; i < (level + 1) * 4; ++i)
                Stdout.format(" ");
            Stdout.formatln("#{}", getFullPath(r));
        }
        string type = object["type"].get!(string);
        long* count = type in counts;
        if (count is null) {
            counts[type] = 0;
            count = type in counts;
        }
        if (++*count % 1000 == 0) {
            Stdout.formatln("{} {}(s)", *count, type);
        }
        if (level >= 8)
            return;
        try {
            foreach (child; &object.children) {
                recurse(child, level + 1);
            }
        } catch (PlatformException ex) {
            Stderr.formatln("{}", ex);
        }
    }
    
    IOManager ioManager = new IOManager();
        
    TritonVFS.get.registerContainer("barbara-at-barbarastogner.com@mozy.test", 162958);
    
    if (args.length > 1) {
        IObject obj = VFSManager.get.find(args[1]);
        recurse(obj, 0);
    } else {
        foreach(vfs; VFSManager.get) {
            recurse(vfs, 0);        
        }
    }

    foreach(t, c; counts) {
        Stdout.formatln("{} {}(s)", c, t);
    }
}
