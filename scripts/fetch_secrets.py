"""
Runs on the backend VMSS instance at boot (via cloud-init).
Uses the VM's System-Assigned Managed Identity — no credentials stored anywhere.
Prints an .env file to stdout, which cloud-init redirects into place.
"""
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = "https://kv-jobtrackr-atharva01.vault.azure.net/"  

credential = ManagedIdentityCredential()
client = SecretClient(vault_url=VAULT_URL, credential=credential)

db_password = client.get_secret("mysql-admin-password").value
db_host = client.get_secret("mysql-host").value

print("DB_USER=mysqladmin")
print(f"DB_PASSWORD={db_password}")
print(f"DB_HOST={db_host}")
print("DB_NAME=jobtrackr")
