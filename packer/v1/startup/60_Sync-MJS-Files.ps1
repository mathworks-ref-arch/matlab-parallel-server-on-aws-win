# Copyright 2022-2023 The MathWorks, Inc.

If (-not (Test-Path $Env:SecurityRoot)) {
    New-Item -Path $Env:SecurityRoot -ItemType Directory
}

# Create shared secret file and set MATLAB client verification
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html
If ($Env:NodeType -eq 'headnode') {

    Set-Location "$Env:MATLABRoot\toolbox\parallel\bin"

    If ( -not (Test-Path $Env:SecretFile) -or -not (Test-Path $Env:CertFile) ) {
        Write-Output '===Creating secret and certificate==='
        .\createSharedSecret.bat -file $Env:SecretFile
        .\generateCertificate.bat -secretfile $Env:SecretFile -certfile $Env:CertFile
    } Else {
        Write-Output '===Using existing secret and certificate==='
    }

    Write-Output '===Creating profile==='
    $WinTemp = [System.Environment]::GetEnvironmentVariable('TEMP','Machine')
    $MJSHostname = $Env:PublicHostname
    $ProfileFile = "$WinTemp\$Env:JobManagerName.mlsettings"
    .\createProfile.bat -name "$Env:JobManagerName" -host $MJSHostname -certfile $Env:CertFile -outfile "$ProfileFile"

    Write-Output '===Uploading files to S3 bucket==='
    # Wait for S3 bucket to appear.
    $TimeoutSeconds = 60
    $StartTime = Get-Date
    While (-not $(aws s3 ls $Env:S3Bucket; $?)) {
        Start-Sleep -Seconds 1
        If (((Get-Date) - $StartTime).TotalSeconds -gt $TimeoutSeconds) {
            Write-Output "The S3 bucket $Env:S3Bucket was not available within $TimeoutSeconds seconds."
            Exit 1
        }
    }

    aws s3 cp --sse AES256 $Env:SecretFile $Env:S3Bucket
    aws s3 cp "$ProfileFile" $Env:S3Bucket

    # Upload default admin password if present
    If (Test-Path $Env:MJSAdminPasswordFile) {
        aws s3 cp --sse AES256 $Env:MJSAdminPasswordFile $Env:S3Bucket
    }

} Else {

    Write-Output '===Retrieving secret from S3 bucket==='
    # Wait for up to 10 minutes for the shared secret
    # to appear before giving up.
    $TimeoutSeconds = 600
    $StartTime = Get-Date
    While (-not $(aws s3 ls $Env:S3Bucket/secret; $?)) {
        Start-Sleep -Seconds 1
        If (((Get-Date) - $StartTime).TotalSeconds -gt $TimeoutSeconds) {
            Write-Output "The shared secret was not found in $Env:S3Bucket within $TimeoutSeconds seconds."
            Exit 1
        }
    }

    aws s3 cp --sse AES256 $Env:S3Bucket/secret $Env:SecretFile

}
