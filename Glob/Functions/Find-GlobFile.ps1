
function Find-GlobFile
{
    <#
    .SYNOPSIS
    Searches for files using advanced wildcard/glob syntax.

    .DESCRIPTION
    The `Find-GlobFile` function searches directories for files using `*` and `**` wildcard/glob patterns. Pass the top-level directories to search to the `Path` parameter. Only files under these directories will be returned. By default, all files are returned (i.e. the function uses `**/*` as the pattern). 

    Pass glob/wildcard patterns to the `Include` pattern. Only files that match that pattern will be included. To exclude files, pass glob/wildcard patterns to the `Exclude` parameter. Supported patterns are:

    * `*`: matches zero or more characters in a directory or file name *except* the directory separator character
    * `**`: matches zero or more characters in a directory or file name's path, i.e. it matches the directory separator character
    * `?`: match exactly one character
    * `[abc]`: match one of the characters inside the brackets
    * `[a-z]`: matches one character from the range inside the brackets
    * `[!abc]`: matches any one character *not* inside the brackets
    * `[!a-z]`: matches one character that is *not* in the range defined in the brackets

    By default, the search is case-insensitive. To peform a case-sensitive search, use the `CaseSensitive` switch.

    By default, hidden files and directories are not searched. To include hidden files, use the `Force` switch.

    To troubleshoot which files `Find-GlobFile` is including/excluding/finding, set your `$DebugPreference` to `Continue`.  You'll see three columns of output:
    
    1. Either empty to indicate a pattern included a file, or contains an exclamation mark, "!", to indicate a file was excluded by a pattern.
    2. The pattern.
    3. The file that matched the pattern.

    Here's an example:

        DEBUG:    **/*       file.txt
        DEBUG: !  **/*.orig  file.txt.orig

    The `Find-GlobFile` function uses the [DotNet.Glob library](https://www.nuget.org/packages/DotNet.Glob).

    .EXAMPLE
    Find-GlobFile -Path 'dir1','dir2' 

    Returns all files under `dir`` and `dir2` in the current directory.

    .EXAMPLE
    Find-GlobFile -Path 'dir1' -Include '*.ps1'

    Returns all `*.ps1` files in the `dir1` directory.

    .EXAMPLE
    Find-GlobFile -Path '.' -Include '**/*.ps1'

    Returns all `*.ps1` files under the current directory and all its sub-directories.

    .EXAMPLE
    Find-GlobFile -Path '.' -Include '**/*.ps1' -Exclude '**/*.Tests.ps1'

    Returns all `*.ps1` files except files that match `*.Tests.ps1` under the current directory and all its sub-directories.

    .EXAMPLE
    Find-GlobFile -Path '.' -Include 'Find-GlobFile.ps1' -CaseSensitive

    Demonstrates how to do a case-sensitive search.

    .EXAMPLE
    Find-GlobFile -Path '.' -Include '**/*.txt' -Force

    Demonstrates how to search hidden files and directories by using the `Force`.
    #>
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        # The directories to search. Relative paths are evaluated from the current directory. 
        [String[]]$Path,

        # The files to include. By default all files in and under each directory in `Path` are returned.
        [String[]]$Include = ('**{0}*' -f [IO.Path]::DirectorySeparatorChar),

        # Any files to exclude. By default, no files are excluded. Any file that gets included that matches an exclude pattern is not returned.
        [String[]]$Exclude,

        # By default, the search is case-insensitive. To perform a case-sensitive search, use this switch.
        [switch]$CaseSensitive,

        # Include hidden files, too.
        [switch]$Force
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    function Test-GlobMatch
    {
        param(
            [object]$InputObject,

            [switch]$IsDirectory
        )

        $relativePath = Resolve-Path -LiteralPath $InputObject.FullName -Relative 
        if( $relativePath.Length -ge 2 -and `
            $relativePath[0] -eq '.' -and `
            ($relativePath[1] -eq [IO.Path]::DirectorySeparatorChar -or `
            $relativePath[1] -eq [IO.Path]::AltDirectorySeparatorChar))
        {
            # Remove the .\ or ./ at the beginning of the path, as the glob library doesn't like it.
            $relativePath = $relativePath.Substring(2)
        }
        
        $result = ' '
        $whatMatched = ''
        $showMessage = -not $IsDirectory
        try
        {
            if( -not $IsDirectory )
            {
                $matches = $false
                foreach( $includeGlob in $includeGlobs )
                {
                    if( $includeGlob.IsMatch($relativePath) )
                    {
                        $whatMatched = $includeGlob
                        $matches = $true
                        break
                    }
                }

                if( -not $matches )
                {
                    return $false
                }
            }

            $matches = $true
            foreach( $excludeGlob in $excludeGlobs )
            {
                if( $excludeGlob.IsMatch($relativePath) )
                {
                    $showMessage = $true
                    $result = '!'
                    $whatMatched = $excludeGlob
                    $matches = $false
                    break
                }
            }

            return $matches
        }
        finally
        {
            if( $showMessage )
            {
                Write-Debug ($outputFormat -f $result, $whatMatched, $relativePath)
            }
        }
    }

    function Find-GlobFileMatch
    {
        param(
            [object[]]$Item
        )

        foreach( $info in (Get-ChildItem -LiteralPath $Item.FullName -Force:$Force) )
        {
            # Recurse into directories that aren't exluded.
            if( $info.PSIsContainer )
            {
                if( -not (Test-GlobMatch $info -IsDirectory) )
                {
                    continue
                }

                Find-GlobFileMatch $info
                continue
            }

            if( (Test-GlobMatch $info) )
            {
                Write-Output $info
            }
        }
    }

    $stats = 
        & {
            $Include
            $Exclude
        } |
        Where-Object { $_ } |
        Measure-Object -Property 'Length' -Maximum

    $outputFormat = '{{0}}  {{1,-{0}}}  {{2}}' -f $stats.Maximum
    foreach( $rootPath in $Path )
    {
        $rootPath = Resolve-Path -Path $rootPath | Select-Object -ExpandProperty 'ProviderPath'
        if( -not $rootPath )
        {
            continue
        }

        $options = New-Object 'DotNet.Globbing.GlobOptions'
        $options.Evaluation.CaseInsensitive = -not $CaseSensitive

        function ConvertTo-Glob
        {
            param(
                [Parameter(Mandatory,ValueFromPipeline)]
                [String]$InputObject
            )

            process
            {
                return [DotNet.Globbing.Glob]::Parse($InputObject,$options) 
            }
        }

        $includeGlobs = $Include | Where-Object { $_ } | ConvertTo-Glob
        $excludeGlobs = $Exclude | Where-Object { $_ } | ConvertTo-Glob

        Push-Location -Path $rootPath
        try
        {
            Find-GlobFileMatch -Item (Get-Item -Path $rootPath)
        }
        finally
        {
            Pop-Location
        }
    }
}
