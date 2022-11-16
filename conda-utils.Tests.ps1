<#
.SYNOPSIS
    This is a Pester test for the conda-utils module
.EXAMPLE
    Invoke-Pester

    Starting discovery in 1 files.d
    Discovery found 1 tests in 23ms.
    Running tests.
    [+] C:\Users\YourUserName\source\repos\PowerShell\conda-utils\conda-utils.Tests.ps1 1.89s (1.83s|39ms)
    Tests completed in 1.89s
    Tests Passed: 1, Failed: 0, Skipped: 0 NotRun: 0
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

BeforeAll {
    # Test to see if the module has already been loaded.
    $wasAlreadyLoaded = Get-Command Get-CondaEnvironments -ErrorAction SilentlyContinue -ne $null
    # Get the name of the module by getting this file's name and replacing the ".Tests.ps1" with ".psm1"
    $moduleName = $PSCommandPath.Replace('.Tests.ps1', '.psm1')
    # Re-import the module using the -Force parameter in case the module file 
    # has been modified since it was imported.
    Import-Module $moduleName -Force
}

AfterAll {
    # If the module wasn't already loaded when the test started,
    # unload it now.
    if (-not $wasAlreadyLoaded) {
        Remove-Module conda-utils
    }
}

Describe "conda-utils" {
    It "Returns expected output" {
        $condaEnvironments = Get-CondaEnvironments

        foreach ($env in $condaEnvironments) {
            # $env | Should -BeOfType CondaEnvironment # This only works w/ .NET types
            $env.GetType() | Should -Be "CondaEnvironment"
        }
    }
}
