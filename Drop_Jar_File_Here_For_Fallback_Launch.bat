@echo off

rem This file is a workaround for broken file name associations on Windows 10
rem and later.  If the ".jar" extension is being associated with Java, Windows
rem no longer permits the user to specify that "-jar" needs to be added after
rem the executable but before the file argument, resulting in an incorrect
rem command string:
rem     C:\some\path\to\java.exe  C:\another\path\to\EW.jar
rem
rem Instead, have the user drop the .jar onto this batch file, which will try
rem to determined the java.exe path before launching:
rem     C:\some\path\to\java.exe  -jar  C:\another\path\to\EW.jar
rem
rem Be aware that ANY PATHNAME CONTAINING SPACES is likely to break, due to
rem wildly inconsistent quoting under different versions of Windows.  As of
rem Windows 10 in mid-2020, we have mostly given up trying to guess how the
rem CMD.EXE interpreter parses/removes the quotes.  (We cannot use PowerShell
rem because that interpreter is often prohibited from running for unprivileged
rem accounts in DoD environments.)
rem
rem We'll also turn off ANSI highlighting in EW logging because the Windows
rem console can't do that safely and the user will be staring at a bunch of
rem noise for a while.


rem I'll be the first to admit that most of this batch file was cribbed from
rem various public example websites, because DOS-era scripting is borderline
rem inscrutable on a good day.

rem Standard boilerplate to not trash other process' environment tables.
if "%OS%" == "WINNT" @setlocal
if "%OS%" == "Windows_NT" @setlocal
setlocal enableextensions

rem If we really, really need a user to override things, here're some hooks.
set _JVM_ARGS=
set _EW_ARGS=

rem there should be exactly one argument, namely the JAR file
if ""%1"" == """" goto badArg
set "_EWJAR=%~1"
rem XXX test whether it's actually a jar file they dropped?  Good luck
rem getting that syntax right...

rem The rules that Apache Ant seems to follow for finding a Java launcher are
rem more or less these, stopping as soon as a file is found:
rem   (1) use the JAVACMD var if it's set
rem   (2) ?? ...not really sure what else Ant might check for here...
rem   (3) use the deprecated JAVA_HOME if it's set
rem   (4) trust the current PATH to have a Java launcher
rem This approach seems to work so we'll follow their lead.  Note that (4) is
rem very likely to use the exe junction-hardlinked from ProgramData, which for
rem the 9.x (and 10.x?) series will cause missing java.dll errors due to bugs
rem like JDK-8189427 and JDK-8162456.  Case (4) is likely to be the majority
rem of the userbase, especially the AFNET SDC in 2020.
rem
rem We preempt it all with
rem   (0) use the AFRL_EW_JAVACMD var if it's set
rem if they need to be very narrow in scope when overriding.  EW 3.5.10 and
rem later will use that variable itself, so it will take effect even when this
rem batch file is never used.
rem
rem DO NOT USE javaw.exe FOR THIS PURPOSE, it breaks when started from a batch
rem because its purpose is to suppress the console window.
rem
rem set JAVACMD=C:\Java\x64\jdk-11.0.1\bin\java.exe useful for testing downstairs
set "_JAVACMD=%AFRL_EW_JAVACMD%"
if ""%_JAVACMD%"" == """" set "_JAVACMD=%JAVACMD%"

rem This reads like assembly code, but is maximally portable (for MS-DOS files)
if ""%JAVA_HOME%"" == """" goto noJavaHome
if not exist "%JAVA_HOME%\bin\java.exe" goto noJavaHome
if ""%_JAVACMD%"" == """" set _JAVACMD=%JAVA_HOME%\bin\java.exe
:noJavaHome

rem If nothing by now, scan the PATH
if ""%_JAVACMD%"" == """" (
    rem Ideally we could use javaw.exe for this.  Pity.
    where /q java.exe || goto badExe
    set _JAVACMD=java.exe
)
goto haveJavaCmd

:badExe
echo.
echo No Java launcher executable (java.exe) was found in your PATH.  Make
echo certain Java SE is installed.  If the JAR file still does not run on
echo its own and this batch file still cannot find the Java launcher, then
echo either adjust the PATH accordingly, or set the AFRL_EW_JAVACMD environment
echo variable to the full launcher location, including the .exe file.
echo.
echo.
echo.
pause
goto end

:badArg
echo.
echo If double-clicking the Encryption Wizard JAR file does not launch the
echo software on your system, then it is likely that the Windows install of
echo Java has some misconfigured file associations and should be reinstalled.
echo.
echo In the meantime, Encryption Wizard may be launched by dragging the EW
echo JAR file and dropping it onto this batch file.
echo.
echo.
echo.
pause
goto end

:haveJavaCmd
rem Cannot actually capture the return code reliably in CMD.EXE, only the
rem fact of a zero versus non-zero exit, because ERRORLEVEL is so wonked
rem between Windows versions.  Thus this batch file itself always exits with
rem a zero, because variables set here expire at endlocal before 'exit'.
"%_JAVACMD%" %_JVM_ARGS% -jar "%_EWJAR%" "--log=b" %_EW_ARGS%
if ERRORLEVEL 1 pause

:end
rem Apparently resetting an undefined env variable hoses up the errorlevel,
rem so we need to jump through more fiery hoops simply to exit cleanly.
if not ""%_JAVACMD%"" == """" set _JAVACMD=
if not ""%_EWJAR%"" == """" set _EWJAR=
if not ""%_JVM_ARGS%"" == """" set _JVM_ARGS=
if not ""%_EW_ARGS%"" == """" set _EW_ARGS=
rem not really sure if these are needed, but they're at least harmless
if "%OS%" == "WINNT" @endlocal
if "%OS%" == "Windows_NT" @endlocal

exit /b

