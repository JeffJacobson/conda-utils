using namespace System.IO
using namespace System.Collections.Generic

# This is what the ArcGIS conda init runs, but it doesn't work correctly.
# (& "C:\Program Files\ArcGIS\Pro\bin\Python\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | Invoke-Expression


<#
.SYNOPSIS
    Represents a Conda environment.
#>
class CondaEnvironment {
    [string] $Name
    [DirectoryInfo] $Directory
    [bool] $IsDefault

    CondaEnvironment(
        [string] $name,
        [DirectoryInfo]$directory,
        [bool]$isDefault = $false
    ) {
        $this.Name = $name
        $this.Directory = $directory
        $this.IsDefault = $isDefault
    }
}

<#
.SYNOPSIS
    Lists all of the conda environments   
.DESCRIPTION
    Runs the `conda env list` command and parses the output into a hashtable.
.EXAMPLE
    Get-CondaEnvironments

    Name                  Directory                                                 IsDefault
    ----                  ---------                                                 ---------
    base                  C:\Program Files\ArcGIS\Pro\bin\Python                        False
    arcgispro-py3         C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3      True
    ogr-test              C:\Users\YourUserName\AppData\Local\ESRI\conda\envs\ogr-test       False
#>
function Get-CondaEnvironments {
    [string[]]$condaEnvList = Invoke-Expression "conda env list"

    <# $condaEnvList will look like this, one line = one string in array.
    # conda environments:
    #
    base                     C:\Program Files\ArcGIS\Pro\bin\Python
    arcgispro-py3         *  C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3
    ogr-test                 C:\Users\YourUserName\AppData\Local\ESRI\conda\envs\ogr-test
    #>

    # This regex will match a line listing an environment.
    $dataRe = [regex]"^(?<name>.+)\s{2,}(?<default>\*)?\s{2,}(?<path>.+)$";
    
    # Create new outut hash table.
    $output = [List[CondaEnvironment]]::new()

    foreach ($line in $condaEnvList) {
        $match = $dataRe.Match($line)
        if ($match.Success) {
            # $match.Captures | ForEach-Object {$_.GetType()}
            $name = $match.Groups["name"].Value
            $path = [System.IO.DirectoryInfo]$match.Groups["path"].Value
            $isDefault = $match.Groups["default"].Success

            $condaEnv = New-Object CondaEnvironment $name,$path,$isDefault
            

            $output.Add($condaEnv)
        }
    }

    return $output

    # # conda environments:
    # #
    # base                     C:\Program Files\ArcGIS\Pro\bin\Python
    # arcgispro-py3         *  C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3
    # ogr-test                 C:\Users\YourUserName\AppData\Local\ESRI\conda\envs\ogr-test
}
