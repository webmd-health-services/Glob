
function Publish-WhiskeyPesterTestResult
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The path to the Pester test resut.
        $Path
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( -not (Test-Path -Path 'env:APPVEYOR_JOB_ID') )
    {
        return
    }

    $webClient = New-Object 'Net.WebClient'
    [uri]$uploadUri = 'https://ci.appveyor.com/api/testresults/nunit/{0}' -f $env:APPVEYOR_JOB_ID
    Resolve-Path -Path $Path -ErrorAction Stop |
        Select-Object -ExpandProperty 'ProviderPath' |
        ForEach-Object { 
            $resultPath = $_
            Write-Verbose -Message ('Uploading Pester test result file "{0}" to AppVeyor at "{1}".' -f $resultPath,$uploadUri)
            # PowerShell Core can't find the UploadFile method, so we have to use refelction.
            $webClient.UploadFile($uploadUri,$resultPath)
        }
}