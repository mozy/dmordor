module mordor.kalypso.vfs.model;

import tango.core.Variant;

import mordor.common.streams.stream;
import mordor.common.stringutils;

interface IVFS : IObject
{
    IObject find(tstring path);
}

interface IObject
{
    int children(int delegate(ref IObject) dg);
    int references(int delegate(ref IObject) dg);
    int properties(int delegate(ref tstring) dg);
    Variant opIndex(tstring property);
    void opIndexAssign(Variant value, tstring property);
    void _delete();
    Stream open();
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
        Move                = 0x4000,
        MovedFrom           = 0x0040,
        MovedTo             = 0x0080,
        Open                = 0x0020,
        Security            = 0x0400,
        Size                = 0x8000,

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

    void watch(tstring path, Events events);
}
