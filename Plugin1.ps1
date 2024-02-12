
Param(
	[Parameter(Mandatory=$true)][ValidateSet("verifypass","changepass","prereconcilepass","reconcilepass","logon")][string]$action,
	[Parameter(Mandatory=$true)][String]$targetuser,
	[Parameter(Mandatory=$true)][String]$address,
	[Parameter(Mandatory=$false)][String]$port,
	[Parameter(Mandatory=$false)][ValidateSet("yes","no")][String]$reconmode = "no",
	[Parameter(Mandatory=$false)][String]$reconuser,
	[Parameter(Mandatory=$false)][ValidateSet("Password","Phrase","racfPassword","racfPassPhrase")][String]$credtype
	)
	
# Set Variables
$targetuser = $targetuser.ToUpper()
$reconuser = $reconuser.ToUpper
$basedn = "profiletype=user,cn=racf,o=X,c=US"
$targetuser = "racfid=$targetuser,$basedn"
$reconuser = "racfid=$reconuser,$basedn"
if($credtype -eq "Password"){$credtype = "racfPassword"}
if($credtype -eq "Phrase"){$credtype = "racfPassPhrase"}
if($null -eq $port){$port = 636}

# Check for minimum arguments
if($null -eq $targetuser -or $null -eq $address){
	Write-Host "Script: Missing Arguments"
	Exit
}

# Do some validation on expected format of the target user
if($targetuser -notmatch "") {
	Write-Host "Script: Username Format"
}

# Load Modules
Add-Type -AssemblyName System.DirectoryServices.Protocols
Add-Type -AssemblyName System.Net
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Create Objects

$objRACFService = New-Object "System.DirectoryServices.Protocols.LdapDirectoryIdentifier" -ArgumentList $address,$port
$objLdapConnector = New-Object "System.DirectoryServices.Protocols.LdapConnection" ($objRACFService)
$objLdapConnector.SessionOptions.SecureSocketLayer = $True
$objLdapConnector.SessionOptions.ProtocolVersion = 3
$objLdapConnector.AuthType = [System.DirectoryServices.Protocols.AuthType]::Basic


switch -regex ($action) {
		'verifypass|logon' {
			Write-Host "TargetUser Current Password"
			$objCred = New-Object "System.Net.NetworkCredential" -ArgumentList $targetuser,$([Console]::ReadLine())
			try {
				$objLdapConnector.Bind($objCred)
				Write-Host "TargetUser Auth OK"
			} catch {
				Write-Host "TargetUser Auth Failed - $($_.Exception.Message)"
			}
		}
		'prereconcilepass' {
			Write-Host "ReconUser Current Password"
			$objCred = New-Object "System.Net.NetworkCredential" -ArgumentList $reconuser,$([Console]::ReadLine())
			try {
				$objLdapConnector.Bind($objCred)
				Write-Host "ReconUser Auth OK"
			} catch {
				Write-Host "ReconUser Auth Failed - $($_.Exception.Message)"
			}			
		}
		'reconcilepass' {
			Write-Host "ReconUser Current Password"
			$objCred = New-Object "System.Net.NetworkCredential" -ArgumentList $reconuser,$([Console]::ReadLine())
			try {
				$objLdapConnector.Bind($objCred)
				$objChange = New-Object System.DirectoryServices.Protocols.ModifyRequest($targetuser)
				$objAttrib = New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification
				$objAttrib.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]:Add
				$objAttrib.Name = "$credtype"
				Write-Host "TargetUser New Password"
				$objAttrib.Add($([Console]::ReadLine()))
				$objChange.Modifications.Add($objAttrib)
				
				$objAttrib = New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification
				$objAttrib.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]:Add
				$objAttrib.Name = "racfAttributes"
				$objAttrib.Add("noexpired")
				$objChange.Modifications.Add($objAttrib)

				$doChange = $objLdapConnector.SendRequest($objChange)
				Write-Host "TargetUser Reconcile Complete"
			} catch {
				Write-Host "ReconUser Change Error - $($_.Exception.Message)"
			}			
		}
		'changepass' {
			if($reconmode -eq "yes") {
				Write-Host "ReconUser Current Password"
				$objCred = New-Object "System.Net.NetworkCredential" -ArgumentList $reconuser,$([Console]::ReadLine())
			} else {
				Write-Host "TargetUser Current Password"
				$objCred = New-Object "System.Net.NetworkCredential" -ArgumentList $reconuser,$([Console]::ReadLine())
			}
			try {
				$objLdapConnector.Bind($objCred)
				$objChange = New-Object System.DirectoryServices.Protocols.ModifyRequest($targetuser)
				$objAttrib = New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification
				$objAttrib.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]:Add
				$objAttrib.Name = "$credtype"
				Write-Host "TargetUser New Password"
				$objAttrib.Add($([Console]::ReadLine()))
				$objChange.Modifications.Add($objAttrib)
				
				$objAttrib = New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification
				$objAttrib.Operation = [System.DirectoryServices.Protocols.DirectoryAttributeOperation]:Add
				$objAttrib.Name = "racfAttributes"
				$objAttrib.Add("noexpired")
				$objChange.Modifications.Add($objAttrib)		

				$doChange = $objLdapConnector.SendRequest($objChange)
				Write-Host "TargetUser Change Complete"
			} catch {
				if($reconmode -eq "yes") {
					Write-Host "ReconUser Change Error - $($_.Exception.Message)"
				} else {
					Write-Host "TargetUser Change Error - $($_.Exception.Message)"
				}
			}
		}
}
