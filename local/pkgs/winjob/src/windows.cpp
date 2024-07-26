# include <winjob/windows.hpp>
# include <windows.h>
# include <tchar.h>
# include <accctrl.h>
# include <aclapi.h>
# include <winbase.h>

namespace winjob
{
  std::optional<std::pair<std::wstring, std::wstring>> get_owner(std::wstring file_name)
  {
    DWORD dwRtnCode = 0;
    PSID pSidOwner = NULL;
    BOOL bRtnBool = TRUE;
    LPWSTR AcctName = NULL;
    LPWSTR DomainName = NULL;
    DWORD dwAcctName = 1, dwDomainName = 1;
    SID_NAME_USE eUse = SidTypeUnknown;
    HANDLE hFile;
    PSECURITY_DESCRIPTOR pSD = NULL;

    // Get the handle of the file object.
    hFile = CreateFileW
      (file_name.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

    // Check GetLastError for CreateFile error code.
    if (hFile == INVALID_HANDLE_VALUE) return {};

    // Get the owner SID of the file.
    dwRtnCode = GetSecurityInfo(hFile, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, &pSidOwner, NULL, NULL, NULL, &pSD);

    // Check GetLastError for GetSecurityInfo error condition.
    if (dwRtnCode != ERROR_SUCCESS) return {};

    // First call to LookupAccountSid to get the buffer sizes.
    bRtnBool = LookupAccountSidW
      (NULL, pSidOwner, AcctName, (LPDWORD)&dwAcctName, DomainName, (LPDWORD)&dwDomainName, &eUse);

    // Reallocate memory for the buffers.
    AcctName = (LPWSTR)GlobalAlloc(GMEM_FIXED, dwAcctName * sizeof(wchar_t));

    // Check GetLastError for GlobalAlloc error condition.
    if (AcctName == NULL) return {};

    DomainName = (LPWSTR)GlobalAlloc(GMEM_FIXED, dwDomainName * sizeof(wchar_t));

    // Check GetLastError for GlobalAlloc error condition.
    if (DomainName == NULL) return {};

    // Second call to LookupAccountSid to get the account name.
    bRtnBool = LookupAccountSidW
      (NULL, pSidOwner, AcctName, (LPDWORD)&dwAcctName, DomainName, (LPDWORD)&dwDomainName, &eUse);

    // Check GetLastError for LookupAccountSid error condition.
    if (bRtnBool == FALSE) return {};

    return std::make_pair(std::wstring(DomainName), std::wstring(AcctName));
  }

  bool set_permission(std::wstring fileName)
  {
    // Define the SID for the Users group
    PSID pUsersSID = NULL;
    SID_IDENTIFIER_AUTHORITY SIDAuthNT = SECURITY_NT_AUTHORITY;

    if (!AllocateAndInitializeSid(&SIDAuthNT, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_USERS,
      0, 0, 0, 0, 0, 0, &pUsersSID))
      return false;

    // Initialize an EXPLICIT_ACCESS structure for an ACE
    EXPLICIT_ACCESS ea;
    ZeroMemory(&ea, sizeof(EXPLICIT_ACCESS));
    ea.grfAccessPermissions = GENERIC_WRITE;
    ea.grfAccessMode = SET_ACCESS;
    ea.grfInheritance = NO_INHERITANCE;
    ea.Trustee.TrusteeForm = TRUSTEE_IS_SID;
    ea.Trustee.TrusteeType = TRUSTEE_IS_GROUP;
    ea.Trustee.ptstrName = (LPTSTR)pUsersSID;

    // Create a new ACL that contains the new ACE
    PACL pACL = NULL;
    DWORD dwRes = SetEntriesInAcl(1, &ea, NULL, &pACL);
    if (ERROR_SUCCESS != dwRes) { FreeSid(pUsersSID); return false; }

    // Initialize a security descriptor
    PSECURITY_DESCRIPTOR pSD = (PSECURITY_DESCRIPTOR)LocalAlloc(LPTR, SECURITY_DESCRIPTOR_MIN_LENGTH);
    if (NULL == pSD) { FreeSid(pUsersSID); LocalFree(pACL); return false; }

    if (!InitializeSecurityDescriptor(pSD, SECURITY_DESCRIPTOR_REVISION))
      { FreeSid(pUsersSID); LocalFree(pACL); LocalFree(pSD); return false; }

    // Add the ACL to the security descriptor
    if (!SetSecurityDescriptorDacl(pSD, TRUE, pACL, FALSE))
      { FreeSid(pUsersSID); LocalFree(pACL); LocalFree(pSD); return false; }

    // Change the security attributes
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.lpSecurityDescriptor = pSD;
    sa.bInheritHandle = FALSE;

    if (!SetFileSecurityW(fileName.c_str(), DACL_SECURITY_INFORMATION, pSD))
      { FreeSid(pUsersSID); LocalFree(pACL); LocalFree(pSD); return false; }
    else { FreeSid(pUsersSID); LocalFree(pACL); LocalFree(pSD); return true; }
  }

  std::unique_ptr<boost::process::child> run_as(std::pair<std::wstring, std::wstring> user, std::wstring program)
  {
    auto password = L"";

    // Initialize the STARTUPINFO structure
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;

    // Create the process as the specified user
    BOOL result = CreateProcessWithLogonW
    (
      user.second.c_str(), user.first.c_str(), password, LOGON_WITH_PROFILE, program.c_str(), NULL, // args
      CREATE_UNICODE_ENVIRONMENT, NULL, NULL, &si, &pi
    );
    if (!result) return {};
    else return new boost::process::child(boost::process::detail::windows::child_handle(pi.hProcess, true));
  }
}
