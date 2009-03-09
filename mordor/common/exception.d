module mordor.common.exception;

public import tango.core.Exception;
import tango.util.Convert;

class StreamException : PlatformException
{
    this(char[] msg = "", Exception next = null)
    {
        super(msg);
        this.next = next;
    }
}

class UnexpectedEofException : StreamException
{}

class BufferOverflowException : StreamException
{}

class BeyondEofException : StreamException
{}

class ZeroLengthWriteException : StreamException
{}

class StreamTransferException : StreamException
{
    Exception readException;
    Exception writeException;

    this(Exception readException, Exception writeException)
    in
    {
        assert(readException !is null || writeException !is null);
    }
    body
    {
        this.readException = readException;
        this.writeException = writeException;
    }
    
    char[] toString()
    {
        if (readException !is null && writeException !is null) {
            return readException.toString() ~ ", " ~ writeException.toString();
        } else if (readException !is null) {
            return readException.toString();
        } else {
            return writeException.toString();
        }
    }
}

version (Windows) {
    import win32.winbase;
    import win32.winnt;

    class Win32Exception : PlatformException
    {
        uint error;
        char[] desc;

        this(uint error, char[] msg)
        {
            super(msg);
            this.error = error;
            char* desc;
            DWORD numChars = FormatMessage(
                FORMAT_MESSAGE_ALLOCATE_BUFFER |
                FORMAT_MESSAGE_FROM_SYSTEM |
                FORMAT_MESSAGE_IGNORE_INSERTS,
                null,
                error, 0,
                cast(char*)&desc, 0, null);
            if (numChars > 0) {
                this.desc.length = numChars;
                this.desc[] = desc[0..numChars];
                if (this.desc[$ - 1] == '\n')
                    this.desc = this.desc[0..$ - 1];
                LocalFree(cast(HANDLE)desc);
            }
        }
        
        char[] toString()
        {
            char[] ret = to!(char[])(error);
            if (desc.length != 0)
                ret ~= ": " ~ desc;
            if (msg.length != 0)
                ret ~= " - " ~ msg;
            return ret;
        }
    }
    
    alias Win32Exception NativeException;
} else version (Posix) {
    import tango.stdc.errno;
    import tango.stdc.string;

    class ErrnoException : PlatformException
    {
        int errno;
        char[] desc;

        this(int errno, char[] msg)
        {
            super(msg);
            this.errno = errno;
            .errno = 0;
            char* desc = strerror(errno);
            if (.errno == 0) {
                this.desc = desc[0..strlen(desc)];
            }
        }
        
        char[] toString()
        {
            char[] ret = to!(char[])(errno);
            if (desc.length != 0)
                ret ~= ": " ~ desc;
            if (msg.length != 0)
                ret ~= " - " ~ msg;
            return ret;
        }
    }
    
    alias ErrnoException NativeException;
    private alias errno GetLastError;
}

Exception exceptionFromLastError(char[] msg = "")
{
    return exceptionFromLastError(GetLastError(), msg);
}

Exception exceptionFromLastError(int error, char[] msg = "")
{
    return new NativeException(error, msg);
}
