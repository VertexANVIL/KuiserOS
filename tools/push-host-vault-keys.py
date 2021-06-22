#!/usr/bin/env python3
# Pushes Vault approles for every host in the specified flake path

import io
import hvac
import json
import fabric
import argparse
import tempfile
import subprocess

parser = argparse.ArgumentParser(description="Pushes Vault keys and approles for every host in the specified flake path")
parser.add_argument("-f", "--flake", type=str, default=".", help="Specifies the flake path")
parser.add_argument("-a", "--approles", action="store_true", help="Pushes approles for every specified host")
parser.add_argument("-k", "--keys", action="store_true", help="Pushes external keys for every specified host")
args = parser.parse_args()

# set up clients
vault = hvac.Client()

# modified from https://github.com/fabric/fabric/issues/1750#issuecomment-389990692
def root_install(connection, source, dest, *, owner='root', group='root', mode='0600'):
    """
    Helper which installs a file with arbitrary permissions and ownership

    This is a replacement for Fabric 1's `put(…, use_sudo=True)` and adds the
    ability to set the expected ownership and permissions in one operation.
    """

    # make sure we umask correctly to avoid making the temp file world readable
    with connection.prefix('umask 077'):
        mktemp_result = connection.run('mktemp', hide='out')

    assert mktemp_result.ok
    temp_file = mktemp_result.stdout.strip()

    try:
        connection.put(source, temp_file)
        connection.run(f'doas install -o {owner} -g {group} -m {mode} {temp_file} {dest}')
    finally:
        connection.run(f'rm {temp_file}')

def push_approle(dns: str, role: str):
    # Read the role ID and secret ID from Vault
    prefix = f"auth/approle/role/{role}"
    role_id = vault.read(f"{prefix}/role-id")["data"]["role_id"]
    secret_id = vault.write(f"{prefix}/secret-id")["data"]["secret_id"]

    # Push it to the remote host
    conn = fabric.Connection(dns)

    # Ensure /var/lib/vault-agent exists and is owned by the correct user
    conn.run('doas mkdir -p /var/lib/vault-agent')
    conn.run('doas chmod 0700 /var/lib/vault-agent')
    conn.run('doas chown vault-agent:vault-agent /var/lib/vault-agent')

    # Copy the files
    root_install(conn, io.StringIO(role_id), "/var/lib/vault-agent/role-id", owner="vault-agent", group="vault-agent", mode="0600")
    root_install(conn, io.StringIO(secret_id), "/var/lib/vault-agent/secret-id", owner="vault-agent", group="vault-agent", mode="0600")

def push_keys(dns: str, keys: dict):
    # Connect to the remote host
    conn = fabric.Connection(dns)

    # Push the keys
    for key in keys.values():
        for template in key["templates"]:
            data: bytes

            # Evaluate using consul-template
            with tempfile.NamedTemporaryFile() as f:
                with open(f.name, "wb") as obj:
                    obj.write(template["text"].encode())

                result = subprocess.run(["consul-template", "-template", f"{f.name}:{f.name}", "-once"], capture_output=True)
                result.check_returncode()
                
                with open(f.name, "rb") as obj:
                    data = obj.read().strip()
            
            root_install(conn, io.BytesIO(data), f"{key['folder']}/.{template['id']}.tmp", owner="vault-agent", group="vault-agent", mode="0600")

# find every host
eval_nix = '''
{ lib, nodes }: let
    inherit (lib) filterAttrs mapAttrsToList;
in
    (mapAttrsToList (n: v: let
        cfg = v.config;
        appRole = v.config.services.vault-agent.autoAuth.methods.appRole;
    in {
        role = if (appRole.enable == true) then appRole.name else null;
        dns = "${cfg.networking.hostName}.${cfg.networking.domain}";

        keys = filterAttrs (k: v: v.external == true) cfg.reflection.vault-keys;
    }) nodes)
'''

result = subprocess.run(["colmena", "introspect", "-i", args.flake, "-E", eval_nix], stdout=subprocess.PIPE)
result.check_returncode()

nodes = json.loads(result.stdout)

for node in nodes:
    if args.approles:
        print(f"pushing approle for {node['dns']}")
        try:
            push_approle(node["dns"], node["role"])
        except Exception as e:
            print(f"push failed: {e}")
    if args.keys:
        print(f"pushing external keys for {node['dns']}")
        try:
            push_keys(node["dns"], node["keys"])
        except Exception as e:
            print(f"push failed: {e}")

print("all approles/keys successfully deployed for this flake path")
