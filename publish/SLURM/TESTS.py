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