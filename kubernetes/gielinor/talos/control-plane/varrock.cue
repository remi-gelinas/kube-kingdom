machine: {
	install: diskSelector: ""

	network: {
		hostname: "varrock.gielinor.internal"

		interfaces: [
			{
				deviceSelector: busPath: "0 - 1.0"
				dhcp: false
				mtu:  65520
				addresses: ["169.254.255.10/32"]
				routes: [
					{
						network: "169.254.255.12/32"
						metric:  2048
					},
				]
			},
		]
	}
}
