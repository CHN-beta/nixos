# include <winjob/windows.hpp>
# include <windows.h>
# include <tchar.h>
# include <accctrl.h>
# include <aclapi.h>

namespace winjob
{
  std::optional<std::pair<std::string, std::string>> get_owner(const std::string& file_name)
  {
    DWORD dwRtnCode = 0;
    PSID pSidOwner = NULL;
    BOOL bRtnBool = TRUE;
    LPTSTR AcctName = NULL;
    LPTSTR DomainName = NULL;
    DWORD dwAcctName = 1, dwDomainName = 1;
    SID_NAME_USE eUse = SidTypeUnknown;
    HANDLE hFile;
    PSECURITY_DESCRIPTOR pSD = NULL;

    // Get the handle of the file object.
    hFile = CreateFile
      (file_name.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

    // Check GetLastError for CreateFile error code.
    if (hFile == INVALID_HANDLE_VALUE) return {};

    // Get the owner SID of the file.
    dwRtnCode = GetSecurityInfo(hFile, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, &pSidOwner, NULL, NULL, NULL, &pSD);

    // Check GetLastError for GetSecurityInfo error condition.
    if (dwRtnCode != ERROR_SUCCESS) return {};

    // First call to LookupAccountSid to get the buffer sizes.
    bRtnBool = LookupAccountSid
      (NULL, pSidOwner, AcctName, (LPDWORD)&dwAcctName, DomainName, (LPDWORD)&dwDomainName, &eUse);

    // Reallocate memory for the buffers.
    AcctName = (LPTSTR)GlobalAlloc(GMEM_FIXED, dwAcctName * sizeof(wchar_t));

    // Check GetLastError for GlobalAlloc error condition.
    if (AcctName == NULL) return {};

    DomainName = (LPTSTR)GlobalAlloc(GMEM_FIXED, dwDomainName * sizeof(wchar_t));

    // Check GetLastError for GlobalAlloc error condition.
    if (DomainName == NULL) return {};

    // Second call to LookupAccountSid to get the account name.
    bRtnBool = LookupAccountSid
      (NULL, pSidOwner, AcctName, (LPDWORD)&dwAcctName, DomainName, (LPDWORD)&dwDomainName, &eUse);

    // Check GetLastError for LookupAccountSid error condition.
    if (bRtnBool == FALSE) return {};

    return std::make_pair(std::string(DomainName), std::string(AcctName));
  }
}
