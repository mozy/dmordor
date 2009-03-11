module mordor.common.streams.std;

public import mordor.common.streams.stream;

version (Windows) {
    import win32.winbase;
    import win32.winnt;
	
    import mordor.common.exception;
	import mordor.common.streams.handle;
	
	private alias HandleStream NativeStream;
} else version (Posix) {
	import tango.stdc.posix.unistd;
	
	import mordor.common.streams.fd;
	
	private alias FDStream NativeStream;
}

class StdinStream : NativeStream
{
public:
	this() {
		version (Windows) {
            HANDLE hStdIn = GetStdHandle(STD_INPUT_HANDLE);
            if (hStdIn == INVALID_HANDLE_VALUE)
                throw exceptionFromLastError();
            if (hStdIn == NULL)
                throw exceptionFromLastError(ERROR_FILE_NOT_FOUND);
			super(hStdIn, true);
		} else version (Posix) {
			super(STDIN_FILENO, false);
		}
	}
	
	bool supportsWrite() { return false; }
	
	size_t write() { assert(false); }
    
    char[] toString() { return "stdin"; }
}

class StdoutStream : NativeStream
{
public:
	this() {
		version (Windows) {
            HANDLE hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
            if (hStdOut == INVALID_HANDLE_VALUE)
                throw exceptionFromLastError();
            if (hStdOut == NULL)
                throw exceptionFromLastError(ERROR_FILE_NOT_FOUND);
            super(hStdOut, true);
		} else version (Posix) {
			super(STDOUT_FILENO, false);
		}
	}
	
	bool supportsRead() { return false; }
	
	size_t read() { assert(false); }
    
    char[] toString() { return "stdout"; }
}

class StderrStream : NativeStream
{
public:
	this() {
		version (Windows) {
            HANDLE hStdErr = GetStdHandle(STD_ERROR_HANDLE);
            if (hStdErr == INVALID_HANDLE_VALUE)
                throw exceptionFromLastError();
            if (hStdErr == NULL)
                throw exceptionFromLastError(ERROR_FILE_NOT_FOUND);
            super(hStdErr, true);
		} else version (Posix) {
			super(STDERR_FILENO, false);
		}
	}
	
	bool supportsRead() { return false; }
	
	size_t read() { assert(false); }
    
    char[] toString() { return "stderr"; }
}
