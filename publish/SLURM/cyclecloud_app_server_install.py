#!/usr/bin/python3
# Prepare an Azure provider account for CycleCloud usage.
import os
import argparse
import json
import re
import random
import subprocess
import base64
import hmac
import hashlib
from subprocess import CalledProcessError, run
from string import ascii_uppercase, ascii_lowercase, digits
from os import path, listdir, chdir, fdopen, remove
from urllib.request import urlopen, Request
from shutil import rmtree, copy2, move  
from tempfile import mkstemp, mkdtemp
from time import sleep
from datetime import datetime
from functools import wraps
from urllib.error import URLError

tmpdir = mkdtemp()
print("Creating temp directory {} for installing CycleCloud".format(tmpdir))
cycle_root = "/opt/cycle_server"
cs_cmd = cycle_root + "/cycle_server"

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

def clean_up():
    rmtree(tmpdir)

def _catch_sys_error(cmd_list):
    try:
        output = subprocess.run(cmd_list, capture_output=True, check=True, text=True).stdout
        print("Command list:", cmd_list)
        print("Command output:", output)
        return output
    except CalledProcessError as e:
        print("Error with cmd: %s" % e.cmd)
        print("Output: %s" % e.output)
        raise

def create_shared_key_signature(storage_account_key, verb, canonicalized_headers, canonicalised_resource, content_length="", content_type=""):
    string_params = {
        "VERB": verb,
        "Content-Encoding": "",
        "Content-Language": "",
        "Content-Length": content_length,
        "Content-MD5": "",
        "Content-Type": content_type,
        "Date": "",
        "If-Modified-Since": "",
        "If-Match": "",
        "If-None-Match": "",
        "If-Unmodified-Since": "",
        "Range": "",
        "CanonicalizedHeaders": canonicalized_headers,
        "CanonicalizedResource": canonicalised_resource
    }
    
    string_to_sign = (string_params["VERB"] + "\n"
        + string_params["Content-Encoding"] + "\n"
        + string_params["Content-Language"] + "\n"
        + string_params["Content-Length"] + "\n"
        + string_params["Content-MD5"] + "\n"
        + string_params["Content-Type"] + "\n"
        + string_params["Date"] + "\n"
        + string_params["If-Modified-Since"] + "\n"
        + string_params["If-Match"] + "\n"
        + string_params["If-None-Match"] + "\n"
        + string_params["If-Unmodified-Since"] + "\n"
        + string_params["Range"] + "\n"
        + string_params["CanonicalizedHeaders"]
        + string_params["CanonicalizedResource"])
    
    signed_string = base64.b64encode(hmac.new(base64.b64decode(storage_account_key), msg=string_to_sign.encode('utf-8'), digestmod=hashlib.sha256).digest()).decode()
    return signed_string

def create_user(username):
    import pwd
    try:
        pwd.getpwnam(username)
    except KeyError:
        print('Creating user {}'.format(username))
        _catch_sys_error(["useradd", "-m", "-d", "/home/{}".format(username), username])
    _catch_sys_error(["chown", "-R", username + ":" + username, "/home/{}".format(username)])

def create_keypair(use_managed_identity, vm_metadata, ssh_key_name):
    if use_managed_identity:
        managed_identity = get_vm_managed_identity()
        access_token = managed_identity["access_token"]
        access_headers = {
            "Authorization": f"Bearer {access_token}"
        }

    subscriptionId = vm_metadata["compute"]["subscriptionId"]
    resourceGroup = vm_metadata["compute"]["resourceGroupName"]
    
    sshkey_url = "https://management.azure.com/subscriptions/{}/resourceGroups/{}/providers/Microsoft.Compute/sshPublicKeys/{}/generateKeyPair?api-version=2021-11-01".format(subscriptionId, resourceGroup, ssh_key_name)
    sshkey_req = Request(sshkey_url, method="POST", headers=access_headers)

    for _ in range(30):
        print("Generating SSH key")
        sshkey_response = urlopen(sshkey_req, timeout=2)
        
        try:
            return json.load(sshkey_response)
        except ValueError as e:
            print("Failed to generate SSH key %s" % e)
            print("    Retrying")
            sleep(2)
            continue
        except:
            print("Unable to generate SSH key after 30 tries")
            raise

def get_storage_account_keys(use_managed_identity, vm_metadata, storage_account_name):
    if use_managed_identity:
        managed_identity = get_vm_managed_identity()
        access_token = managed_identity["access_token"]
        access_headers = {
            "Authorization": f"Bearer {access_token}"
        }

    subscriptionId = vm_metadata["compute"]["subscriptionId"]
    resourceGroup = vm_metadata["compute"]["resourceGroupName"]
    
    blob_url = "https://management.azure.com/subscriptions/{}/resourceGroups/{}/providers/Microsoft.Storage/storageAccounts/{}/listKeys?api-version=2021-09-01&$expand=kerb".format(subscriptionId, resourceGroup, storage_account_name)
    blob_req = Request(blob_url, method="POST", headers=access_headers)
    
    for _ in range(30):
        print("Fetching storage account access keys")
        blob_response = urlopen(blob_req, timeout=2)
        
        try:
            return json.load(blob_response)
        except ValueError as e:
            print("Failed to obtain storage account access keys %s" % e)
            print("    Retrying")
            sleep(2)
            continue
        except:
            print("Unable to obtain storage account access keys after 30 tries")
            raise

def create_blob_container(storage_account_key, storage_account_name, container_name):
    api_version = "2021-06-08"
    current_timestamp = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    canonicalized_headers = "x-ms-date:" + current_timestamp + "\nx-ms-version:" + api_version + "\n"
    canonicalized_resource = "/" + storage_account_name + "/" + container_name + "\nrestype:container"

    signed_string = create_shared_key_signature(storage_account_key, "PUT", canonicalized_headers, canonicalized_resource)
    
    headers = {
        "x-ms-version": api_version,
        "x-ms-date": current_timestamp,
        "Authorization": f"SharedKey {storage_account_name}:{signed_string}"
    }
    
    container_url = "https://{}.blob.core.windows.net/{}?restype=container".format(storage_account_name, container_name)
    container_req = Request(container_url, method="PUT", headers=headers)
    
    for _ in range(30):
        print("Creating blob container for holding ssh key")
        container_response = urlopen(container_req, timeout=2)
        
        try:
            return container_response.status
        except ValueError as e:
            print("Failed to create blob container %s" % e)
            print("    Retrying")
            sleep(2)
            continue
        except:
            print("Unable to create blob container after 30 tries")
            raise

def upload_key_file(storage_account_key, storage_account_name, private_key, container_name):
    data = private_key.encode("utf-8")
    api_version = "2021-06-08"
    blob_name = "schedulernodeaccesskey.pem"
    blob_type = "BlockBlob"
    current_timestamp = datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")
    content_length = str(len(data))
    content_type = "text/plain; charset=utf-8"
    canonicalized_headers = "x-ms-blob-type:" + blob_type +"\nx-ms-date:" + current_timestamp + "\nx-ms-version:" + api_version + "\n"
    canonicalized_resource = "/" + storage_account_name + "/" + container_name + "/" + blob_name

    signed_string = create_shared_key_signature(storage_account_key, "PUT", canonicalized_headers, canonicalized_resource, content_length, content_type)
    
    headers = {
        'x-ms-date' : current_timestamp,
        'x-ms-version' : api_version,
        'Content-Length': content_length,
        'Content-Type': content_type,
        'x-ms-blob-type': blob_type,
        'Authorization' : f"SharedKey {storage_account_name}:{signed_string}"
    }
    
    upload_url = "https://{}.blob.core.windows.net/{}/{}".format(storage_account_name, container_name, blob_name)  
    upload_req = Request(upload_url, method="PUT", headers=headers, data=data)

    for _ in range(30):
        print("Uploading the ssh key file to the blob container")
        upload_response = urlopen(upload_req, timeout=2)
        
        try:
            return upload_response.status
        except ValueError as e:
            print("Failed to upload the sshkey files to the blob container %s" % e)
            print("    Retrying")
            sleep(2)
            continue
        except:
            print("Unable to upload the ssh key file to the blob container after 30 tries")
            raise

def create_user_credential(username, public_key):
    create_user(username)

    credential_record = {
        "PublicKey": public_key,
        "AdType": "Credential",
        "CredentialType": "PublicKey",
        "Name": username + "/public"
    }
    credential_data_file = os.path.join(tmpdir, "credential.json")
    print("Creating cred file: {}".format(credential_data_file))
    with open(credential_data_file, 'w') as fp:
        json.dump(credential_record, fp)

    config_path = os.path.join(cycle_root, "config/data/")
    print("Copying config to {}".format(config_path))
    _catch_sys_error(["chown", "cycle_server:cycle_server", credential_data_file])
    # Don't use copy2 here since ownership matters
    # copy2(credential_data_file, config_path)
    _catch_sys_error(["mv", credential_data_file, config_path])

def generate_password_string():
    random_pw_chars = ([random.choice(ascii_lowercase) for _ in range(20)] +
                        [random.choice(ascii_uppercase) for _ in range(20)] +
                        [random.choice(digits) for _ in range(10)])
    random.shuffle(random_pw_chars)
    return ''.join(random_pw_chars)

def reset_cyclecloud_pw(username):
    reset_pw = subprocess.Popen( [cs_cmd, "reset_access", username],
                                stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, )
    reset_out, reset_err = reset_pw.communicate( b"yes\n" )
    print(reset_out)
    if reset_err:
        print("Password reset error: %s" % (reset_err))
    out_split = reset_out.rsplit(None, 1)
    pw = out_split.pop().decode("utf-8")
    print("Disabling forced password reset for {}".format(username))
    update_cmd = 'update AuthenticatedUser set ForcePasswordReset = false where Name=="%s"' % (username)
    _catch_sys_error([cs_cmd, 'execute', update_cmd])
    return pw 

  
def cyclecloud_account_setup(vm_metadata, use_managed_identity, tenant_id, application_id, application_secret,
                             admin_user, azure_cloud, accept_terms, password, storageAccount, no_default_account, 
                             webserver_port):
    print("Setting up the Azure account in CycleCloud and initializing cyclecloud CLI")

    if not accept_terms:
        print("Accept terms was false. Overriding for now...")
        accept_terms = True

    subscription_id = vm_metadata["compute"]["subscriptionId"]
    location = vm_metadata["compute"]["location"]
    resource_group = vm_metadata["compute"]["resourceGroupName"]

    random_suffix = ''.join(random.SystemRandom().choice(
        ascii_lowercase) for _ in range(14))

    cyclecloud_admin_pw = ""
    if password:
        print('Password specified, using it as the admin password')
        cyclecloud_admin_pw = password
    else:
        print('Password not specified, using the user name as password')
        cyclecloud_admin_pw = admin_user
        
    if storageAccount:
        print('Storage account specified, using it as the default locker')
        storage_account_name = storageAccount
    else:
        storage_account_name = 'cyclecloud{}'.format(random_suffix)

    azure_data = {
        "Environment": azure_cloud,
        "AzureRMUseManagedIdentity": use_managed_identity,
        "AzureResourceGroup": resource_group,
        "AzureRMApplicationId": application_id,
        "AzureRMApplicationSecret": application_secret,
        "AzureRMSubscriptionId": subscription_id,
        "AzureRMTenantId": tenant_id,
        "DefaultAccount": True,
        "Location": location,
        "Name": "azure",
        "Provider": "azure",
        "ProviderId": subscription_id,
        "RMStorageAccount": storage_account_name,
        "RMStorageContainer": "cyclecloud"
    }
    distribution_method ={
        "Category": "system",
        "Status": "internal",
        "AdType": "Application.Setting",
        "Description": "CycleCloud distribution method e.g. marketplace, container, manual.",
        "Value": "manual",
        "Name": "distribution_method"
    }
    if use_managed_identity:
        azure_data["AzureRMUseManagedIdentity"] = True

    app_setting_installation = {
        "AdType": "Application.Setting",
        "Name": "cycleserver.installation.complete",
        "Value": True
    }
    initial_user = {
        "AdType": "Application.Setting",
        "Name": "cycleserver.installation.initial_user",
        "Value": admin_user
    }
    account_data = [
        initial_user,
        distribution_method,
        app_setting_installation
    ]

    if accept_terms:
        # Terms accepted, auto-create login user account as well
        login_user = {
            "AdType": "AuthenticatedUser",
            "Name": admin_user,
            "RawPassword": cyclecloud_admin_pw,
            "Superuser": True
        }
        account_data.append(login_user)

    account_data_file = tmpdir + "/account_data.json"

    with open(account_data_file, 'w') as fp:
        json.dump(account_data, fp)

    config_path = os.path.join(cycle_root, "config/data/")
    _catch_sys_error(["chown", "cycle_server:cycle_server", account_data_file])
    _catch_sys_error(["mv", account_data_file, config_path])
    sleep(5)

    if not accept_terms:
        # reset the installation status so the splash screen re-appears
        print("Resetting installation")
        sql_statement = 'update Application.Setting set Value = false where name ==\"cycleserver.installation.complete\"'
        _catch_sys_error(
            ["/opt/cycle_server/cycle_server", "execute", sql_statement])

    # If using a random password, we need to reset it on each container restart (since we regenerated it above)
    # But do is AFTER user is created in CC
    if not password:
        cyclecloud_admin_pw = reset_cyclecloud_pw(admin_user)
    initialize_cyclecloud_cli(admin_user, cyclecloud_admin_pw, webserver_port)

    if no_default_account:
        print("Skipping default account creation (--noDefaultAccount).") 
    else:
        output =  _catch_sys_error(["/usr/local/bin/cyclecloud", "account", "show", "azure"])
        if 'Credentials: azure' in str(output):
            print("Account \"azure\" already exists.   Skipping account setup...")
        else:
            azure_data_file = tmpdir + "/azure_data.json"
            with open(azure_data_file, 'w') as fp:
                json.dump(azure_data, fp)

            print("CycleCloud account data:")
            print(json.dumps(azure_data))

            # Wait until Managed Identity is ready for use before creating the Account
            if use_managed_identity:
                get_vm_managed_identity()

            # Create the cloud provider account
            # Retry in case it takes much longer than expected 
            # (this is common with limited compute resources)
            max_tries = 30
            created = False
            print("Registering the Azure subscription in CycleCloud")

            while not created:
                try:
                    max_tries -= 1
                    cmd_list = ["/usr/local/bin/cyclecloud", "account", "create", "-f", azure_data_file]
                    output = subprocess.run(cmd_list, capture_output=True).stdout
                    created = True
                    print("Command list:", cmd_list)
                    print("Command output:", output)
                except:
                    if max_tries >  0:
                            print("Retrying after 10 seconds...")
                            sleep(10)
                    else:
                        print("Error adding the subscription")
                        raise                    

def initialize_cyclecloud_cli(admin_user, cyclecloud_admin_pw, webserver_port):
    print("Setting up azure account in CycleCloud and initializing cyclecloud CLI")

    # wait for the data to be imported
    password_flag = ("--password=%s" % cyclecloud_admin_pw)

    print("Initializing cylcecloud CLI")
    _catch_sys_error(["/usr/local/bin/cyclecloud", "initialize", "--loglevel=debug", "--batch", "--force",
                      "--url=https://localhost:{}".format(webserver_port), "--verify-ssl=false", "--username=%s" % admin_user, password_flag])


def letsEncrypt(fqdn):
    sleep(60)
    try:
        cmd_list = [cs_cmd, "keystore", "automatic", "--accept-terms", fqdn]
        output = subprocess.run(cmd_list, capture_output=True, check=True, text=True).stdout
        print("Command list:", cmd_list)
        print("Command output:", output)
    except CalledProcessError as e:
        print("Error getting SSL cert from Lets Encrypt")
        print("Proceeding with self-signed cert")

@retry(URLError, tries=30, delay=2, backoff=2)
def get_vm_metadata():
    metadata_url = "http://169.254.169.254/metadata/instance?api-version=2017-08-01"
    metadata_req = Request(metadata_url, headers={"Metadata": True})
    print("Getting VM metadata...")
    metadata_response = urlopen(metadata_req, timeout=2)
    return json.load(metadata_response)

            # def get_vm_metadata():
            #     metadata_url = "http://169.254.169.254/metadata/instance?api-version=2017-08-01"
            #     metadata_req = Request(metadata_url, headers={"Metadata": True})

            #     for _ in range(30):
            #         print("Fetching metadata")
            #         metadata_response = urlopen(metadata_req, timeout=2)

            #         try:
            #             return json.load(metadata_response)
            #         except ValueError as e:
            #             print("Failed to get metadata %s" % e)
            #             print("    Retrying")
            #             sleep(5)
            #             continue
            #         except:
            #             print("Unable to obtain metadata after 30 tries")
            #             raise

#@retry(URLError, tries=30, delay=2, backoff=2)
def get_vm_managed_identity():
    # Managed Identity may  not be available immediately at VM startup so retrying several times and backing off with each retry
    metadata_url = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
    metadata_req = Request(metadata_url, headers={"Metadata": True})
    print("Getting the Managed System Identity (MSI) of the VM...")
    for i in range(30):
        attempts = i+1
        print("VM MSI attempt number:", attempts)
        while True :
            try:
                metadata_response = urlopen(metadata_req, timeout=2)
            except ValueError as e:
                print("Failed to get managed identity:" % e)
                print("Retrying after 10 seconds...")
                sleep(10)
                continue
            else:
                print("Successfully retrieved the MSI of the VM!")
                return json.load(metadata_response)



                # metadata_url = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
                # metadata_req = Request(metadata_url, headers={"Metadata": True})
                # print("Getting the Managed Identity of the VM...")
                # metadata_response = urlopen(metadata_req, timeout=2)
                # return json.load(metadata_response)

                # def get_vm_managed_identity():
                #     # Managed Identity may  not be available immediately at VM startup...
                #     # Test/Pause/Retry to see if it gets assigned
                #     metadata_url = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
                #     metadata_req = Request(metadata_url, headers={"Metadata": True})

                #     for _ in range(30):
                #         print("Fetching managed identity")
                #         metadata_response = urlopen(metadata_req, timeout=2)

                #         try:
                #             return json.load(metadata_response)
                #         except ValueError as e:
                #             print("Failed to get managed identity %s" % e)
                #             print("    Retrying")
                #             sleep(10)
                #             continue
                #         except:
                #             print("Unable to obtain managed identity after 30 tries")
#             raise    

def start_cc():
    import glob
    import subprocess
    print("(Re-)Starting CycleCloud server")
    _catch_sys_error([cs_cmd, "stop"])
    if glob.glob("/opt/cycle_server/data/ads/corrupt*") or glob.glob("/opt/cycle_server/data/ads/*logfile_failure"):
        print("WARNING: Corrupted datastore masterlog detected.   Restoring from last backup...")
        if not glob.glob("/opt/cycle_server/data/backups/backup-*"):
            raise Exception("ERROR: No backups found, but master.logfile is corrupt!")
        try:
            yes = subprocess.Popen(['echo', 'yes'], stdout=subprocess.PIPE)
            output = subprocess.subprocess.run(['/opt/cycle_server/util/restore.sh'], stdin=yes.stdout)
            yes.wait()
            print(output)
        except CalledProcessError as e:
            print("Error with cmd: %s" % e.cmd)
            print("Output: %s" % e.output)
            raise
    
    _catch_sys_error([cs_cmd, "start"])

    # Retry await_startup in case it takes much longer than expected 
    # (this is common in local testing with limited compute resources)
    max_tries = 60
    started = False
    while not started:
        try:
            max_tries -= 1
            _catch_sys_error([cs_cmd, "await_startup"])
            started = True
        except:
            if max_tries >  0:
                print("Retrying after 20 seconds...")
                sleep(20)
            else:
                raise 

def modify_cs_config(options):
    print("Editing CycleCloud server system properties file")
    # modify the CS config files
    cs_config_file = cycle_root + "/config/cycle_server.properties"

    fh, tmp_cs_config_file = mkstemp()
    with fdopen(fh, 'w') as new_config:
        with open(cs_config_file) as cs_config:
            for line in cs_config:
                if line.startswith('webServerMaxHeapSize='):
                    new_config.write('webServerMaxHeapSize={}\n'.format(options['webServerMaxHeapSize']))
                elif line.startswith('webServerPort='):
                    new_config.write('webServerPort={}\n'.format(options['webServerPort']))
                elif line.startswith('webServerSslPort='):
                    new_config.write('webServerSslPort={}\n'.format(options['webServerSslPort']))
                elif line.startswith('webServerClusterPort'):
                    new_config.write('webServerClusterPort={}\n'.format(options['webServerClusterPort']))
                elif line.startswith('webServerEnableHttps='):
                    new_config.write('webServerEnableHttps={}\n'.format(str(options['webServerEnableHttps']).lower()))
                elif line.startswith('webServerHostname'):
                    # This isn't generally a default setting, so set it below
                    continue
                else:
                    new_config.write(line)

            if 'webServerHostname' in options and options['webServerHostname']:
                new_config.write('webServerHostname={}\n'.format(options['webServerHostname']))

    remove(cs_config_file)
    move(tmp_cs_config_file, cs_config_file)

    #Ensure that the files are created by the cycleserver service user
    _catch_sys_error(["chown", "-R", "cycle_server.", cycle_root])

def install_cc_cli():
    # CLI comes with an install script but that installation is user specific
    # rather than system wide.
    # Downloading and installing pip, then using that to install the CLIs
    # from source.
    if os.path.exists("/usr/local/bin/cyclecloud"):
        print("CycleCloud CLI already installed.")
        return

    print("Unzip and install CLI")
    chdir(tmpdir)
    _catch_sys_error(["unzip", "/opt/cycle_server/tools/cyclecloud-cli.zip"])
    for cli_install_dir in listdir("."):
        if path.isdir(cli_install_dir) and re.match("cyclecloud-cli-installer", cli_install_dir):
            print("Found CLI install DIR %s" % cli_install_dir)
            chdir(cli_install_dir)
            _catch_sys_error(["./install.sh", "--system"])


def already_installed():
    print("Checking for existing Azure CycleCloud install")
    return os.path.exists("/opt/cycle_server/cycle_server")

def download_install_cc():
    print("Installing Azure CycleCloud server")
    _catch_sys_error(["apt", "install", "-y", "cyclecloud8"])

def configure_msft_apt_repos():
    print("Configuring Microsoft apt repository for CycleCloud install")

    # First clear the apt lists to avoid error code 100
    _catch_sys_error (["rm", "-rf", "/var/lib/apt/lists/*"])
    
    _catch_sys_error(
        ["wget", "-q", "-O", "/tmp/microsoft.asc", "https://packages.microsoft.com/keys/microsoft.asc"])
    _catch_sys_error(
        ["apt-key", "add", "/tmp/microsoft.asc"])
    
    # Fix while Ubuntu 20 is not available -- we install the Ubuntu 18.04 version
    lsb_release = "bionic"

    # Install HTTPS transport to avoid error 100 when adding the MSFT repos
    _catch_sys_error(["apt-get", "update"])
    _catch_sys_error(["apt-get", "install", "-y", "apt-transport-https"])

    with open('/etc/apt/sources.list.d/azure-cli.list', 'w') as f:
        f.write("deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ {} main".format(lsb_release))

    with open('/etc/apt/sources.list.d/cyclecloud.list', 'w') as f:
        f.write("deb [arch=amd64] https://packages.microsoft.com/repos/cyclecloud {} main".format(lsb_release))
    _catch_sys_error(["apt-get", "update", "-y", "--allow-releaseinfo-change"])
    
def install_pre_req():
    print("Installing pre-requisites for CycleCloud server")
    _catch_sys_error(["apt-get", "update", "-y", "--allow-releaseinfo-change"])
    _catch_sys_error(["apt", "install", "-y", "openjdk-8-jre-headless"])
    _catch_sys_error(["apt", "install", "-y", "unzip"])
    _catch_sys_error(["apt", "install", "-y", "python3-venv"])
    # Not strictly needed, but it's useful to have the AZ CLI
    _catch_sys_error(["apt", "install", "-y", "azure-cli"])


def import_cluster(vm_metadata, cluster_image, machine_type, node_size, node_cores):
    cluster_template_file_name = "slurm_template.ini"
    cluster_parameters_file_name = "slurm_params.json"

    ###########################################################################################!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ### NEEDS A FINAL LOCATION for PRODUCTION!!
    cluster_files_download_url = "https://raw.githubusercontent.com/fayora/mydev-solution-collections/main/publish/SLURM/"
    ###########################################################################################!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    cluster_template_file_download_path = "/tmp/" + cluster_template_file_name
    cluster_parameters_file_download_path = "/tmp/" + cluster_parameters_file_name
    cluster_template_file_url = cluster_files_download_url + cluster_template_file_name
    cluster_parameters_file_url = cluster_files_download_url + cluster_parameters_file_name
    _catch_sys_error(["sudo", "wget", "-q", "-O", cluster_template_file_download_path, cluster_template_file_url])
    _catch_sys_error(["sudo", "wget", "-q", "-O", cluster_parameters_file_download_path, cluster_parameters_file_url])

    _catch_sys_error(["chown", "-R", "cycle_server:cycle_server", cluster_template_file_download_path])
    _catch_sys_error(["chown", "-R", "cycle_server:cycle_server", cluster_parameters_file_download_path])

    # Construct the Subnet ID value by using the information in the VM metadata for Resource Group and the VM name
    resource_group = vm_metadata["compute"]["resourceGroupName"]
    vm_name = vm_metadata["compute"]["name"]
    # *********************************************************
    # *IMPORTANT: this string value has a dependency on the name specified to the subnet in the ARM template that deploys the CycleCloud App 
    subnet_name = "compute"
    # *********************************************************
    subnet_string_value = resource_group + "/vnet" + vm_name + "/" + subnet_name
    subnet_param = "SubnetId=" + subnet_string_value
    print("The subnet for the worker nodes is: %s" % subnet_param)
    
    schedulerImage_param = "SchedulerImageName=" + cluster_image
    print("The os image for the scheduler nodes is: %s" % schedulerImage_param)
    
    workerImage_param = "HPCImageName=" + cluster_image
    print("The os image for the worker nodes is: %s" % workerImage_param)

    machineType_param = "HPCMachineType=" + machine_type
    print("The machine type for the worker nodes is: %s" % machineType_param)

    max_core = int(node_size) * int(node_cores)
    maxCore_param = "MaxHPCExecuteCoreCount=" + str(max_core)
    print("The amount of execute core for the worker nodes is: %s" % maxCore_param)
    
    # We import the cluster, passing the subnet name as a parameter override
    _catch_sys_error(["/usr/local/bin/cyclecloud","import_cluster","-f", cluster_template_file_download_path, "-p", cluster_parameters_file_download_path, "--parameter-override", subnet_param, "--parameter-override", schedulerImage_param, "--parameter-override", workerImage_param, "--parameter-override", machineType_param, "--parameter-override", maxCore_param])


def start_cluster():
    _catch_sys_error(["/usr/local/bin/cyclecloud", "start_cluster", "Slurm-Custom"])
    
def main():
    parser = argparse.ArgumentParser(description="usage: %prog [options]")

    parser.add_argument("--azureSovereignCloud",
                        dest="azureSovereignCloud",
                        default="public",
                        help="Azure Region [china|germany|public|usgov]")

    parser.add_argument("--tenantId",
                        dest="tenantId",
                        default="",
                        help="Tenant ID of the Azure subscription")

    parser.add_argument("--applicationId",
                        dest="applicationId",
                        default="",
                        help="Application ID of the Service Principal")

    parser.add_argument("--applicationSecret",
                        dest="applicationSecret",
                        default="",
                        help="Application Secret of the Service Principal")

    parser.add_argument("--username",
                        dest="username",
                        default="hpcadmin",
                        help="The local admin user for the CycleCloud VM")

    parser.add_argument("--hostname",
                        dest="hostname",
                        help="The short public hostname assigned to this VM (or public IP), used for LetsEncrypt")

    parser.add_argument("--acceptTerms",
                        dest="acceptTerms",
                        action="store_true",
                        help="Accept Cyclecloud terms and do a silent install")

    parser.add_argument("--useLetsEncrypt",
                        dest="useLetsEncrypt",
                        action="store_true",
                        help="Automatically fetch certificate from Let's Encrypt.  (Only suitable for installations with public IP.)")

    parser.add_argument("--useManagedIdentity",
                        dest="useManagedIdentity",
                        action="store_true",
                        help="Use the first assigned Managed Identity rather than a Service Principle for the default account")

    parser.add_argument("--dryrun",
                        dest="dryrun",
                        action="store_true",
                        help="Allow local testing outside Azure Docker")

    parser.add_argument("--password",
                        dest="password",
                        default="",
                        help="The password for the CycleCloud UI user")

    parser.add_argument("--sshkey",
                        dest="sshkey",
                        default="",
                        help="The Azure ssh key instance that stores the public ssh key for remote accessing scheduler node")

    parser.add_argument("--storageAccount",
                        dest="storageAccount",
                        help="The storage account to use as a CycleCloud locker")

    parser.add_argument("--resourceGroup",
                        dest="resourceGroup",
                        help="The resource group for CycleCloud cluster resources.  Resource Group must already exist.  (Default: same RG as CycleCloud)")

    parser.add_argument("--noDefaultAccount",
                        dest="no_default_account",
                        action="store_true",
                        help="Do not attempt to configure a default CycleCloud Account (useful for CycleClouds managing other subscriptions)")
                    
    parser.add_argument("--webServerMaxHeapSize",
                        dest="webServerMaxHeapSize",
                        default='4096M',
                        help="CycleCloud max heap")

    parser.add_argument("--webServerPort",
                        dest="webServerPort",
                        default=8080,
                        help="CycleCloud front-end HTTP port")

    parser.add_argument("--webServerSslPort",
                        dest="webServerSslPort",
                        default=8443,
                        help="CycleCloud front-end HTTPS port")

    parser.add_argument("--webServerClusterPort",
                        dest="webServerClusterPort",
                        default=9443,
                        help="CycleCloud cluster/back-end HTTPS port")

    parser.add_argument("--webServerHostname",
                        dest="webServerHostname",
                        default="",
                        help="Over-ride CycleCloud hostname for cluster/back-end connections")
    
    parser.add_argument("--sizeOfWorkerNodes",
                        dest="sizeOfWorkerNodes",
                        default="Standard_B2ms",
                        help="The VM size for worker nodes")

    parser.add_argument("--numberOfWorkerNodes",
                        dest="numberOfWorkerNodes",
                        default=2,
                        help="The VM size for worker nodes")
    
    parser.add_argument("--osOfClusterNodes",
                        dest="osOfClusterNodes",
                        default="Canonical:UbuntuServer:18.04-LTS:latest",
                        help="The VM OS for both scheduler & worker nodes")

    parser.add_argument("--countOfNodeCores",
                        dest="countOfNodeCores",
                        default=2,
                        help="The amount of cores for worker nodes")


    args = parser.parse_args()

    print("Debugging arguments: %s" % args)

    if not already_installed():
        configure_msft_apt_repos()
        install_pre_req()
        download_install_cc()
        modify_cs_config(options = {'webServerMaxHeapSize': args.webServerMaxHeapSize,
                                    'webServerPort': args.webServerPort,
                                    'webServerSslPort': args.webServerSslPort,
                                    'webServerClusterPort': args.webServerClusterPort,
                                    'webServerEnableHttps': True,
                                    'webServerHostname': args.webServerHostname})

    start_cc()

    install_cc_cli()

    vm_metadata = get_vm_metadata()

    # We decode the password back to an ASCII string because they are passed as Base64 to avoid issues with special characters
    decoded_password = base64.b64decode(args.password).decode('ascii')

    print("The raw password is: %s" % args.password)
    print("The decoded password is: %s" % decoded_password)

    if args.resourceGroup:
        print("CycleCloud created in resource group: %s" % vm_metadata["compute"]["resourceGroupName"])
        print("Cluster resources will be created in resource group: %s" %  args.resourceGroup)
        vm_metadata["compute"]["resourceGroupName"] = args.resourceGroup

    cyclecloud_account_setup(vm_metadata, args.useManagedIdentity, args.tenantId, args.applicationId,
                             args.applicationSecret, args.username, args.azureSovereignCloud,
                             args.acceptTerms, decoded_password, args.storageAccount, 
                             args.no_default_account, args.webServerSslPort)

    if args.useLetsEncrypt:
        letsEncrypt(args.hostname)

    # Create the ssh key file
    ssh_key = create_keypair(args.useManagedIdentity, vm_metadata, args.sshkey)
    public_key = ssh_key["publicKey"]
    private_key = ssh_key["privateKey"]

    # Store the private key in blob storage
    storage_account_keys = get_storage_account_keys(args.useManagedIdentity, vm_metadata, args.storageAccount)
    storage_account_key = storage_account_keys["keys"][0]["value"]
    container_name = "sshkeyholder"

    create_blob_container(storage_account_key, args.storageAccount, container_name)
    upload_key_file(storage_account_key, args.storageAccount, private_key, container_name)
    
    # Create user requires root privileges
    create_user_credential(args.username, public_key)

    # Sleep for 6 minutes while CycleCloud retrieves Azure information and finish its internal configuration
    # sleep(360)

    #clean_up()

    # Import and start the SLURM cluster using template and parameter files downloaded from an online location 
    import_cluster(vm_metadata, args.osOfClusterNodes, args.sizeOfWorkerNodes, args.numberOfWorkerNodes, args.countOfNodeCores)
    start_cluster()

if __name__ == "__main__":
    try:
        main()
    except:
        print("Deployment failed...")
        raise