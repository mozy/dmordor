module mordor.common.exception;

public import tango.core.Exception;

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
    {
        this.readException = readException;
        this.writeException = writeException;
    }
}

version (Windows) {
    import win32.winbase;

    class Win32Exception : PlatformException
    {
        uint error;

        this(uint error, char[] msg)
        {
            super(msg);
            this.error = error;
        }
    }
    
    alias Win32Exception NativeException;
} else version (Posix) {
    import tango.stdc.errno;

    class ErrnoException : PlatformException
    {
        int errno;

        this(int errno, char[] msg)
        {
            super(msg);
            this.errno = errno;
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
