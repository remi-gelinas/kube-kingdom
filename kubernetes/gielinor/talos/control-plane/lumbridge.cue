package lumbridge

import (
	"encoding/yaml"
	commonConfig "kubek.ing/kubernetes/gielinor/talos:config"
)

yaml.MarshalStream([commonConfig & {
	#config: type: "controlplane"

	machine: network: {
		hostname: "lumbridge.gielinor.internal"
		interfaces: [{
			deviceSelector: busPath: "0 - 1.0"
			dhcp: false
			mtu:  65520
			addresses: ["fe80::0000:0000:0000:0002/128"]
			routes: [
				// Falador
				{
					network: "fe80::0000:0000:0000:0001/128"
					metric:  2048
					gateway: ""
				},

				// Varrock
				{
					network: "fe80::0000:0000:0000:0003/128"
					metric:  2048
					gateway: ""
				},
			]
		}]
	}
}])
