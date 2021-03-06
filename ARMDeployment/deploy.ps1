
param(
 
 [string]
 $resourceGroupName = "ARMDeployDemoRG",
 [string]
 $subscriptionId = "016ee3d9-5ce9-4f39-a2e4-149aa3dbd010",
 [string]
 $resourceGroupLocation ="australiaeast",
 [string]
 $deploymentName= "ARMDeploymentDemo",
 [string]
 $templateFilePath = "azuredeploy.json",
 [string]
 $parametersFilePath = "azuredeploy.parameters.json"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# sign in
Write-Host "Logging in to the acount...";
Login-AzureRmAccount;

Write-Host "Deleting the storge disk (vhd)";

$RGName = "blobdiskstorage"
$SAName = "blobdiskstroage"
$ContainerName = "vhds"
$BlobName = "ARMDeployDemoVM20190210083931.vhd"
$Keylist = Get-AzureRmStorageAccountKey -ResourceGroupName $RGName -StorageAccountName $SAName

if($Keylist) 
{
    $Key = $Keylist[0].Value
    $storageContext = New-AzureStorageContext -StorageAccountName $SAName -StorageAccountKey $Key
    $blob = Get-AzureStorageBlob -Context $storageContext -Container  $ContainerName -Blob $BlobName -ErrorAction Ignore  
    if($blob)
    { 
        $leaseStatus = $blob.ICloudBlob.Properties.LeaseStatus
        Write-Host "Lease Status $leaseStatus"
        if($leaseStatus -eq "Locked")
        {
            $blob.ICloudBlob.BreakLeaseAsync($(New-TimeSpan), $null, $null, $null)
            Write-Host "Blob Lease Released"
        }
         Write-Host "Deleting the Disk '$BlobName'";
        Remove-AzureStorageBlob -Container $ContainerName -Blob $BlobName -Context $storageContext
        Write-Host "Deleting the Disk '$Deleted'";
    }
}



# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.compute","microsoft.devtestlab");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if($resourceGroup)
{
     Remove-AzResourceGroup -Name $resourceGroupName -Force
     Write-Host "Deleted Resource Group :$resourceGroupName";
}
Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation

# Start the deployment
Write-Host "Starting deployment...";
if(Test-Path $parametersFilePath) {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
} else {
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}