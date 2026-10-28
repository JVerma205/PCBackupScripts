@echo off
if /i not "%~1"==":LogError" exit /b 0
goto :LogError

:LogError
>>"%error_file%" echo [%date% %time%] %error_detail%
>>"%error_file%" echo Archive folder: %error_folder%
>>"%error_file%" echo File path: %error_file_path%
>>"%error_file%" echo.
exit /b 0
