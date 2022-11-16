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
    <#
    .SYNOPSIS
        Returns all of the Powershell script files ("*.ps1") in the CondaEnvironment.Directory.
    .EXAMPLE
        Get-CondaEnvironments | ForEach-Object { $_.GetPowershellFiles() } | Select-Object -Property FullName

        FullName
        --------
        C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\Lib\venv\scripts\common\Activate.ps1
        C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\Lib\venv\scripts\common\Activate.ps1
        C:\Users\JacobsJ\AppData\Local\ESRI\conda\envs\ogr-test\etc\conda\activate.d\gdal-activate.ps1
        C:\Users\JacobsJ\AppData\Local\ESRI\conda\envs\ogr-test\etc\conda\deactivate.d\gdal-deactivate.ps1
        C:\Users\JacobsJ\AppData\Local\ESRI\conda\envs\ogr-test\Lib\venv\scripts\common\Activate.ps1
    #>
    [IEnumerable[FileInfo]] GetPowershellFiles() {
        return $this.Directory.EnumerateFiles("*.ps1", [SearchOption]::AllDirectories);
    }
}

<#
.SYNOPSIS
    Locates the "conda" command.
.DESCRIPTION
    Tries to locate the conda command first with `Get-Command("conda")`,
    then searches recursively via Get-ChildItem in the "$env:ProgramFiles\ArcGIS" directory.
.EXAMPLE
    Get-CondaCommand

    CommandType     Name                                               Version    Source
    -----------     ----                                               -------    ------
    Application     conda.exe                                          0.0.0.0    C:\Program Files\ArcGIS\Pro\bin\Python\Scripts\conda.exe
    
#>
function Get-CondaCommand {
    # Try to get the conda command from directories in $env:Path
    # If not found, $condaCommand will be $null.
    # Otherwise the variable will contain the path to
    # the executable "conda" file.
    $condaCommand = Get-Command("conda") -ErrorAction Continue

    # Return the command if it was found.
    if ($null -cne $condaCommand) {
        return $condaCommand
    }

    [DirectoryInfo[]]$possiblePaths = 
      ("$env:ProgramFiles\ArcGIS\Pro\bin\Python\Scripts",
    "$env:ProgramFiles\ArcGIS\Server\framework\runtime\ArcGIS\bin\Python\Scripts")

    # $getChildItemSearchPath = "$env:ProgramFiles\**\conda.*"
    

    Write-Information "Could not find the ""Conda"" file in the directories specified in the PATH environment variable."

    # Loop through all the files in the "Program Files" directory and return the first match.
    $activity = "Searching for conda command in $getChildItemSearchPath"
    Write-Progress -Activity $activity
    
    # Define parameters for Get-ChildItem. See `Get-Help about_Splatting` for details.
    $getChildItemsParams = @{
        Path        = "$env:ProgramFiles\ArcGIS"
        File        = $true
        Recurse     = $true
        Include     = "conda.*"
        Depth       = 7
        ErrorAction = "SilentlyContinue"
    }
    
    foreach ($file in Get-ChildItem @getChildItemsParams) {
        Remove-Variable getChildItemSearchPath
        return $file
    }
    Write-Progress -Completed

    # If the conda command still hasn't been found, throw an exception.
    throw [FileNotFoundException]::new("Could not find a Conda executable.")
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
    arcgispro-py3         C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3     True
    ogr-test              C:\Users\YourUserName\AppData\Local\ESRI\conda\envs\ogr-test  False

.EXAMPLE
    Get-CondaEnvironments | Sort-Object -Property IsDefault

    Name                  Directory                                                 IsDefault
    ----                  ---------                                                 ---------
    base                  C:\Program Files\ArcGIS\Pro\bin\Python                        False
    ogr-test              C:\Users\YourUserName\AppData\Local\ESRI\conda\envs\ogr-test  False
    arcgispro-py3         C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3     True

.EXAMPLE
    Get-CondaEnvironments | Sort-Object -Property IsDefault -Descending
    Name                  Directory                                                 IsDefault
    ----                  ---------                                                 ---------
    arcgispro-py3         C:\Program Files\ArcGIS\Pro\bin\Python\envs\arcgispro-py3     True
    base                  C:\Program Files\ArcGIS\Pro\bin\Python                        False
    ogr-test              C:\Users\YourUserName\AppData\Local\ESRI\conda\envs\ogr-test  False
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

            $condaEnv = New-Object CondaEnvironment $name, $path, $isDefault
            

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
