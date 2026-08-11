mkdir package
robocopy "sourcemod" "package/treason/addons/sourcemod" /MIR
robocopy "include" "package/treason/addons/sourcemod/scripting/include" /MIR
robocopy "notepad++" "package/notepad++" /MIR

copy treason_api.sp "package/treason/addons/sourcemod/scripting/treason_api.sp" /Y /V
copy treason_customroles.sp "package/treason/addons/sourcemod/scripting/treason_customroles.sp" /Y /V
copy "compiled/treason_api.smx" "package/treason/addons/sourcemod/plugins/treason_api.smx" /Y /V

pause