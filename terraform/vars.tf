variable "ssh_user" {
    default = "user"
}

variable "ssh_password" {
    default = "Password123"
}

variable "pm_user" {
    # Remember to include realm in username - user@realm
    default = "root@pam"
}

variable "pm_password" {
    default = "Password123"
}

variable "pm_api_token_id" {
    # api token id is in the form of: <username>@pam!<tokenId>
    default = "root@pam!YourTokenId"
} 

variable "pm_api_token_secret" {
    # this is the full secret wrapped in quotes:
    default = "token-secret-here"
}

variable "pm_api_url" {
    # proxmox cluster api url
    default = "https://192.168.5.224:8006/api2/json"
}
