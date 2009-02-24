module mordor.common.result;

public import tango.stdc.errno;

// a result_t is an HRESULT, except that on a 64-bit platform all 4 upper bytes
// have to be set for it to be an error
alias ptrdiff_t result_t;


enum : uint
{
    SEVERITY_SUCCESS = 0,
    SEVERITY_ERROR = 1
}

enum : uint
{
    FACILITY_WINRM                   = 51,
    FACILITY_WINDOWSUPDATE           = 36,
    FACILITY_WINDOWS_DEFENDER        = 80,
    FACILITY_WINDOWS_CE              = 24,
    FACILITY_WINDOWS                 = 8,
    FACILITY_URT                     = 19,
    FACILITY_UMI                     = 22,
    FACILITY_TPM_SOFTWARE            = 41,
    FACILITY_TPM_SERVICES            = 40,
    FACILITY_SXS                     = 23,
    FACILITY_STORAGE                 = 3,
    FACILITY_STATE_MANAGEMENT        = 34,
    FACILITY_SSPI                    = 9,
    FACILITY_SCARD                   = 16,
    FACILITY_SHELL                   = 39,
    FACILITY_SETUPAPI                = 15,
    FACILITY_SECURITY                = 9,
    FACILITY_RPC                     = 1,
    FACILITY_PLA                     = 48,
    FACILITY_WIN32                   = 7,
    FACILITY_CONTROL                 = 10,
    FACILITY_NULL                    = 0,
    FACILITY_NDIS                    = 52,
    FACILITY_METADIRECTORY           = 35,
    FACILITY_MSMQ                    = 14,
    FACILITY_MEDIASERVER             = 13,
    FACILITY_INTERNET                = 12,
    FACILITY_ITF                     = 4,
    FACILITY_USERMODE_HYPERVISOR     = 53,
    FACILITY_HTTP                    = 25,
    FACILITY_GRAPHICS                = 38,
    FACILITY_FWP                     = 50,
    FACILITY_FVE                     = 49,
    FACILITY_USERMODE_FILTER_MANAGER = 31,
    FACILITY_DPLAY                   = 21,
    FACILITY_DISPATCH                = 2,
    FACILITY_DIRECTORYSERVICE        = 37,
    FACILITY_CONFIGURATION           = 33,
    FACILITY_COMPLUS                 = 17,
    FACILITY_USERMODE_COMMONLOG      = 26,
    FACILITY_CMI                     = 54,
    FACILITY_CERT                    = 11,
    FACILITY_BACKGROUNDCOPY          = 32,
    FACILITY_ACS                     = 20,
    FACILITY_AAF                     = 18,
}


result_t MAKERESULT(uint severity, uint facility, size_t code)
/*in
{
    static if (result_t.sizeof == 8) {
        assert(code <= 0xffffU || severity == 0U && facility == 0U &&
            code <= 0x7fffffff_ffffffffUL);
    } else {
        assert(code <= 0xffffU || severity == 0U && facility == 0U &&
            code <= 0x7ffffffffU);
    }
    assert(facility <= 0x1fff);
    assert(severity == 0U || severity == 1U);
}
body*/
{
    static if (result_t.sizeof == 8) {
        if (severity == 1) {
            return 0xffffffff80000000 | (facility << 16) | code;
        } else {
            return (facility << 16) | code;
        }
    } else {
        return (severity << 31) | (facility << 16) | code;
    }
}

uint RESULT_SEVERITY(result_t result)
{
    static if (result_t.sizeof == 8) {
        return (result >> 31) == 0x1ffffffffL ? SEVERITY_ERROR : SEVERITY_SUCCESS;
    } else {
        return (result >> 31) & 1;
    }
}
uint RESULT_FACILITY(result_t result)
{ return (result >> 16) & 0x1fff; }
uint RESULT_CODE(result_t result)
{ return result & 0xffff; }

bool FAILED(result_t result)
{ return RESULT_SEVERITY(result) == SEVERITY_ERROR; }
bool SUCCEEDED(result_t result)
{ return RESULT_SEVERITY(result) == SEVERITY_SUCCESS; }

result_t RESULT_FROM_WIN32(uint error)
{
    if (error == 0)
        return S_OK;
    return MAKERESULT(1, FACILITY_WIN32, error & 0xffff);
}

enum : result_t
{
    S_OK            = 0x00000000,
    S_FALSE         = 0x00000001,
    E_UNEXPECTED    = 0x8000ffff,
    E_NOTIMPL       = 0x80004001,
    E_OUTOFMEMORY   = 0x8007000e,
    E_INVALIDARG    = 0x80070057,
    E_NOINTERFACE   = 0x80004002,
    E_POINTER       = 0x80004003,
    E_HANDLE        = 0x80070006,
    E_ABORT         = 0x80004004,
    E_FAIL          = 0x80004005,
    E_ACCESSDENIED  = 0x80070005,
    E_PENDING       = 0x8000000a,
}

enum : uint
{
    FACILITY_MORDOR = 0xbd5, // good 'ol BDS
    FACILITY_POSIX = 0xbd6,
}

enum : result_t
{
    MORDOR_E_ZEROLENGTHWRITE = 0x8bd50001,
    MORDOR_E_BUFFEROVERFLOW  = 0x8bd50002,
    MORDOR_E_UNEXPECTEDEOF   = 0x8bd50003,
    MORDOR_E_READFAILURE     = 0x8bd50004,
    MORDOR_E_WRITEFAILURE    = 0x8bd50005,
}

result_t RESULT_FROM_ERRNO(int rc)
{
    if (rc == 0)
        return S_OK;
    return MAKERESULT(1, FACILITY_POSIX, rc & 0xffff);
}

version (Windows) {
    import win32.winbase;

    enum : uint {
        FACILITY_NATIVE = FACILITY_WIN32
    }

} else version (Posix) {
    enum : uint {
        FACILITY_NATIVE = FACILITY_POSIX
    }
    
    private alias errno GetLastError;
}

result_t RESULT_FROM_LASTERROR()
{
    return MAKERESULT(SEVERITY_ERROR, FACILITY_NATIVE, GetLastError());
}

result_t RESULT_FROM_LASTERROR(int rc)
{
    if (rc == 0)
        return S_OK;
    if (rc < 0) {
        return RESULT_FROM_LASTERROR();
    }
    return rc;
}

result_t RESULT_FROM_LASTERROR(int rc, int error)
{
    if (rc == 0)
        return S_OK;
    if (rc < 0) {
        return MAKERESULT(SEVERITY_ERROR, FACILITY_NATIVE, error);
    }
    return rc;
}

result_t RESULT_FROM_LASTERROR(bool ret)
{
    if (!ret)
        return RESULT_FROM_LASTERROR();
    return S_OK;
}

result_t RESULT_FROM_LASTERROR(bool ret, int error)
{
    if (!ret)
        return MAKERESULT(SEVERITY_ERROR, FACILITY_NATIVE, error);
    return S_OK;
}
