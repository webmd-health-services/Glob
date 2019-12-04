
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
    #>
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [string[]]
        # The directories to search. Relative paths are evaluated from the current directory. 
        $Path,

        [string[]]
        # The files to include. By default all files in and under each directory in `Path` are returned.
        $Include = '**/*',

        [string[]]
        # Any files to exclude. By default, no files are excluded. Any file that gets included that matches an exclude pattern is not returned.
        $Exclude,

        [Switch]
        # By default, the search is case-insensitive. To perform a case-sensitive search, use this switch.
        $CaseSensitive
    )

    Set-StrictMode -Version 'Latest'

    foreach( $rootPath in $Path )
    {
        $rootPath = Resolve-Path -Path $rootPath | Select-Object -ExpandProperty 'ProviderPath'
        if( -not $rootPath )
        {
            continue
        }

        $options = New-Object 'DotNet.Globbing.GlobOptions'
        $options.Evaluation.CaseInsensitive = -not $CaseSensitive

        $includeGlobs = $Include | Where-Object { $_ } | ForEach-Object { [DotNet.Globbing.Glob]::Parse($_,$options) }
        $excludeGlobs = $Exclude | Where-Object { $_ } | ForEach-Object { [DotNet.Globbing.Glob]::Parse($_,$options) }

        Push-Location -Path $rootPath
        try
        {
            foreach( $fileInfo in (Get-ChildItem -Path $rootPath -File -Recurse) )
            {
                $relativePath = $fileInfo.FullName | Resolve-Path -Relative | ForEach-Object { $_ -replace '^\.(\\|//)','' }
                $matches = $false
                foreach( $includeGlob in $includeGlobs )
                {
                    if( $includeGlob.IsMatch($relativePath) )
                    {
                        $matches = $true
                        break
                    }
                }

                if( -not $matches )
                {
                    continue
                }

                foreach( $excludeGlob in $excludeGlobs )
                {
                    if( $excludeGlob.IsMatch($relativePath) )
                    {
                        $matches = $false
                        break
                    }
                }

                if( $matches )
                {
                    $fileInfo
                }
            }
        }
        finally
        {
            Pop-Location
        }
    }
}
