from urllib.request import urlopen, Request
from time import sleep
import json

# NEW!!!
from functools import wraps
from urllib.error import URLError


# def retry(howmany):
#     def tryIt(func):
#         def f():
#             attempts = 0
#             while attempts < howmany:
#                 try:
#                     return func()
#                 except:
#                     attempts += 1
#         return f
#     return tryIt

# @retry(5)

def retry(ExceptionToCheck, tries=4, delay=3, backoff=2, logger=None):
    """Retry calling the decorated function using an exponential backoff.

    http://www.saltycrane.com/blog/2009/11/trying-out-retry-decorator-python/
    original from: http://wiki.python.org/moin/PythonDecoratorLibrary#Retry

    :param ExceptionToCheck: the exception to check. may be a tuple of
        exceptions to check
    :type ExceptionToCheck: Exception or tuple
    :param tries: number of times to try (not retry) before giving up
    :type tries: int
    :param delay: initial delay between retries in seconds
    :type delay: int
    :param backoff: backoff multiplier e.g. value of 2 will double the delay
        each retry
    :type backoff: int
    :param logger: logger to use. If None, print
    :type logger: logging.Logger instance
    """
    def deco_retry(f):

        @wraps(f)
        def f_retry(*args, **kwargs):
            mtries, mdelay = tries, delay
            while mtries > 1:
                try:
                    return f(*args, **kwargs)
                except ExceptionToCheck as e:
                    message = "%s, Retrying in %d seconds..." % (str(e), mdelay)
                    if logger:
                        logger.warning(msg)
                    else:
                        print (message)
                    sleep(mdelay)
                    mtries -= 1
                    mdelay *= backoff
            return f(*args, **kwargs)
        return f_retry  # true decorator
    return deco_retry

@retry(URLError, tries=4, delay=5, backoff=2)
def get_vm_metadata():
    metadata_url = "http://169.254.169.254/metadata/instance?api-version=2017-08-01"
    metadata_req = Request(metadata_url, headers={"Metadata": True})
    print("Getting VM Metadata...")
    metadata_response = urlopen(metadata_req, timeout=2)
    return json.load(metadata_response)

@retry(URLError, tries=4, delay=5, backoff=2)
def get_vm_managed_identity():
    # Managed Identity may  not be available immediately at VM startup...
    # Test/Pause/Retry to see if it gets assigned
    metadata_url = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
    metadata_req = Request(metadata_url, headers={"Metadata": True})
    print("Getting the Managed Identity of the VM...")
    metadata_response = urlopen(metadata_req, timeout=2)
    return json.load(metadata_response)

result_metadata = get_vm_metadata()
print('Metadata=', result_metadata)
result_msi = get_vm_managed_identity()
print('MSI=', result_msi)

/var/lib/waagent/custom-script/download/0/

sudo python3 /var/lib/waagent/custom-script/download/0/cyclecloud_app_server_install.py --acceptTerms --useManagedIdentity --azureSovereignCloud "public" --username "hpcadmin" --password 'TG9vbWVSb2NrUzEy' --useLetsEncrypt --webServerPort 80 --webServerSslPort 443 --webServerMaxHeapSize 4096M --numberOfWorkerNodes 2 --sizeOfWorkerNodes "Standard_B2ms" --osOfClusterNodes "Canonical:UbuntuServer:18.04-LTS:latest" --countOfNodeCores 2 --sshkey "SSHKEY-NAME" --storageAccount "STORAGEACCT-NAME" --hostname "ENTER_HERE" --resourceGroup "RG-NAME" 

CycleCloud account data:
{"Environment": "public", "AzureRMUseManagedIdentity": true, "AzureResourceGroup": "rg-SLURMSolCollTesting--Felipe-Manual6-FelipeCSPAccount", "AzureRMApplicationId": "", "AzureRMApplicationSecret": "", "AzureRMSubscriptionId": "74bdf443-9081-4138-9af1-61f8542cdb45", "AzureRMTenantId": "", "DefaultAccount": true, "Location": "australiaeast", "Name": "azure", "Provider": "azure", "ProviderId": "74bdf443-9081-4138-9af1-61f8542cdb45", "RMStorageAccount": "stocycleappm7fp3rmcw4", "RMStorageContainer": "cyclecloud"}
Getting the Managed Identity of the VM...
Registering the Azure subscription in CycleCloud
Command list: ['/usr/local/bin/cyclecloud', 'account', 'create', '-f', '/tmp/tmptecizfpy/azure_data.json']
Command output: b''

{"Environment": "public", "AzureRMUseManagedIdentity": true, "AzureResourceGroup": "rg-SLURMSolCollTesting--Felipe-Manual6-FelipeCSPAccount", "AzureRMApplicationId": "", "AzureRMApplicationSecret": "", "AzureRMSubscriptionId": "74bdf443-9081-4138-9af1-61f8542cdb45", "AzureRMTenantId": "", "DefaultAccount": true, "Location": "australiaeast", "Name": "azure", "Provider": "azure", "ProviderId": "74bdf443-9081-4138-9af1-61f8542cdb45", "RMStorageAccount": "stocycleappm7fp3rmcw4", "RMStorageContainer": "cyclecloud"}root@cycleappm7fp3rmcw4:/home/hpcadmin#

root@cycleappgpuhbr3g5c:/opt/cycle_server# cat /opt/cycle_server/system/work/.plugins_expanded/.expanded/cloud-ae3a52c5-b8fb-4692-a236-91ef65a01d07/plugins/azure/initial_data/ads/permissions.ini
AdType=Application.Permission
Name=Azure.Cluster.CloudMetadata.Read
Label=View Azure features for {a cloud-provisioned cluster}
ForTypes=Cloud.Cluster,Cloud.Node
Operations=Read
ParentPermission=Cloud.Clusters/View
Permissions=Azure.ComputeCell.Read

AdType=Application.Permission
Name=Azure.ComputeCell.Read
ForTypes=Azure.ComputeCell
Operations=Read
Hidden=true
root@cycleappgpuhbr3g5c:/opt/cycle_server# cat /opt/cycle_server/system/work/.plugins_expanded/.expanded/cloud-ae3a52c5-b8fb-4692-a236-91ef65a01d07/plugins/cloud/initial_data/ads/permissions.ini
AdType=Application.Permission
Name=Cloud.Clusters/View
Label=View {a cloud-provisioned cluster}
ForTypes=Cloud.Cluster,Cloud.Node
Operations=Read
ParentPermission=Clusters/View
Permissions=Cloud.Clusters/Access,Cloud.ClusterTemplate.ReadSection,Cloud.Cluster.ReadCloudMetadata,Cloud.Cluster.ReadMetadata

AdType=Application.Permission
Name=Cloud.Clusters/Manage
Label=Manage {a cloud-provisioned cluster}
ForTypes=Cloud.Cluster,Cloud.Node
Operations=Add:Cloud.Node, Remove:Cloud.Node, Start:Cloud.Node, Terminate:Cloud.Node, Deallocate:Cloud.Node, Shutdown:Cloud.Node, Edit:Cloud.Node, Remove:Cloud.Cluster, Start:Cloud.Cluster, Terminate:Cloud.Cluster, Edit:Cloud.Cluster, Copy:Cloud.Cluster, Upgrade:Cloud.Cluster, Share:Cloud.Cluster
ParentPermission=Clusters/Manage
Permissions=Cloud.Clusters/View

AdType=Application.Permission
Name=Cloud.Clusters/Create
Label=Create new cloud-provisioned clusters
ParentPermission=Clusters/Create
Permissions=Cloud.Cluster.Create,Cloud.ClusterTemplate.Read,Cloud.ClusterTemplate.ReadNode,Cloud.ClusterTemplate.ReadSection,Cloud.Cluster.ReadMetadata

AdType=Application.Permission
Name=Cloud.Clusters/Access
Label=Access the Clusters page and features
ParentPermission=Clusters/Access
Operations=Access:Cloud.Cluster

AdType=Application.Permission
Name=Cloud.Clusters/Configure
Label=Modify CycleCloud-related features
ParentPermission=Clusters/Configure
Permissions=Cloud.Cluster.ConfigureMetadata,Cloud.Cluster.ConfigureAccount,Cloud.Cluster.ConfigureLocker

AdType=Application.Permission
Name=Cloud.Clusters/Connect
Label=Log in to {a cloud-provisioned cluster} as a regular user
ForTypes=Cloud.Cluster,Cloud.Node
Operations=Read,Connect:Cloud.Node
ParentPermission=Clusters/Connect

AdType=Application.Permission
Name=Cloud.Clusters/Administer
Label=Log in to {a cloud-provisioned cluster} as an administrator
ForTypes=Cloud.Cluster,Cloud.Node
Operations=Read,Connect:Cloud.Node,Administer:Cloud.Node
ParentPermission=Clusters/Administer


# building-block permissions
AdType=Application.Permission
Name=Cloud.Cluster.Create
Operations=Add:Cloud.Cluster
ForTypes=Cloud.Cluster
Hidden=true

AdType=Application.Permission
Name=Cloud.Cluster.ReadMetadata
ForTypes=Cloud.Instance,Cloud.InstanceSession,Cloud.Locker,Cloud.MachineType,Cloud.Price,Cloud.ProviderAccount,Cloud.Region,ClusterMetrics,NodeMetrics
Operations=Read
Hidden=true

AdType=Application.Permission
Name=Cloud.Cluster.ConfigureMetadata
ForTypes=Cloud.Instance,Cloud.InstanceSession,Cloud.MachineType,Cloud.Price,Cloud.Region
Operations=Create,Read,Update,Delete
Hidden=true

AdType=Application.Permission
Name=Cloud.Cluster.ConfigureAccount
ForTypes=Cloud.ProviderAccount
Operations=Create,Read,Update,Delete,Retry:Cloud.ProviderAccount
Hidden=true

AdType=Application.Permission
Name=Cloud.Cluster.ConfigureLocker
ForTypes=Cloud.Locker
Operations=Create,Read,Update,Delete,Retry:Cloud.Locker
Hidden=true

AdType=Application.Permission
Name=Cloud.ClusterTemplate.Read
Operations=Read
Description=View cluster templates
ForTypes=Cloud.Cluster
Filter := IsTemplate is true
Hidden=true

AdType=Application.Permission
Name=Cloud.ClusterTemplate.ReadNode
Operations=Read
Description=View nodes in cluster templates
ForTypes=Cloud.Node
Filter := Cluster().IsTemplate is true
Hidden=true

AdType=Application.Permission
Name=Cloud.ClusterTemplate.ReadSection
Operations=Read
ForTypes=Cloud.ClusterSection,Cloud.ClusterParameter
Hidden=true

AdType=Application.Permission
Name=Cloud.Cluster.ReadCloudMetadata
ForTypes=Cloud.MachineType,Cloud.Price,Cloud.Region
Operations=Read
Hidden=true


[{"AdType": "Application.Permission", "Name": "hpcadmin", "Role": "Cloud.Clusters/Administer"}]
Name=Cloud.Clusters/Administer
Label=Log in to {a cloud-provisioned cluster} as an administrator
ForTypes=Cloud.Cluster,Cloud.Node
Operations=Read,Connect:Cloud.Node,Administer:Cloud.Node
ParentPermission=Clusters/Administer