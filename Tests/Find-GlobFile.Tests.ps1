
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Glob' -Resolve) -Force

$result = $null

function GivenFile
{
    param(
        [string[]]
        $Path
    )

    foreach( $pathItem in $Path )
    {
        $fullPath = Join-Path -Path $TestDrive.FullName -ChildPath $pathItem

        $parentDir = $fullPath | Split-Path
        if( -not (Test-Path -Path $parentDir -PathType Container) )
        {
            New-Item -Path $parentDir -ItemType 'Directory'
        }

        if( -not (Test-Path -Path $fullPath -PathType Leaf) )
        {
            New-Item -Path $fullPath -ItemType 'File'
        }
    }
}

function Init
{
    $script:result = $null
}

function ThenFound
{
    param(
        $Path
    )

    It ('should find files') {
        foreach( $pathItem in $Path )
        {
            $fullPath = Join-Path -Path $TestDrive.FullName -ChildPath $pathItem
            ($result | Select-Object -ExpandProperty 'FullName') | Should -Contain $fullPath
        }
    }
}

function ThenNotFound
{
    param(
        $Path
    )

    It ('should not find files') {
        foreach( $pathItem in $Path )
        {
            $fullPath = Join-Path -Path $TestDrive.FullName -ChildPath $pathItem
            ($result | Select-Object -ExpandProperty 'FullName') | Should -Not -Contain $fullPath
        }
    }
}

function WhenFinding
{
    param(
        $In = $TestDrive.FullName,

        $Including,

        $Excluding,

        [Switch]
        $CaseSensitive
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

    Push-Location $TestDrive.FullName
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
    Init
    GivenFile 'fubar', 'snafu.txt'
    WhenFinding -Including '*.txt'
    ThenFound 'snafu.txt'
    ThenNotFound 'fubar'
}

Describe 'Find-GlobFile.when excluding' {
    Init
    GivenFile 'fubar.pdf', 'snafu.txt'
    WhenFinding -Excluding '*.txt'
    ThenFound 'fubar.pdf'
    ThenNotFound 'snafu.txt'
}

Describe 'Find-GlobFile.when rooting include pattern with ''/''' {
    Init
    GivenFile 'fubar.txt', 'dir1/snafu.txt'
    WhenFinding -Including '*/*.txt'
    ThenFound 'dir1/snafu.txt'
    ThenNotFound 'fubar.txt'
}

Describe 'Find-GlobFile.when searching multiple directoryes and rooting without ''/'' and include contains directory that matches in multiple directories (make sure matcher matches from the root not anywhere)' {
    Init
    GivenFile 'dir1/sub/fubar.txt', 'dir2/parent/sub/snafu.txt'
    WhenFinding -In 'dir1','dir2' -Including 'sub/*.txt'
    ThenFound 'dir1/sub/fubar.txt'
    ThenNotFound 'dir2/parent/sub/snafu.txt'
}

Describe 'Find-GlobFile.when searching multiple directoryes and rooted with ''**''' {
    Init
    GivenFile 'dir1/sub/fubar.txt', 'dir2/parent/sub/snafu.txt'
    WhenFinding -In 'dir1','dir2' -Including '**/sub/*.txt'
    ThenFound 'dir1/sub/fubar.txt','dir2/parent/sub/snafu.txt'
}

Describe 'Find-GlobFile.when no include is used' {
    Init
    GivenFile 'file.txt','dir1/fubar.txt'
    WhenFinding 
    ThenFound 'file.txt','dir1/fubar.txt'
}

Describe 'Find-GlobFile.when using default string comparison' {
    Init
    GivenFile 'file.txt','dir1/FILE.txt'
    WhenFinding -Including '**/file.txt' 
    ThenFound 'file.txt','dir1/FILE.txt'
}

Describe 'Find-GlobFile.when using case-sensitive string comparison' {
    Init
    GivenFile 'file.txt','dir1/FILE.txt'
    WhenFinding -Including '**/file.txt' -CaseSensitive
    ThenFound 'file.txt'
    ThenNotFound 'dir1/FILE.txt'
}

Describe 'Find-GlobFile.when excluding something found by include' {
    Init
    GivenFile 'file.txt','dir1/file.txt'
    WhenFinding -Including '**/file.txt' -Excluding 'file.txt'
    ThenFound 'dir1/file.txt'
    ThenNotFound 'file.txt'
}

Describe 'Find-GlobFile.when using ? in pattern' {
    Init
    GivenFile 'file.txt','pile.txt','tile.txt'
    WhenFinding -Including '?ile.txt'
    ThenFound 'file.txt','pile.txt','tile.txt'
}

Describe 'Find-GlobFile.when using [] in pattern' {
    Init
    GivenFile 'file.txt','pile.txt','tile.txt'
    WhenFinding -Including '[fp]ile.txt'
    ThenFound 'file.txt','pile.txt'
    ThenNotFound 'tile.txt'
}
