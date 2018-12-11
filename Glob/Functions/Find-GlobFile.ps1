
function Find-GlobFile
{
    <#
    .SYNOPSIS
    Searches for files using advanced wildcard/glob syntax.

    .DESCRIPTION
    The `Find-GlobFile` function searches directories for files using `*` and `**` wildcard/glob patterns. Pass the top-level directories to search to the `Path` parameter. Only files under these directories will be returned. By default, all files are returned (i.e. the function uses `**/*` as the pattern). 

    Pass glob/wildcard patterns to the `Include` pattern. Only files that match that pattern will be included. To exclude files, pass glob/wildcard patterns to the `Exclude` parameter.

    The `*` pattern matches zero or more characters in a file/directory name, excluding directory separator characters. The `**` pattern matches zero more characters, including directory separator characters.
 
    These patterns will match exact directory and file name:

    * `one.txt`: just the file `one.txt` in the top-level directory.
    * `dir/two.txt`: just the file `two.txt` in the `dir` directory in the top-level directory.

    These patterns will match zero or more characters in a file and directory name in/from the top-level directory:

    * `*.txt`: all files with .txt file extension
    * `*.*`: all files with an extension
    * `*`: all files in top level directory
    * `.*`: filenames beginning with `.`
    * `readme.*`: all files named `readme` with any file extension
    * `styles/*.css`: all files with extension `.css` in the directory `styles/`
    * `scripts/*/*`: all files in `scripts/` or one level of subdirectory under `scripts/`
    * `images*/*`: all files in a folder with name that is or begins with `images`

    These patterns will match files recursively, at any arbitrary directory depth:

    * `**/*`: all files in any subdirectory
    * `dir/**/*`: all files in any subdirectory under `dir/`

    By default, the search is case-insensitive. To peform a case-sensitive search, pass the appropriate [StringComparison](https://docs.microsoft.com/en-us/dotnet/api/system.stringcomparison) value to the `StringComparison` parameter.

    The `Find-GlobFile` function uses Microsoft's [File System Globbing](https://www.nuget.org/packages/Microsoft.Extensions.FileSystemGlobbing/2.2.0) library.

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
    Find-GlobFile -Path '.' -Include 'Find-GlobFile.ps1' -StringComparison Ordinal

    Demonstrates how to do a case-sensitive search.
    #>
    [CmdletBinding()]
    [Output([IO.FileInfo])]
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

        [StringComparison]
        # By default, the search is case-insensitive. To perform a case-sensitive search, pass the appropriate [StringComparison](https://docs.microsoft.com/en-us/dotnet/api/system.stringcomparison). Usually, this is `[StringComparison]::Ordinal`.
        $StringComparison
    )

    Set-StrictMode -Version 'Latest'

    $ctorArgs = @()
    if( $StringComparison )
    {
        $ctorArgs = @( $StringComparison )
    }

    $matcher = New-Object 'Microsoft.Extensions.FileSystemGlobbing.Matcher' $ctorArgs

    foreach( $item in $Include )
    {
        [void]$matcher.AddInclude($item)
    }

    foreach( $item in $Exclude )
    {
        [void]$matcher.AddExclude($item)
    }

    foreach( $rootPath in $Path )
    {
        $rootPath = Resolve-Path -Path $rootPath | Select-Object -ExpandProperty 'ProviderPath'
        if( -not $rootPath )
        {
            continue
        }

        $directoryInfo = Get-Item -Path $rootPath
        $fsgDirectoryInfo = New-Object 'Microsoft.Extensions.FileSystemGlobbing.Abstractions.DirectoryInfoWrapper' $directoryInfo
        $result = $matcher.Execute($fsgDirectoryInfo)
        $result.Files | Select-Object -ExpandProperty 'Path' | ForEach-Object { Join-Path -Path $rootPath -ChildPath $_ } | Get-Item
    }
}
