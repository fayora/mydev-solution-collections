#!/usr/bin/python3
# Prepare an Azure provider account for CycleCloud usage.
import os
import sys
import argparse
import json
import re
import random
from string import ascii_uppercase, ascii_lowercase, digits
import subprocess
from subprocess import CalledProcessError, run
from os import path, listdir, chdir, fdopen, remove
from urllib.request import urlopen, Request
from shutil import rmtree, copy2, move
from tempfile import mkstemp, mkdtemp
from time import sleep
import base64


tmpdir = mkdtemp()
print("Creating temp directory {} for installing CycleCloud".format(tmpdir))
cycle_root = "/opt/cycle_server"
cs_cmd = cycle_root + "/cycle_server"


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

def create_user(username):
    import pwd
    try:
        pwd.getpwnam(username)
    except KeyError:
        print('Creating user {}'.format(username))
        _catch_sys_error(["useradd", "-m", "-d", "/home/{}".format(username), username])
    _catch_sys_error(["chown", "-R", username + ":" + username, "/home/{}".format(username)])

def create_keypair(username, public_key=None):
    if not os.path.isdir("/home/{}/.ssh".format(username)):
        _catch_sys_error(["mkdir", "-p", "/home/{}/.ssh".format(username)])
    public_key_file  = "/home/{}/.ssh/id_rsa.pub".format(username)
    if not os.path.exists(public_key_file):
        if public_key:
            with open(public_key_file, 'w') as pubkeyfile:
                pubkeyfile.write(public_key)
                pubkeyfile.write("\n")
        else:
            _catch_sys_error(["ssh-keygen", "-f", "/home/{}/.ssh/id_rsa".format(username), "-N", ""])
            with open(public_key_file, 'r') as pubkeyfile:
                public_key = pubkeyfile.read()

    authorized_key_file = "/home/{}/.ssh/authorized_keys".format(username)
    authorized_keys = ""
    if os.path.exists(authorized_key_file):
        with open(authorized_key_file, 'r') as authkeyfile:
            authorized_keys = authkeyfile.read()
    if public_key not in authorized_keys:
        with open(authorized_key_file, 'w') as authkeyfile:
            authkeyfile.write(public_key)
            authkeyfile.write("\n")
    _catch_sys_error(["chown", "-R", username + ":" + username, "/home/{}".format(username)])
    return public_key

def create_user_credential(username, public_key=None):
    create_user(username)    
    public_key = create_keypair(username, public_key)

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

    print("Setting up azure account in CycleCloud and initializing cyclecloud CLI")

    if not accept_terms:
        print("Accept terms was FALSE !!!!!  Over-riding for now...")
        accept_terms = True

    # if path.isfile(cycle_root + "/config/data/account_data.json.imported"):
    #     print 'Azure account is already configured in CycleCloud. Skipping...'
    #     return

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
    # Don't use copy2 here since ownership matters
    # copy2(account_data_file, config_path)
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

            # wait until Managed Identity is ready for use before creating the Account
            if use_managed_identity:
                get_vm_managed_identity()

            # create the cloud provided account
                # Retry await_startup in case it takes much longer than expected 
            # (this is common in local testing with limited compute resources)
            max_tries = 10
            created = False
            print("Registering Azure subscription in CycleCloud")
            try:
                cmd_list = ["/usr/local/bin/cyclecloud", "account", "create", "-f", azure_data_file]
                output = subprocess.run(cmd_list, capture_output=True).stdout
                print("Command list:", cmd_list)
                print("Command output:", output)
            except CalledProcessError as e:
                print("Error adding the subscription")

def initialize_cyclecloud_cli(admin_user, cyclecloud_admin_pw, webserver_port):
    print("Setting up azure account in CycleCloud and initializing cyclecloud CLI")

    # wait for the data to be imported
    password_flag = ("--password=%s" % cyclecloud_admin_pw)

    print("Initializing cylcecloud CLI")
    _catch_sys_error(["/usr/local/bin/cyclecloud", "initialize", "--loglevel=debug", "--batch", "--force",
                      "--url=https://localhost:{}".format(webserver_port), "--verify-ssl=false", "--username=%s" % admin_user, password_flag])


def letsEncrypt(fqdn):
    sleep(90)
    try:
        cmd_list = [cs_cmd, "keystore", "automatic", "--accept-terms", fqdn]
        output = subprocess.run(cmd_list, capture_output=True, check=True, text=True).stdout
        print("Command list:", cmd_list)
        print("Command output:", output)
    except CalledProcessError as e:
        print("Error getting SSL cert from Lets Encrypt")
        print("Proceeding with self-signed cert")


def get_vm_metadata():
    metadata_url = "http://169.254.169.254/metadata/instance?api-version=2017-08-01"
    metadata_req = Request(metadata_url, headers={"Metadata": True})

    for _ in range(30):
        print("Fetching metadata")
        metadata_response = urlopen(metadata_req, timeout=2)

        try:
            return json.load(metadata_response)
        except ValueError as e:
            print("Failed to get metadata %s" % e)
            print("    Retrying")
            sleep(2)
            continue
        except:
            print("Unable to obtain metadata after 30 tries")
            raise

def get_vm_managed_identity():
    # Managed Identity may  not be available immediately at VM startup...
    # Test/Pause/Retry to see if it gets assigned
    metadata_url = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
    metadata_req = Request(metadata_url, headers={"Metadata": True})

    for _ in range(30):
        print("Fetching managed identity")
        metadata_response = urlopen(metadata_req, timeout=2)

        try:
            return json.load(metadata_response)
        except ValueError as e:
            print("Failed to get managed identity %s" % e)
            print("    Retrying")
            sleep(10)
            continue
        except:
            print("Unable to obtain managed identity after 30 tries")
            raise    

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

def configure_msft_repos():
    configure_msft_apt_repos()

def configure_msft_apt_repos():
    print("Configuring Microsoft apt repository for CycleCloud install")
    _catch_sys_error(
        ["wget", "-q", "-O", "/tmp/microsoft.asc", "https://packages.microsoft.com/keys/microsoft.asc"])
    _catch_sys_error(
        ["apt-key", "add", "/tmp/microsoft.asc"])
    
    # Fix while Ubuntu 20 is not available -- we install the Ubuntu 18.04 version
    lsb_release = "bionic"

    with open('/etc/apt/sources.list.d/azure-cli.list', 'w') as f:
        f.write("deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ {} main".format(lsb_release))

    with open('/etc/apt/sources.list.d/cyclecloud.list', 'w') as f:
        f.write("deb [arch=amd64] https://packages.microsoft.com/repos/cyclecloud {} main".format(lsb_release))
    _catch_sys_error(["apt", "update", "-y"])

def install_pre_req():
    print("Installing pre-requisites for CycleCloud server")
    _catch_sys_error(["apt", "update", "-y"])
    _catch_sys_error(["apt", "install", "-y", "openjdk-8-jre-headless"])
    _catch_sys_error(["apt", "install", "-y", "unzip"])
    _catch_sys_error(["apt", "install", "-y", "python3-venv"])
    # Not strictly needed, but it's useful to have the AZ CLI
    _catch_sys_error(["apt", "install", "-y", "azure-cli"])

def add_slurm_fix():
    # Download the file with the Slurm fix, save it in the required path and give the cycle_server ownership of it
    slurm_fix_file_name = "cluster-init-slurm-2.5.1.txt"
    slurm_fix_file_download_path = "/tmp/" + slurm_fix_file_name
    slurm_fix_file_path = "/opt/cycle_server/config/data/"
    slurm_fix_file_full_path = slurm_fix_file_path + slurm_fix_file_name
    slurm_fix_file_download_url = "https://raw.githubusercontent.com/fayora/mydev-solution-collections/main/publish/CycleCloud_SLURM/" + slurm_fix_file_name
    
    _catch_sys_error(["wget","-q","-O", slurm_fix_file_download_path, slurm_fix_file_download_url])
    _catch_sys_error(["mv", slurm_fix_file_download_path, slurm_fix_file_path])
    _catch_sys_error(["chown", "-R", "cycle_server:cycle_server", slurm_fix_file_full_path])
    sleep(30)

def import_cluster(vm_metadata):
    cluster_template_file_name = "slurm_template.ini"
    cluster_parameters_file_name = "slurm_params.json"
    cluster_files_download_url = "https://raw.githubusercontent.com/fayora/mydev-solution-collections/main/publish/CycleCloud_SLURM/"
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
    
    # We import the cluster, passing the subnet name as a parameter override
    _catch_sys_error(["/usr/local/bin/cyclecloud","import_cluster","-f", cluster_template_file_download_path, "-p", cluster_parameters_file_download_path, "--parameter-override", subnet_param])


def start_cluster():
    _catch_sys_error(["/usr/local/bin/cyclecloud", "start_cluster", "Slurm"])
    
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

    parser.add_argument("--publickey",
                        dest="publickey",
                        default="",
                        help="The public ssh key for the CycleCloud UI user")

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

    args = parser.parse_args()

    print("Debugging arguments: %s" % args)

    if not already_installed():
        configure_msft_repos()
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

    # We decode the password and publick key back to an ASCII string because they are passed as Base64 to avoid issues with special characters
    decoded_password = base64.b64decode(args.password).decode('ascii')
    decoded_publicKey = base64.b64decode(args.publickey).decode('ascii')

    print("The raw password is: %s" % args.password)
    print("The decoded password is: %s" % decoded_password)


    print("The raw SSH key is: %s" %  args.publickey)
    print("The decoded SSH key is: %s" % decoded_publicKey)

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

    #  Create user requires root privileges
    create_user_credential(args.username, decoded_publicKey)

    # Sleep for 5 minutes while CycleCloud retrieves Azure information and finish its internal configuration
    sleep(300)

    # Add the temporary fix provided by the CycleCloud Engineerig team for SLURM, and then restart the CycleCloud server
    add_slurm_fix()
    start_cc()

    # Import and start the SLURM cluster using template and parameter files downloaded from an online location 
    import_cluster(vm_metadata)
    start_cluster()

    clean_up()

if __name__ == "__main__":
    try:
        main()
    except:
        print("Deployment failed...")
        raise

