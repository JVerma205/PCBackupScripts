@echo off
if /i "%~1"==":LogFileSetup" goto :LogFileSetup
if /i "%~1"==":LogError" goto :LogError
exit /b 0

:LogFileSetup
set "log_suffix=%~2"
for %%I in ("%user_dir%") do set "log_base_name=%%~nxI"
if not defined log_base_name set "log_base_name=folder"
set "log_file=logs\%log_base_name%%log_suffix%.csv"
if "%sim_mode%"=="True" set "log_file=logs\%log_base_name%%log_suffix%_sim.csv"

if exist "%log_file%" (
	echo.
	echo Log file already exists: "%log_file%"
	set /p "log_choice=Append to existing log? [A]ppend or [N]ew file: "
	if /i not "!log_choice!"=="N" (
		set "log_choice=A"
	) else (
		set /p "new_log_name=Enter new log file name (for example: my_log.csv): "
		if not defined new_log_name set "new_log_name=!log_base_name!_my_log.csv"
		set "new_log_name=!new_log_name:"=!"
		echo New log file name set to: "!new_log_name!"
		if /i not "!new_log_name:~0,1!"=="\" (
			if /i not "!new_log_name:~0,1!"=="/" (
				set "log_file=logs\!new_log_name!"
			) else (
				set "log_file=!new_log_name!"
			)
		) else (
			set "log_file=!new_log_name!"
		)
		if /i not "!log_file:~-4!"==".csv" set "log_file=!log_file!.csv"
	)
)

echo Log file will be created at: "%log_file%"
for %%I in ("%log_file%") do set "log_dir=%%~dpI"
if not exist "%log_dir%" mkdir "%log_dir%" 2>nul
set "error_file=%log_dir%error.txt"
exit /b 0

:LogError
>>"%error_file%" echo [%date% %time%] %error_detail%
>>"%error_file%" echo Archive folder: %error_folder%
>>"%error_file%" echo File path: %error_file_path%
>>"%error_file%" echo.
exit /b 0
