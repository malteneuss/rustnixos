({ pkgs, config, ... }: {
            networking.firewall.allowedTCPPorts = [ 80 443 ];
            services.rustnixos.enable = true;

            services = {
              caddy = {
                enable = true;
#                acmeCA =
#                  "https://acme-staging-v02.api.letsencrypt.org/directory";
                globalConfig = ''
                  #                        debug
                  #                         auto_https disable_certs
                                          skip_install_trust
                  #                         http_port 8080
                  #                         https_port 8090

                '';
                # Test with curl
                # curl --connect-to localhost:80:mycontainer:80 --connect-to localhost:443:mycontainer:443 http://localhost -k -L
                virtualHosts = {
                  "localhost".extraConfig = ''
                    #           respond "Hello, world34!"
                     reverse_proxy http://127.0.0.1:${toString config.services.rustnixos.port}
                  '';
                  "workler.de".extraConfig = ''
                     reverse_proxy http://127.0.0.1:${toString config.services.rustnixos.port}
                  '';
                };
              };
            };
          })