# Parameters for VMNAME, WINDOWS VERSION, and CPU COUNT
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$Name,

    [Parameter(Mandatory=$True,Position=2)]
    [string]$version,

    [Parameter(Mandatory=$True,Position=3)]
    [string]$CPUCount,

    [Parameter(Mandatory=$False,Position=6)]
    [switch]$AutopilotV1 = $False
)

# Verifica se o script está sendo executado como administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "O terminal nao esta em modo administrador. Execute o script como administrador."
    exit
} else {
    Write-Output "O terminal esta em modo administrador."
}

$number = Get-Random -Minimum 1000 -Maximum 10000
$numberString = $number.ToString()
$VMName = $Name + "-" + $version + "-" + $numberString

# Copy disk from TEMPLATES FOLDER and place in Hyper-V directory with VM name
Copy-Item -Path "Path your VHDX.vhdx" -Destination "Your destination VHDX.vhdx" -Force | Out-Null

# Set some VM definitions
$VMSwitchName = "Your Virtual Switch in Hyper-V"
$VhdxPath = "Location for saved your vhdx.vhdx"
$VMPath = "Path VM"

# VM settings and create the VM
New-VM -Name $VMName -BootDevice VHD -VHDPath $VhdxPath -Path $VMPath -Generation 2 -Switch $VMSwitchName
Set-VM -VMName $VMName -ProcessorCount $CPUCount
Set-VMMemory -VMName $VMName -StartupBytes 8GB -DynamicMemoryEnabled $false
Set-VMSecurity -VMName $VMName -VirtualizationBasedSecurityOptOut $false
Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
Enable-VMTPM -VMName $VMName
Set-VM -VMName $VMName -AutomaticCheckpointsEnabled $false | Out-Host

if ($AutopilotV1 -eq $True) {

    # make a path to export the csv to
    $exportPath = "D:\vms\autopilot"
    if(!(Test-Path $exportPath))
    {
        mkdir $exportPath
    }
    # get the hardware info: manufacturer, model, serial
    $serial = Get-WmiObject -ComputerName localhost -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData | Where-Object {$_.elementName -eq $VMName} | Select-Object -ExpandProperty BIOSSerialNumber
    $data = "Microsoft Corporation,Virtual Machine,$($serial)"
    # add to CSV file in path
    Set-Content -Path "$($exportPath)\$($VMName).csv" -Value $data


    # Start the VM
    Start-VM -Name $VMName

    # Wait for the VM to start
    Start-Sleep -Seconds 300

    # Execute the command inside the VM as user 'User' with password 'Password User'
    $securePassword = ConvertTo-SecureString "autopilotv1" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ("Name User", $securePassword)

    Invoke-Command -VMName $VMName -Credential $credential -ScriptBlock {

        $appId="Your App ID"

        $tenantId="Your tenant ID"
        
        $appSecret="Secret"

        
		$Env:AZURE_CLIENT_ID = $appId
		$Env:AZURE_TENANT_ID = $tenantId
		$Env:AZURE_CLIENT_SECRET = $appSecret
        
		
		Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
		Install-Module Microsoft.Graph  -AllowClobber -Force




        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force:$true
        Install-Script get-windowsautopilotinfo -Confirm:$false -Force:$true
        get-windowsautopilotinfo -Online -TenantId $tenantId -AppId $appId -AppSecret $appSecret -GroupTag NERD




    }

# Avisar que a VM vai reinicializar
Write-Output "A VM vai reinicializar agora."

# Reiniciar a VM
Restart-VM -Name $VMName

}
