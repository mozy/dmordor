module mordor.kalypso.vfs.fuse;

import tango.core.Memory;
import tango.core.Thread;
import tango.stdc.errno;
import tango.stdc.stdint;
import tango.stdc.stringz;
import tango.stdc.posix.fcntl;
import tango.stdc.posix.sys.stat;
import tango.text.util;
import tango.util.log.AppendConsole;
import tango.util.log.Log;

import fuse.fuse;

import mordor.common.config;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.kalypso.vfs.helpers;
import mordor.kalypso.vfs.model;
import mordor.kalypso.vfs.triton;

IObject _root;
Logger _log, _logReaddir;
extern (C) int printf(char* format, ...);
static this()
{
    _log = Log.lookup("mordor.kalypso.vfs.fuse");
    _logReaddir = Log.lookup("mordor.kalypso.vfs.fuse.readdir");
}

void attachThread()
{
    if (Thread.getThis is null) {
        thread_attachThis();
        new WorkerPool("fuse");
    }
}
    
extern (C) int vfs_getattr(char* path, stat_t* stbuf)
{
    attachThread();
    _log.trace("in getattr");
    try {
        char[] pathstr = fromStringz(path);
        _log.trace("getattr '{}'", pathstr);
        switch (pathstr) {
            case "/":
                stbuf.st_mode = S_IFDIR | 0755;
                stbuf.st_nlink = 3;
                return 0;
            case "/._.":
            case "/.metadata_never_index":
            case "/Backups.backupdb":
            case "/mach_kernel":
            case "/.DS_Store":
            case "/.Spotlight-V100":
            case "/DCIM":
                return -ENOENT;
            default:
                break;
        }
        return -ENOENT;
    } catch (Object o) {
        auto ex = cast(Exception)o;
        if (ex !is null) {
            _log.fatal("In getattr, unhandled exception: {}@{}:{}", ex, ex.file, ex.line);
            if (ex.next !is null) {
                ex = ex.next;
                _log.fatal("In getattr, unhandled exception: {}@{}:{}", ex, ex.file, ex.line);
            }
        } else {
            _log.fatal("In getattr, unhandled exception: {}", o);
        }
        return -ENOENT;
    }
}

struct DirContext
{
    off_t offset;
    bool done;
    bool full;
    Fiber fiber;
    void* buf;
    fuse_fill_dir_t filler;
    IObject obj;
    
    void run()
    {
        if (done) {
            _logReaddir.trace("readdir aborted");
            return;
        }
        ++offset;
        _logReaddir.trace("readdir worker '.' ({})", offset);
        if (filler(buf, ".\0", null, offset)) {
            _logReaddir.trace("readdir buffer full");
            full = true;
            Fiber.yield();
            if (done) {
                _logReaddir.trace("readdir aborted");
                return;
            }
        }
        ++offset;
        _logReaddir.trace("readdir worker '..' ({})", offset);
        if (filler(buf, "..\0", null, offset)) {
            _logReaddir.trace("readdir buffer full");
            full = true;
            Fiber.yield();
            if (done) {
                _logReaddir.trace("readdir aborted");
                return;
            }
        }
        foreach(c; &obj.children) {
            string path = getFullPath(c);
            ++offset;
            _logReaddir.trace("readdir worker '{}' ({})", path, offset);
            if (filler(buf, toStringz(path), null, offset)) {
                _logReaddir.trace("readdir buffer full");
                full = true;
                Fiber.yield();
                if (done) {
                    _logReaddir.trace("readdir aborted");
                    return;
                }
            }
        }
        _logReaddir.trace("readdir complete");
    }
}

extern (C) int vfs_opendir(char* path, fuse_file_info* fi)
{
    attachThread();
    try {
        char[] pathstr = fromStringz(path);
        _log.trace("opendir '{}'", pathstr);
        IObject obj = _root.find(pathstr[1..$]);
        if (obj is null)
            return -ENOENT;
        auto ctx = new DirContext();
        ctx.obj = obj;
        ctx.fiber = new Fiber(&ctx.run, 64 * 1024);
        GC.addRoot(ctx);
        fi.fh = cast(uint64_t)ctx;
        return 0;
    } catch (Object o) {
        return -ENOENT;
    }
}

extern (C) int vfs_readdir(char *path, void *buf, fuse_fill_dir_t filler,
              off_t offset, fuse_file_info *fi)
{
    attachThread();
    try {
        auto ctx = cast(DirContext*)fi.fh;
        _log.trace("readdir '{}' ({})", 1 /*getFullPath(ctx.obj)*/, offset);
        
        if (offset != ctx.offset) {
            return -ENOENT;
        }
        
        ctx.buf = buf;
        ctx.filler = filler;
        ctx.full = false;
        
        while (true) {
            if (ctx.full || ctx.fiber.state == Fiber.State.TERM)
                return 0;
            ctx.fiber.call();
        }
    } catch (Object o) {
        _log.error("oh crap {}", o);
    }
}

extern (C) int vfs_releasedir(char* path, fuse_file_info* fi)
{
    attachThread();
    auto ctx = cast(DirContext*)fi.fh;
    _log.trace("releasedir '{}'", getFullPath(ctx.obj));
    ctx.done = true;
    if (ctx.fiber.state != Fiber.State.TERM)
        ctx.fiber.call();
    assert(ctx.fiber.state == Fiber.State.TERM);
    GC.removeRoot(ctx);
    delete ctx.fiber;
    delete ctx;
    return 0;
}


fuse_operations ops = {
    getattr : &vfs_getattr,
    opendir : &vfs_opendir,
    readdir : &vfs_readdir,
    releasedir : &vfs_releasedir,
};    

int
main(char[][] argv)
{
    Config.loadFromEnvironment();
    Log.root.add(new AppendConsole());
    enableLoggers();

    _root = TritonVFS.get.registerContainer("barbara-at-barbarastogner.com@mozy.test", 162958);
    
    char*[] argv2;
    argv2.length = argv.length;
    foreach (i, arg; argv) {
        argv2[i] = arg.ptr;
    }
    return fuse_main(argv.length, argv2.ptr, &ops, null);
}
