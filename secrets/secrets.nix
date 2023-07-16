let
  mahene = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJV/MZW0GP6guibA1rNwPwK6Q0WGg1of6MQRMpeqiUR8 mahene";
  users = [ mahene ];
  # NixOS generates a private/public key pair when "services.openssh.enable = true;".
  # Look it up on cat NixOS server "cat /etc/ssh/ssh_host_ed25519_key.pub" after installation.
  hetzner-vps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGIowFj7qGzGuy4tOSCQyiwsj4J7JNTK6+EHDzfMVXWU root@nixos";
  systems = [ hetzner-vps ];
in
{
  "secret1.age".publicKeys = users ++ systems;
}