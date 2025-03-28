#set download URL and file path for scribe msi
$downloadUrl = "colony-labs-public.s3.us-east-2.amazonaws.com/Scribe_5.3.24.msi"
$downloadPath = "C:\Temp\Scribe_5.3.24.msi"

# create temp folder if it doesnt exist
if (-not (Test-Path -Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp"
}

#download and install scribe 
Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
Start-Process msiexec.exe -ArgumentList "/i `"$downloadPath`" /qn" -Wait