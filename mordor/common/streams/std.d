module mordor.common.streams.std;

public import mordor.common.streams.stream;

version (Windows) {
    import win32.winbase;
	
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
			super(GetStdHandle(STD_INPUT_HANDLE), true);
		} else version (Posix) {
			super(STDIN_FILENO, false);
		}
	}
	
	bool supportsWrite() { return false; }
	
	result_t write() { assert(false); return -1; }
}

class StdoutStream : NativeStream
{
public:
	this() {
		version (Windows) {
			super(GetStdHandle(STD_OUTPUT_HANDLE), true);
		} else version (Posix) {
			super(STDOUT_FILENO, false);
		}
	}
	
	bool supportsRead() { return false; }
	
	result_t read() { assert(false); return -1; }
}

class StderrStream : NativeStream
{
public:
	this() {
		version (Windows) {
			super(GetStdHandle(STD_ERROR_HANDLE), true);
		} else version (Posix) {
			super(STDERR_FILENO, false);
		}
	}
	
	bool supportsRead() { return false; }
	
	result_t read() { assert(false); return -1; }
}
