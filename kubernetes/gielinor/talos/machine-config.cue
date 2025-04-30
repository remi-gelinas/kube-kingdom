@jsonschema(schema="https://www.talos.dev/v1.9/schemas/config.schema.json")

#machineType:    string @tag(machine_type)
#isControlPlane: #machineType == "controlplane"

version: "v1alpha1"
debug:   false
persist: true

machine: {
	// type:  #machineType
	token: "op://K8s/talos/MACHINE_TOKEN"

	ca: {
		crt: "op://K8s/talos/MACHINE_CA_CRT"

		if #isControlPlane {
			key: "op://K8s/talos/MACHINE_CA_KEY"
		}
	}

	features: {
		rbac:                 true
		stableHostname:       true
		apidCheckExtKeyUsage: true
		diskQuotaSupport:     true

		kubePrism: {
			enabled: true
			port:    7445
		}

		hostDNS: {
			enabled:              true
			resolveMemberNames:   true
			forwardKubeDNSToHost: false
		}

		if #isControlPlane {
			kubernetesTalosAPIAccess: {
				enabled: true
				allowedRoles: ["os:admin"]
				allowedKubernetesNamespaces: ["system-upgrade"]
			}
		}
	}

	install: {
		extraKernelArgs: [
			"intel_iommu=on",
			"iommu=pt",
		]

		image: "factory.talos.dev/installer-secureboot/c4656257d36b75c5459a556bd4613c94badd08aaecd39734b2901637b5c93b0b:{{ ENV.TALOS_VERSION }}"
		wipe:  false
	}

	kernel: modules: [
		{name: "nbd"},
		{name: "thunderbolt"},
		{name: "thunderbolt_net"},
	]

	files: [{
		op:   "create"
		path: "/etc/cri/conf.d/20-customization.part"
		content: """
			[plugins."io.containerd.grpc.v1.cri".containerd]
			  default_runtime_name = "crun"

			[plugins."io.containerd.cri.v1.images"]
			  discard_unpacked_layers = false
			"""
	}]

	kubelet: {
		image:                               "ghcr.io/siderolabs/kubelet:{{ ENV.KUBERNETES_VERSION }}"
		defaultRuntimeSeccompProfileEnabled: true
		disableManifestsDirectory:           true

		extraConfig: serializeImagePulls: false

		nodeIP: validSubnets: ["192.168.10.0/24"]
	}

	network: {
		nameservers: ["192.168.10.1"]
		disableSearchDomain: true
	}

	nodeLabels: "intel.feature.node.kubernetes.io/gpu": true

	sysctls: {
		"fs.inotify.max_user_watches":   1048576
		"fs.inotify.max_user_instances": 8192
	}

	sysfs: {
		"devices.system.cpu.intel_pstate.hwp_dynamic_boost": 1
		"devices.system.cpu.cpu0.cpuidle.state1.disable":    1
		"devices.system.cpu.cpu0.cpuidle.state2.disable":    1
		"devices.system.cpu.cpu0.cpuidle.state3.disable":    1
	}

	time: {
		disabled: false
		servers: ["time.cloudflare.com"]
	}

	udev: rules: [
		// Thunderbolt
		#"ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1""#,

		// Intel GPU
		#"SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="44", MODE="0660""#,
	]
}

cluster: {
	clusterName: "gielinor"
	id:          "op://K8s/talos/CLUSTER_ID"
	secret:      "op://K8s/talos/CLUSTER_SECRET"
	token:       "op://K8s/talos/CLUSTER_TOKEN"

	controlPlane: endpoint: "https://gielinor.internal:6443"

	ca: {
		crt: "op://K8s/talos/CLUSTER_CA_CRT"

		if #isControlPlane {
			key: "op://K8s/talos/CLUSTER_CA_KEY"
		}
	}

	discovery: {
		enabled: true

		registries: {
			kubernetes: disabled: true
			service: disabled:    true
		}
	}

	network: {
		cni: name: "none"
		dnsDomain: "cluster.local"
		podSubnets: ["10.244.0.0/16"]
		serviceSubnets: ["10.245.0.0/16"]
	}

	if #isControlPlane {
		secretboxEncryptionSecret:      "op://K8s/talos/CLUSTER_SECRETBOXENCRYPTIONSECRET"
		allowSchedulingOnControlPlanes: true

		aggregatorCA: {
			crt: "op://K8s/talos/CLUSTER_AGGREGATORCA_CRT"
			key: "op://K8s/talos/CLUSTER_AGGREGATORCA_KEY"
		}

		serviceAccount: key: "op://K8s/talos/CLUSTER_SERVICEACCOUNT_KEY"

		coreDNS: disabled: true

		proxy: {
			disabled: true
			image:    "registry.k8s.io/kube-proxy:{{ ENV.KUBERNETES_VERSION }}"
		}

		apiServer: {
			image:                    "registry.k8s.io/kube-apiserver:{{ ENV.KUBERNETES_VERSION }}"
			disablePodSecurityPolicy: true
			certSANs: ["k8s.internal"]
			extraArgs: "enable-aggregator-routing": true
		}

		controllerManager: {
			image: "registry.k8s.io/kube-controller-manager:{{ ENV.KUBERNETES_VERSION }}"
			extraArgs: "bind-address": "0.0.0.0"
		}

		etcd: {
			advertisedSubnets: ["192.168.10.0/24"]
			"listen-metrics-urls": "http://0.0.0.0:2381"

			ca: {
				crt: "op://K8s/talos/CLUSTER_ETCD_CA_CRT"
				key: "op://K8s/talos/CLUSTER_ETCD_CA_KEY"
			}
		}

		scheduler: {
			image: "registry.k8s.io/kube-scheduler:{{ ENV.KUBERNETES_VERSION }}"
			extraArgs: "bind-address": "0.0.0.0"

			config: {
				apiVersion: "kubescheduler.config.k8s.io/v1"
				kind:       "KubeSchedulerConfiguration"
				profiles: [
					{
						schedulerName: "default-scheduler"

						plugins: score: disabled: [
							{name: "ImageLocality"},
						]

						pluginConfig: [
							{
								name: "PodTopologySpread"

								args: {
									defaultingType: "list"
									defaultConstraints: [
										{
											maxSkew:           1
											topologyKey:       "kubernetes.io/hostname"
											whenUnsatisfiable: "ScheduleAnyway"
										},
									]
								}
							},
						]
					},
				]
			}
		}
	}
}
