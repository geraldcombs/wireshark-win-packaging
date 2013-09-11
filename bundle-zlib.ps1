Set-PSDebug -Trace 1

$obsRepository = "openSUSE_12.3"
$buildDir = "$pwd\obs\zlib"

Write-Host -NoNewline "Looking for Python 3..."

foreach ($pv in @(33, 32, 31, 30) ) {
    if (Test-Path "C:\Python$pv\python.exe") {
        $python = "C:\Python$pv\python.exe"
    }
}

if ($python) {
    Write-Host "found $python"
} else {
    Write-Error "not found"
    Exit 1
}

foreach ($requiredCmd in @("7z", "lib") ) {
    try {
        Get-Command -CommandType Application $requiredCmd
    } catch {
        Write-Error "$requiredCmd is not in PATH."
        Exit 1
    }
}

$dmrPrefix = "$python $pwd\externals\download-mingw-rpm\download-mingw-rpm.py -z -m -r $obsRepository"

cd $buildDir

foreach ($bits in @(32, 64) ) {
    Remove-Item -Recurse -EA SilentlyContinue $bits
    New-Item -Name $bits -ItemType directory
    Set-Location $bits
    
    $project = "windows:mingw:win$bits"
    if ($bits -eq "32" ) {
        $machine = "x86"
    } else {
        $machine = "x64"
    }

    Write-Host "Bundling zlib for win$bits / $machine"
    foreach ($rpmPkg in @("zlib", "zlib-devel") ) {
        $downloadMingwRpmCmd = "$dmrPrefix -p $project $rpmPkg"
        Write-Host "Running $downloadMingwRpmCmd"
        cmd /c "$downloadMingwRpmCmd"
    }

    $pkgName = Get-Childitem . -Name -File zlib-1*.zip | Select -first 1
    $pkgName = $pkgName.Replace(".zip", "");
    $pkgName = "$pkgName-win$bits"
    Write-Host "Preparing $pkgName"

    New-Item -Name $pkgName -ItemType directory
    Set-Location $pkgName

    Get-Childitem ..\*.zip | foreach ($_) {
        Write-Host "Extracting $_"
        7z x $_
    }

    lib /machine:$machine /def:..\..\zlib.def /name:zlib1.dll /out:lib\zlib1.lib

    # obs/zlib/$bits
    Set-Location ..

    7z a -r "$pkgName.zip" "$pkgName"
    Move-Item "$pkgName.zip" ..\..

    # obs/zlib
    Set-Location ..
}
