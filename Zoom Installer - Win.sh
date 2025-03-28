#set download URL and file path for zoom msi
$downloadUrl = "https://zoom.us/client/latest/ZoomInstallerFull.msi"
$downloadPath = "C:\Temp\ZoomInstallerFull.msi"

# create temp folder if it doesnt exist
if (-not (Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp"
}

#download and install zoom 
Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
Start-Process msiexec.exe -ArgumentList "/i `"$downloadPath`" /qn" -Wait
