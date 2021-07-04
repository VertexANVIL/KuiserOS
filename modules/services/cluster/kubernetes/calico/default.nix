{ config, lib, pkgs, ... }:

with lib;

let
    top = config.services.kubernetes;
    cfg = top.calico;

    kubeconfig = top.lib.mkKubeConfig "calico-node" cfg.kubeconfig;
in
{
    ###### interface
    options.services.kubernetes.calico = {
        enable = mkEnableOption "enable calico networking";
        kubeconfig = top.lib.mkKubeConfigOptions "Calico CNI";
    };

    ###### implementation
    config = mkIf cfg.enable {
        services.calico = {
            inherit kubeconfig;

            enable = mkDefault true;
            network = mkDefault top.clusterCidr;
            nodeName = config.services.kubernetes.kubelet.hostname;

            # we want calico to use kubernetes itself as configuration backend, not direct etcd
            storageBackend = "kubernetes";
        };

        services.kubernetes.kubelet = {
            networkPlugin = mkDefault "cni";
            cni.config = mkDefault [
                {
                    type = "calico";
                    log_level = "info";
                    datastore_type = "kubernetes";
                    mtu = 1500;
                    ipam.type = "calico-ipam";
                    policy.type = "k8s";
                    kubernetes.kubeconfig = kubeconfig;
                }
                {
                    type = "portmap";
                    snat = true;
                    capabilities.portMappings = true;
                }
            ];
        };

        networking = {
            firewall.allowedUDPPorts = [
                179   # calico BGP
                5473  # calico typha
                8285  # calico udp
                8472  # calico vxlan
            ];
            dhcpcd.denyInterfaces = [ "mynet*" "calico*" ];
        };

        services.kubernetes.pki.certs = {
            calicoNode = top.lib.mkCert {
                name = "calico-node";
                CN = "calico-node";
                action = "systemctl restart calico-node.service";
            };
        };

        # give calico some kubernetes rbac permissions if applicable
        services.kubernetes.addonManager.bootstrapAddons = mkIf (elem "RBAC" top.apiserver.authorizationMode) {
            calico-node-cr = {
                kind = "ClusterRole";
                apiVersion = "rbac.authorization.k8s.io/v1";
                metadata = { name = "calico-node"; };
                rules = [
                    {
                        apiGroups = [ "" ];
                        resources = [ "endpoints" "services" ];
                        verbs = [
                            # Used to discover service IPs for advertisement.
                            "watch"
                            "list"
                            
                            # Used to discover Typhas.
                            "get"
                        ];
                    }
                    {
                        # Pod CIDR auto-detection on kubeadm needs access to config maps.
                        apiGroups = [ "" ];
                        resources = [ "configmaps" ];
                        verbs = [ "get" ];
                    }
                    {
                        apiGroups = [ "" ];
                        resources = [ "nodes/status" ];
                        verbs = [
                            # Needed for clearing NodeNetworkUnavailable flag.
                            "patch"

                            # Calico stores some configuration information in node annotations.
                            "update"
                        ];
                    }
                    {
                        apiGroups = [ "crd.projectcalico.org" ];
                        resources = [
                            "globalfelixconfigs"
                            "felixconfigurations"
                            "bgppeers"
                            "globalbgpconfigs"
                            "bgpconfigurations"
                            "ippools"
                            "ipamblocks"
                            "globalnetworkpolicies"
                            "globalnetworksets"
                            "networkpolicies"
                            "clusterinformations"
                            "hostendpoints"
                            "blockaffinities"
                            "networksets"
                        ];
                        verbs = [ "get" "list" "watch" ];
                    }
                    {
                        # Calico must create and update some CRDs on startup.
                        apiGroups = [ "crd.projectcalico.org" ];
                        resources = [
                            "ippools"
                            "felixconfigurations"
                            "clusterinformations"
                        ];
                        verbs = [ "create" "update" ];
                    }
                    {
                        # Calico stores some configuration information on the node.
                        apiGroups = [ "" ];
                        resources = [ "nodes" ];
                        verbs = [ "get" "list" "watch" ];
                    }
                    {
                        apiGroups = [ "crd.projectcalico.org" ];
                        resources = [ "ipamconfigs" ];
                        verbs = [ "get" ];
                    }
                    {
                        # Block affinities must also be watchable by confd for route aggregation.
                        apiGroups = [ "crd.projectcalico.org" ];
                        resources = [ "blockaffinities" ];
                        verbs = [ "watch" ];
                    }
                ];
            };

            calico-node-crb = {
                apiVersion = "rbac.authorization.k8s.io/v1";
                kind = "ClusterRoleBinding";
                metadata = { name = "calico-node"; };
                roleRef = {
                    apiGroup = "rbac.authorization.k8s.io";
                    kind = "ClusterRole";
                    name = "calico-node";
                };
                subjects = [{
                    kind = "User";
                    name = "calico-node";
                }];
            };
        };

        services.kubernetes.calico.kubeconfig = with top.pki.certs.calicoNode; {
            server = mkDefault top.apiserverAddress;

            # must define these here as we can't modify pki.nix
            certFile = mkDefault cert;
            keyFile = mkDefault key;
        };
    };
}
