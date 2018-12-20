<#
CHANGELOG
--------------------------------------------------------------------------------------------------------------------------------------------
10/01/2018: JNB - Created job ZL176W02.


TODO:
Add SFTP Step.
Retrieve SFTP access to ibn2m04t.iib..com
#>

#PARAMETERS
#Set accepted parameters to script
#--------------------------------------------------------------------------------------------------------------------------------------------
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False, Position=1)]
	$src="\\documents\sourcedocs\ToExport "
)

#FUNCTIONS
#Each function must be declared BEFORE they are called.
#--------------------------------------------------------------------------------------------------------------------------------------------

<#
Function: Ends current running script and sends email.
#>
function End-Script{

#Adding file list to status email if files were processed
IF ($fileSuccess){
	$attachments+=$file_list
}
#Adding error file attachments to status email
IF ($error) { 
	ECHO $error > $error_file
	$attachments+=$error_file
}
IF ($fileError){
	$attachments+=$file_error_list
}

$date=Get-Date -Format g
ECHO "`nError Code $ReturnCode Reported. Job end $date" >> $MSG
F:\ens\lib\email.ps1 -to $TO -subject $($ExecutionContext.InvokeCommand.ExpandString($SUBJECT)) -msg $MSG -attachments $attachments
exit $ReturnCode
}

#CONFIG
#--------------------------------------------------------------------------------------------------------------------------------------------
$envir="TEST"
$DTA="N/A"
$JOB="ZL176W02"
$VENDOR="VENDOR NAME"
$JOB_dir="F:\docs\PROGS\$vendor\IN"
$FILEPATTERNS="*.pdf,*.csv"
$date=Get-Date -Format g
$ReturnCode=0

$file_list="F:\docs\PROGS\${JOB}_filelist.TXT"
if (Test-Path $file_list) {Remove-Item $file_list;}

#SFTP
$sftp_options=""
$sftp_user="SYS_T"
$sftp_dns="aniib"
$sftp_remote="/Shared/IIB/VENDOR/SYS"
#error/logging
$file_error_list="F:\docs\PROGS\${JOB}_error_filelist.TXT"
if (Test-Path $file_error_list) {Remove-Item $file_error_list;}
$error_file="F:\docs\PROGS\${JOB}_error.TXT"

#email
$STATUS="SUCCESS"
$TO="IM_SFTP_GM@gmail.com, DL-IS-VENDOR-OUTBOUND@gmail.com"
$SUBJECT='$JOB - $VENDOR - $STATUS'
$MSG="F:\docs\PROGS\${JOB}MSG.TXT"
$attachments=

$error.Clear()

cd $JOB_dir

#TEMPLATE
#--------------------------------------------------------------------------------------------------------------------------------------------
ECHO "$ENVIR - Internal - $VENDOR. Job begin $date" > $MSG
ECHO "DTA: $DTA" >> $MSG

$step=1
#Step 1. Check if source path exists
ECHO "`nStep ${step}. Checking path `"$src`"" >> $MSG
if (!(Test-Path "$src")) {
    ECHO "Issue with Source path detected. Please check `"$src`" exists and the account has access permissions." >> $MSG
	ECHO $error[0].Exception.Message >> $MSG
	$STATUS="Error Path Not Found"
	$ReturnCode=1
	End-Script
}
else{
    ECHO "Done" >> $MSG
}

#For each pattern specificed in filepattern variable...
foreach($pattern in $FILEPATTERNS -split ','){
	#SFTP Step
	$step++
    $fileCount=0
	$fileErrorCount=0
	
	ECHO "`nStep ${step}. Pushing files matching `"$pattern`" to `"$sftp_dns`" at `"$sftp_remote`" ..." >> $MSG
	    $files=Get-ChildItem -Path "$src\$pattern"
        :sftp_loop ForEach($file in $files) {
		
		$sftp_out=sftp $sftp_options "$file" $sftp_user@${sftp_dns}:"$sftp_remote" 2>&1
        #$sftp_out= cmd.exe /c "sftp $sftp_params 2>&1"
		$sftp_out | Select-String '(Downloaded|Uploaded) (\/.*\/|F\:\\.*\\)(.+) to' -AllMatches | %{
			$sftp_action=$_.Matches.groups[1].value
			$sftp_path=$_.Matches.groups[2].value
			$sftp_file=$_.Matches.groups[3].value
			#Write filename to file list
			$fileCount++
			$totalFileCount++
			ECHO $sftp_file >> $file_list
		}
		$ReturnCode=$LASTEXITCODE
        #Break out of sftp loop if an error occurs
		IF($ReturnCode -gt 0){ break sftp_loop; }
	}
	ECHO "$fileCount files uploaded." >> $MSG
	#SFTP Errorhandling
	switch ($ReturnCode){
		0 {
			$status="Success"
		}
		1 {
			$status="No Files Processed"
			"No local file found" >> $MSG
		} 
		2 {
			$status="No Files Found On Server"
			"No remote files matching pattern" >> $MSG
		}
        3{
            $status="SFTP Error - Access Denied"
			"$($error.Exception.Message)" >> $MSG
			End-Script
        }
		4 {
			$status="SFTP Error - Unable to Connect"
			"Unable to connect to server. Please check connection details are correct." >> $MSG
			End-Script
		}
		41 {
			$status="Files Not Found On Server"
			"No remote file found" >> $MSG
		}
		43 {
			$status="SFTP Error - Unknown DNS"
			"No such host is known. Please check connection details are correct." >> $MSG
			End-Script
		}
		default {
			$status="SFTP - Unknown Status"
			"Uncaught Return Code on SFTP step" >> $MSG
            "$($error.Exception.Message)" >> $MSG
			End-Script
		}
	}
}

#END
End-Script
