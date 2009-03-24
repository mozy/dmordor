module mordor.kalypso.vfs.model;

import tango.core.Variant;
import tango.time.Time;

import mordor.common.iomanager;
import mordor.common.streams.stream;
import mordor.common.stringutils;

interface IVFS : IObject
{
    IObject find(string path);
}

interface ISnapshottableVFS : IVFS
{
    IVFS snapshot(out Time timestamp);
}

interface IVersionedVFS : IVFS
{
    IVFS openVersionAtTimestamp(Time timestamp);
}

interface IObject
{
    IObject parent();
    int children(int delegate(ref IObject) dg);
    int references(int delegate(ref IObject) dg);
    int properties(int delegate(ref string, ref bool, ref bool) dg);
    Variant opIndex(string property);
    Variant[string] opSlice();
    void opIndexAssign(Variant value, string property);
    void opSliceAssign(Variant[string] properties);
    void _delete();
    Stream open();
    IObject create(Variant[string] properties, bool okIfExists = true, Stream* stream = null);
}

interface IVersionedObject : IObject
{
    int versions(int delegate(ref Time) dg);
    IObject openVersionAtTimestamp(Time timestamp);
}

// Children are enumerated in order
interface IOrderedEnumerateObject : IObject
{   
}

interface IWatcher
{
    enum Events
    {
        AccessTime          = 0x0001,
        Attributes          = 0x0800,
        Close               = 0x1000,
        CloseNoWrite        = 0x0010,
        CloseWrite          = 0x0008,
        Create              = 0x0100,
        CreationTime        = 0x2000,
        Delete              = 0x0200,
        Metadata            = 0x0004,
        ModificationTime    = 0x0002,
        MovedFrom           = 0x0040,
        MovedTo             = 0x0080,
        Open                = 0x0020,
        Security            = 0x0400,
        Size                = 0x4000,

        // Events have been dropped
        EventsDropped = 0x02000000,
        // Support for notifications on a file, not just directories (implies IncludeSelf)
        FileDirect = 0x04000000,
        // Include the file/directory itself
        IncludeSelf = 0x08000000,
        // Only return results for files
        Files = 0x10000000,
        // Only return results for directories
        Directories = 0x20000000,
        // Watch automatically removes itself after returning the first (set of) result
        OneShot = 0x40000000,
        // Applies to all sub-directories and files
        Recursive = 0x80000000,

        // Special value... impl does everything it can
        All = 0x0000ffff
    }

    Events supportedEvents();

    bool isReliable(IObject object);
    void watch(IObject object, Events events);
}

interface IWatchableVFS : IVFS
{
    IWatcher getWatcher(IOManager ioManager, void delegate(string, IWatcher.Events));
}
