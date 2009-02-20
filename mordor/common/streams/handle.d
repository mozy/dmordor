module mordor.common.streams.handle;

import win32.winbase;
import win32.winnt;

import mordor.common.iomanager;
public import mordor.common.streams.stream;

class HandleStream : Stream
{
public:
	this(HANDLE hFile, bool ownHandle = true)
	{
		_hFile = hFile;
		_own = ownHandle;
	}
	
	this(IOManager ioManager, HANDLE hFile, bool ownHandle = true)
	{
		_ioManager = ioManager;
		_hFile = hFile;
		_own = ownHandle;
	}
	
	result_t close(CloseType type)
	in
	{
		assert(type == CloseType.BOTH);
	}
	body
	{
		if (_hFile != INVALID_HANDLE_VALUE && _own) {
			CloseHandle(_hFile);
			_hFile = INVALID_HANDLE_VALUE;
		}
		return 0;
	}
	
	bool supportsRead() { return true; }
	bool supportsWrite() { return true; }
	
	result_t read(Buffer b, size_t len)
	{
		return -1;
	}
	
	result_t write(Buffer b, size_t len)
	{
		return -1;
	}
	
private:
	IOManager _ioManager;
	HANDLE _hFile;
	bool _own;
}
