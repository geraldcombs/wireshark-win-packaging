Set-PSDebug -Trace 1

$obsRepository = "openSUSE_12.3"
$buildDir = "obs\gtk3"

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

# It looks like we don't really need 7-Zip:
# http://vcsjones.com/2012/11/11/unzipping-files-with-powershell-in-server-core-the-new-way/
if (Test-Path "C:\Program Files\7-Zip") {
    $env:Path = $env:Path + ";C:\Program Files\7-Zip"
}
foreach ($requiredCmd in @("7z", "gendef", "lib") ) {
    # XXX We don't exit properly here.
    try {
        Get-Command -CommandType Application $requiredCmd
    } catch {
        Write-Error "$requiredCmd is not in PATH."
        Exit 1
    }
}

$dmrPrefix = "$python $pwd\externals\download-mingw-rpm\download-mingw-rpm.py -z -m --deps -r $obsRepository"

if (! (Test-Path $buildDir)) {
    try {
        New-Item -Name $buildDir -ItemType directory
    } catch {
        Write-Error "Can't create $buildDir."
        Exit 1
    }
}

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

    Write-Host "Bundling GTK+ 3 for win$bits / $machine"
    foreach ($rpmPkg in @(
        "gtk3"
        "gtk3-devel"
        "gtk3-tools"
        "glib2-tools"
        ) ) {
        $downloadMingwRpmCmd = "$dmrPrefix -p $project $rpmPkg"
        Write-Host "Running $downloadMingwRpmCmd"
        cmd /c "$downloadMingwRpmCmd"
    }

    $pkgName = Get-Childitem . -Name -File gtk3-3*.zip | Select -first 1
    $pkgName = $pkgName.Replace(".zip", "")
    $pkgVersion = $pkgName.replace("gtk3", "")
    if ( !$pkgName -or !$pkgVersion) {
        Write-Error "Can't derive package name or version"
        exit 1
    }
    $pkgName = "$pkgName-win$bits"
    
    @"
// GTK+ 3 OBS $project package information
// DO NOT EDIT
#defines {
    obs-win${bits}-name: $pkgName;
    obs-win${bits}-version: $pkgVersion;
}
"@ | Out-File -FilePath "..\..\gtk3-win${bits}-obs-info.inc" -Encoding utf8
    
    Write-Host "Preparing $pkgName"

    New-Item -Name $pkgName -ItemType directory
    Set-Location $pkgName

    Get-Childitem ..\*.zip | foreach ($_) {
        Write-Host "Extracting $_"
        7z x -y $_
    }

    Set-Location bin
    Get-ChildItem . -File -Name "*.dll" | foreach ($_) {
        $baseName = $_.replace(".dll", "")
        $dllFile = "$_"
        $defFile = "${baseName}.def"
        $libFile = "${baseName}.lib"

        Write-Host "Generating $libFile from $dllFile."
        gendef $dllFile
        lib /machine:$machine /def:$defFile /name:$dllFile /out:$libFile
        Move-Item $libFile ..\lib\
        Move-Item $defFile ..\lib\
    }
    # gtk3-<version/>-win<bits/>
    Set-Location ..

    # obs/gtk3/$bits
    Set-Location ..

    # obs/gtk3
    Set-Location ..
}

Set-Location ..\..

Write-NuGetPackage .\gtk3-obs.autopackage