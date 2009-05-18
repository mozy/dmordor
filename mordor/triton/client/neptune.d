module mordor.triton.client.neptune;

import tango.net.InternetAddress;
import tango.stdc.stringz;
import tango.util.log.AppendConsole;

import mordor.common.asyncsocket;
import mordor.common.config;
import mordor.common.http.client;
import mordor.common.iomanager;
import mordor.common.log;
import mordor.common.streams.socket;
import mordor.common.streams.file;
import mordor.common.streams.transfer;
import mordor.common.stringutils;
import mordor.triton.client.get;

private IOManager _iomanager;

private struct DRestoreFile
{
    void* context;
    string path;
    long _version;
    string tempPath;
}

extern (C):

private alias void delegate(Exception) ExceptionHandler;
private bool rt_init(ExceptionHandler dg = null );
private bool rt_term(ExceptionHandler dg = null );

export int dneptuneInit()
{
    try {
        if (!rt_init()) {
            return -1;
        }

        Config.loadFromEnvironment();
        Log.root.add(new AppendConsole());
        enableLoggers();

        _iomanager = new IOManager(1, false);

        return 0;
    } catch (Object o) {
        return -1;
    }    
}

export int dneptuneTerminate()
{
    try {
        _iomanager.stop();
    
        if (!rt_term()) {
            return -1;
        }
        return 0;
    } catch (Object o) {
        return -1;
    }
}
    
struct RestoreFile
{
    void* context;
    size_t pathLength;
    char* path;
    long _version;
    size_t tempPathLength;
    char* tempPath;
}

alias void function(void*, int, long) FileRestoredCB;
alias void function(void*, int) RestoreDoneCB;
private int printf(char* format, ...);
export int dneptuneRestoreFiles(char* tritonHost,
                        size_t count, RestoreFile* files,
                        char* username,
                        long machineId,
                        FileRestoredCB fileCB, RestoreDoneCB doneCB,
                        void* context)
in
{
    assert(doneCB);
}
body
{
    try {
        Fiber f = new Fiber({
            string ltritonHost = fromStringz(tritonHost).dup;
            DRestoreFile[] lfiles;
            static assert(RestoreFile.sizeof == DRestoreFile.sizeof);
            lfiles = cast(DRestoreFile[])files[0..count].dup;
            foreach(file; lfiles) {
                file.path = file.path.dup;
                file.tempPath = file.tempPath.dup;
            }
            string lusername = fromStringz(username).dup;
            long lmachineId = machineId;
            FileRestoredCB lfileCB = fileCB;
            RestoreDoneCB ldoneCB = doneCB;
            void* lcontext = context;
            Fiber.yield();

            try {
                scope s = new AsyncSocket(_iomanager, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
                s.connect(new InternetAddress(ltritonHost));
                scope stream = new SocketStream(s);
                
                scope conn = new ClientConnection(stream);
                Object innerException;
                parallel_foreach(lfiles, delegate int (ref DRestoreFile file) {
                    try {
                        long read, written;
                        {
                            scope tempFile = new FileStream(file.tempPath);
                            transferStream(get(conn, lusername, lmachineId, file.path), tempFile, read, written);
                        }
                        lfileCB(file.context, 0, written);
                    } catch (Object o) {
                        return 0;
                    }
                    return 0;
                }, 10);
            } catch (Object o) {
                ldoneCB(lcontext, -1);                
            }
        }, 65536);
        // Dynamic closur-ish
        f.call();
        _iomanager.schedule(f);
        return 0;
    } catch (Object o) {
        return -1;
    }
}
