import json
import argparse
import os
import subprocess

def run_mount_script(json_data):
    account_names = json_data.get("StorageAccountName", [])[0]
    account_keys = json_data.get("StorageAccountKey", [])[0]
    fileshares = json_data.get("FileshareName", [])[0]

    # Match them by index
    for name, key, share in zip(account_names, account_keys, fileshares):
        cred_dir = "/etc/smbcredentials"
        cred_file = f"{cred_dir}/{name}.cred"
        mount_point = f"/projectrepos/{share}"
        remote_path = f"//{name}.file.core.windows.net/{share}"

        print(f"Creating credential file for {name}...")

        os.makedirs(cred_dir, exist_ok=True)
        with open(cred_file, "w") as f:
            f.write(f"username={name}\npassword={key}\n")

        os.chmod(cred_file, 0o600)

        print(f"Creating mount point at {mount_point}...")
        os.makedirs(mount_point, exist_ok=True)

        mount_cmd = [
            "sudo", "mount", "-t", "cifs", remote_path, mount_point,
            "-o", f"vers=3.1.1,credentials={cred_file},dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30,auto,mfsymlinks,_netdev"
        ]

        print(f"Mounting {remote_path} to {mount_point}...")
        try:
            subprocess.run(mount_cmd, check=True)
            print(f"Mounted {remote_path} successfully.")
        except subprocess.CalledProcessError as e:
            print(f"Error mounting {remote_path}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Mount Azure file shares using JSON input")
    parser.add_argument('--input', required=True, help='Path to processed JSON file')
    args = parser.parse_args()

    with open(args.input, "r") as f:
        data = json.load(f)

    run_mount_script(data)

if __name__ == "__main__":
    main()
