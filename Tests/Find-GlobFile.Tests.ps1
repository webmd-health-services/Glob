
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Glob' -Resolve) -Force
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PSModules\Carbon' -Resolve) -Force

$testRoot = $null
$result = $null

function GivenDirectory
{
    param(
        [String[]]$Path,

        [switch]$Hidden
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $testRoot -ChildPath $pathItem

        if( -not (Test-Path -Path $fullPath -PathType Container) )
        {
            New-Item -Path $fullPath -ItemType 'Directory' -Force
        }

        if( $Hidden )
        {
            $item = Get-Item $fullPath -Force
            $item.Attributes = $item.Attributes -bor [IO.FileAttributes]::Hidden
        }
    }
}

function GivenFile
{
    param(
        [String[]]$Path,

        [switch]$Hidden
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $testRoot -ChildPath $pathItem

        $parentDir = $fullPath | Split-Path
        if( -not (Test-Path -Path $parentDir -PathType Container) )
        {
            New-Item -Path $parentDir -ItemType 'Directory'
        }

        if( -not (Test-Path -Path $fullPath -PathType Leaf) )
        {
            New-Item -Path $fullPath -ItemType 'File' -Force
        }

        if( $Hidden )
        {
            $item = Get-Item $fullPath -Force
            $item.Attributes = $item.Attributes -bor [IO.FileAttributes]::Hidden
        }
    }
}

function Init
{
    $Global:Error.Clear()
    $script:result = $null
    $script:testRoot = Join-Path -Path $TestDrive.FullName -ChildPath ([IO.Path]::GetRandomFileName())
    New-Item -Path $testRoot -ItemType 'Directory'
}

function ThenFound
{
    param(
        $Path
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $testRoot -ChildPath $pathItem
        ($result | Select-Object -ExpandProperty 'FullName') | Should -Contain $fullPath
    }
}

function ThenNotFound
{
    param(
        $Path
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $testRoot -ChildPath $pathItem
        ($result | Select-Object -ExpandProperty 'FullName') | Should -Not -Contain $fullPath
    }
}

function WhenFinding
{
    param(
        $In = $testRoot,

        $Including,

        $Excluding,

        [switch]$CaseSensitive,

        [switch]$Force
    )

    $optionalParams = @{ }
    if( $Including )
    {
        $optionalParams['Include'] = $Including
    }

    if( $Excluding )
    {
        $optionalParams['Exclude'] = $Excluding
    }

    if( $CaseSensitive )
    {
        $optionalParams['CaseSensitive'] = $CaseSensitive
    }

    if( $Force )
    {
        $optionalParams['Force'] = $Force
    }

    Push-Location $testRoot
    try
    {
        $script:result = Find-GlobFile -Path $In @optionalParams
    }
    finally
    {
        Pop-Location
    }
}

Describe 'Find-GlobFile.when including' {
    It 'should only find files matching include filter' {
        Init
        GivenFile 'fubar', 'snafu.txt'
        WhenFinding -Including '*.txt'
        ThenFound 'snafu.txt'
        ThenNotFound 'fubar'
    }
}

Describe 'Find-GlobFile.when excluding' {
    It 'should not find files that match exclude filter' {
        Init
        GivenFile 'fubar.pdf', 'snafu.txt'
        WhenFinding -Excluding '*.txt'
        ThenFound 'fubar.pdf'
        ThenNotFound 'snafu.txt'
    }
}

Describe 'Find-GlobFile.when rooting include pattern with ''/''' {
    It 'should only find files that match include filter' {
        Init
        GivenFile 'fubar.txt', 'dir1/snafu.txt'
        WhenFinding -Including '*/*.txt'
        ThenFound 'dir1/snafu.txt'
        ThenNotFound 'fubar.txt'
    }
}

Describe 'Find-GlobFile.when searching multiple directories and rooting without ''/'' and include contains directory that matches in multiple directories' {
    It 'should matches from the root not anywhere' {
        Init
        GivenFile 'dir1/sub/fubar.txt', 'dir2/parent/sub/snafu.txt'
        WhenFinding -In 'dir1','dir2' -Including 'sub/*.txt'
        ThenFound 'dir1/sub/fubar.txt'
        ThenNotFound 'dir2/parent/sub/snafu.txt'
    }
}

Describe 'Find-GlobFile.when searching multiple directoryes and rooted with ''**''' {
    It 'should match directory separator with double asterisk' {
        Init
        GivenFile 'dir1/sub/fubar.txt', 'dir2/parent/sub/snafu.txt'
        WhenFinding -In 'dir1','dir2' -Including '**/sub/*.txt'
        ThenFound 'dir1/sub/fubar.txt','dir2/parent/sub/snafu.txt'
    }
}

Describe 'Find-GlobFile.when no include is used' {
    It 'should find all files' {
        Init
        GivenFile 'file.txt','dir1/fubar.pdf','dir2/dir3/snafu.gif'
        WhenFinding 
        ThenFound 'file.txt','dir1/fubar.pdf','dir2/dir3/snafu.gif'
    }
}

Describe 'Find-GlobFile.when using default string comparison' {
    It 'should ignore case' {
        Init
        GivenFile 'file.txt','dir1/FILE.txt'
        WhenFinding -Including '**/file.txt' 
        ThenFound 'file.txt','dir1/FILE.txt'
    }
}

Describe 'Find-GlobFile.when using case-sensitive string comparison' {
    It 'should find files that match case' {
        Init
        GivenFile 'file.txt','dir1/FILE.txt'
        WhenFinding -Including '**/file.txt' -CaseSensitive
        ThenFound 'file.txt'
        ThenNotFound 'dir1/FILE.txt'
    }
}

Describe 'Find-GlobFile.when excluding something found by include' {
    It 'should prioritize exclude higher than include' {
        Init
        GivenFile 'file.txt','dir1/file.txt'
        WhenFinding -Including '**/file.txt' -Excluding 'file.txt'
        ThenFound 'dir1/file.txt'
        ThenNotFound 'file.txt'
    }
}

Describe 'Find-GlobFile.when using ? in pattern' {
    It 'should match one character' {
        Init
        GivenFile 'file.txt','pile.txt','tile.txt'
        WhenFinding -Including '?ile.txt'
        ThenFound 'file.txt','pile.txt','tile.txt'
    }
}

Describe 'Find-GlobFile.when using [] in pattern' {
    It 'should match any character' {
        Init
        GivenFile 'file.txt','pile.txt','tile.txt'
        WhenFinding -Including '[fp]ile.txt'
        ThenFound 'file.txt','pile.txt'
        ThenNotFound 'tile.txt'
    }
}

if( -not (Test-Path -Path 'variable:IsWindows') )
{
    $IsWindows = $true
}

if( $IsWindows )
{
    Describe 'Find-GlobFile.when files are hidden' {
        It 'should not return those files' {
            Init
            GivenFile 'file.txt' -Hidden
            GivenDirectory 'hidden' -Hidden
            GivenFile 'hidden\file2.txt'
            WhenFinding -Including '**\file*'
            ThenNotFound 'file.txt','hidden\file2.txt'
        }
    }

    Describe 'Find-GlobFile.when using the force to find hidden files' {
        It 'should not return those files' {
            Init
            GivenFile 'file.txt' -Hidden
            GivenDirectory 'hidden' -Hidden
            GivenFile 'hidden\file2.txt'
            WhenFinding -Including '**\file*' -Force
            ThenFound 'file.txt','hidden\file2.txt'
        }
    }
}
else
{
    Describe 'Find-GlobFile.when files are hidden' {
        It 'should not return those files' {
            Init
            GivenFile '.file', '.hidden\file2.txt'
            WhenFinding -Including '**\file*'
            ThenNotFound '.file','.hidden\file2.txt'
        }
    }

    Describe 'Find-GlobFile.when using the force to find hidden files' {
        It 'should not return those files' {
            Init
            GivenFile '.file','.hidden\file2.txt'
            WhenFinding -Including '**\file*' -Force
            ThenFound '.file','.hidden\file2.txt'
        }
    }
}

if( $IsWindows )
{
    Describe 'Find-GlobFile.when excluding a directory' {
        It 'should not recurse into excluded directories' {
            Init
            GivenFile 'file.txt','excluded\file.txt'
            # Create a circular junction. When you recurse too deeply, eventually PowerShell throws an error that you've
            # gone too deep. If it got excluded properly, there won't be an error.
            New-CJunction -Link (Join-Path -Path $testRoot -ChildPath 'excluded\circular') `
                          -Target (Join-Path -Path $testRoot -ChildPath 'excluded')
            WhenFinding -Including '**/file.txt' -Excluding '**/excluded/**'
            ThenFound 'file.txt'
            $Global:Error | Should -BeNullOrEmpty
        }
    }
}

# Only really works on Windows. The *.sys files in the root of the system drive are read-able by `Get-ChildItem -Force`,
# but no by `Resolve-Path`. Handle this special situation.
Describe 'Find-GlobFile.when user requests system files they do not have access to' {
    It 'should ignore those files and not write any errors' {
        Init
        $rootPath = Resolve-Path -Path ([IO.Path]::DirectorySeparatorChar)
        $exclude = Get-ChildItem -Path $rootPath -Directory -Force | ForEach-Object { '**/{0}/**' -f $_.Name }
        $files = Get-ChildItem -Path $rootPath -File
        $numExpectedErrors = 
            Get-ChildItem -Path $rootPath -Force -File | 
            Where-Object { -not ($_ | Resolve-Path -ErrorAction Ignore) } |
            Measure-Object |
            Select-Object -ExpandProperty 'Count'
        $include = $files | Select-Object -ExpandProperty 'Name'
        $result = Find-GlobFile -Path $rootPath -Include $include -Exclude $exclude -Force -ErrorAction SilentlyContinue
        $Global:Error | Should -HaveCount $numExpectedErrors
        $expectedFiles = $files | Select-Object -ExpandProperty 'FullName' | Sort-Object
        $result | Select-Object -ExpandProperty 'FullName' | Sort-Object | Should -Be $expectedFiles
    }
}

# Only really works on Windows. The *.sys files in the root of the system drive are read-able by `Get-ChildItem -Force`,
# but no by `Resolve-Path`. Use this situation to make sure Resolve-Path doesn't fail incorrectly when error action is
# ignore.
Describe 'Find-GlobFile.when ignoring errors' {
    It 'should not write any errors' {
        Init
        $rootPath = Resolve-Path -Path ([IO.Path]::DirectorySeparatorChar)
        $exclude = Get-ChildItem -Path $rootPath -Directory -Force | ForEach-Object { '**/{0}/**' -f $_.Name }
        $files = Get-ChildItem -Path $rootPath -File
        $include = $files | Select-Object -ExpandProperty 'Name'
        $result = Find-GlobFile -Path $rootPath -Include $include -Exclude $exclude -Force -ErrorAction Ignore
        $Global:Error | Should -BeNullOrEmpty
        $expectedFiles = $files | Select-Object -ExpandProperty 'FullName'
        $result | Select-Object -ExpandProperty 'FullName' | Sort-Object | Should -Be $expectedFiles
    }
}