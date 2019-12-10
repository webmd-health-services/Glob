
$functionDir = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'
if( (Test-Path -Path $functionDir) )
{
    foreach( $item in (Get-ChildItem -Path $functionDir -Filter '*.ps1') )
    {
        . $item.FullName
    }
}
