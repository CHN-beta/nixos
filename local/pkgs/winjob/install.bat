REM run as admin
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/c cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

REM copy files
if not exist "C:\Program Files\winjob" mkdir "C:\Program Files\winjob"
copy winjob.exe "C:\Program Files\winjob\winjob.exe"
copy winjobd.exe "C:\Program Files\winjob\winjobd.exe"

REM create task scheduler
schtasks /create /tn "winjob" /tr "C:\Program Files\winjob\winjobd.exe" /sc onstart /ru system /f

pause
