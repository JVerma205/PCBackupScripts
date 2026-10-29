@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0config.bat"

echo.
set /p "source_dir=Enter source folder path: "
set "source_dir=%source_dir:"=%"
if not exist "%source_dir%\" (
	echo.
	echo Error: The source folder does not exist.
	pause
	exit /b 1
)

set /p "destination_dir=Enter destination folder path: "
set "destination_dir=%destination_dir:"=%"
if not defined destination_dir (
	echo.
	echo Error: The destination folder path cannot be empty.
	pause
	exit /b 1
)

for %%I in ("%source_dir%") do set "source_full=%%~fI"
for %%I in ("%destination_dir%") do set "destination_full=%%~fI"
if /i "%source_full%"=="%destination_full%" (
	echo.
	echo Error: Source and destination folders must be different.
	pause
	exit /b 1
)

echo.
echo Select Mode:
echo [1] SIMULATION MODE (Log excluded folders without copying)
echo [2] COPY MODE (Copy all content except excluded folders)
set /p "mode_choice=Enter choice (1 or 2): "
if "%mode_choice%"=="1" (
	set "sim_flag=True"
) else if "%mode_choice%"=="2" (
	set "sim_flag=False"
) else (
	echo.
	echo Error: Enter 1 for Simulation Mode or 2 for Copy Mode.
	pause
	exit /b 1
)
set "sim_mode=%sim_flag%"
set "user_dir=%source_dir%"
set "log_suffix=_copy_backup_log"
call "%~dp0common.bat" :LogFileSetup "%log_suffix%"
call "%~dp0common.bat" :CSVHeaderSetup

set "excluded_list_file=%temp%\backup_excluded_!RANDOM!.tmp"
if exist "%excluded_list_file%" del "%excluded_list_file%"
echo.
echo Searching for excluded folders in: "%source_dir%"...
call :ScanDirectory "%source_dir%"

if exist "%excluded_list_file%" (
	for /f "delims=" %%D in ('type "%excluded_list_file%"') do (
		call "%~dp0common.bat" :writeRowToLogFile "%%D" NoPromptRename True
	)
)

set "robocopy_excludes="
if exist "%excluded_list_file%" (
	for /f "usebackq delims=" %%D in ("%excluded_list_file%") do (
		set "robocopy_excludes=!robocopy_excludes! "%%D""
	)
)

if "%sim_flag%"=="False" (
	echo.
	echo Copying from "%source_dir%" to "%destination_dir%"...
	robocopy "%source_dir%" "%destination_dir%" /E /XD !robocopy_excludes! "%destination_full%" /COPY:DAT /DCOPY:DAT /R:2 /W:2
	set "copy_exit_code=!errorlevel!"
	if !copy_exit_code! geq 8 (
		set "error_folder=%source_dir%"
		set "error_file_path=%destination_dir%"
		set "error_detail=Robocopy failed with exit code !copy_exit_code!."
		call "%~dp0common.bat" :LogError
		echo Copy failed with Robocopy exit code !copy_exit_code!.
		if exist "%excluded_list_file%" del "%excluded_list_file%"
		pause
		exit /b !copy_exit_code!
	)
	echo Copy completed successfully.
) else (
	echo.
	echo Simulation complete. No files were copied.
)

if exist "%excluded_list_file%" del "%excluded_list_file%"
echo.
echo Log saved to: "%log_file%"
pause
exit /b 0

:ScanDirectory
for /d %%D in ("%~1\*") do (
	set "candidate_name=%%~nxD"
	echo Searching: "%%D"
	set "is_excluded=0"
	for %%N in (!excluded_folders!) do (
		if /i "!candidate_name!"=="%%N" set "is_excluded=1"
	)
    if /i "!candidate_name:~0,4!"=="arch" set "is_excluded=1"

	if "!is_excluded!"=="1" (
		echo Excluded folder found: "%%D"
		echo %%D>> "%excluded_list_file%"
	) else (
		call :ScanDirectory "%%~fD"
	)
)
exit /b 0
