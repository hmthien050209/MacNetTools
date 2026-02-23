import CoreWLAN
import SystemConfiguration
import Foundation

class CoreWLANService {
    func getWiFiModel(interfaceName: String? = nil) -> WiFiModel? {
        let client = CWWiFiClient.shared()
        
        guard let interface = interfaceName.flatMap({ client.interface(withName: $0) }) ?? client.interface() else {
            return nil
        }
       
        // Additional calculations
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let signalNoiseRatio = rssi - noise
        
        // Roaming stuff
        // Currently returning blank arrays
        // TODO: map available BSSIDs to the same SSIDs
        
        return WiFiModel(
            ssid: interface.ssid() ?? kUnknown,
            connectedBssid: interface.bssid() ?? kUnknown,
            channel: interface.wlanChannel(),
            phyMode: interface.activePHYMode(),
            security: interface.security(),
            rssi: rssi,
            noise: noise,
            signalNoiseRatio: signalNoiseRatio,
            countryCode: interface.countryCode() ?? kUnknown,
            availableBssids: [],
            txRateMbps: interface.transmitRate(),
            interfaceName: interface.interfaceName
        )
    }

    func getBasicNetModel(interfaceName: String? = nil) -> BasicNetModel? {
        let client = CWWiFiClient.shared()
        
        guard let interface = interfaceName.flatMap({ client.interface(withName: $0) }) ?? client.interface(),
              let name = interface.interfaceName else {
            return nil
        }

        let addrInfo = getInterfaceAddressInfo(for: name)
        let networkDetails = getSystemConfigurationInfo(for: name)

        return BasicNetModel(
            mtu: networkDetails.mtu,
            localIp: addrInfo.ip ?? "0.0.0.0",
            routerIp: networkDetails.router ?? "0.0.0.0",
            subnetMask: addrInfo.subnet ?? "255.255.255.0",
            publicIpV4: "", // TODO
            publicIpV6: ""  // TODO
        )
    }

    // MARK: - Helpers

    /// Uses System Configuration to find the Gateway (Router) and MTU
    private func getSystemConfigurationInfo(for interfaceName: String) -> (router: String?, mtu: String) {
        var router: String?
        var mtu = "1500" // Standard default
        
        let dynamicStore = SCDynamicStoreCreate(nil, "WiFiApp" as CFString, nil, nil)
        
        // Get Router/Gateway
        if let dict = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let gateway = dict["Router"] as? String {
            router = gateway
        }
        
        // Get MTU
        if let dict = SCDynamicStoreCopyValue(dynamicStore, "Setup:/Network/Interface/\(interfaceName)/Ethernet" as CFString) as? [String: Any],
           let mtuVal = dict["MTU"] as? Int {
            mtu = "\(mtuVal)"
        }
        
        return (router, mtu)
    }

    /// Uses low-level C API getifaddrs to find IP and Subnet
    private func getInterfaceAddressInfo(for interfaceName: String) -> (ip: String?, subnet: String?) {
        var address: String?
        var subnet: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (nil, nil) }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let name = String(cString: ptr.pointee.ifa_name)
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            // Check for IPv4 and match interface name
            if addr.sa_family == UInt8(AF_INET) && name == interfaceName {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    address = String(cString: hostname)
                }
                
                // Get Subnet Mask
                if let netmask = ptr.pointee.ifa_netmask {
                    var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &netmaskName, socklen_t(netmaskName.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        subnet = String(cString: netmaskName)
                    }
                }
            }
        }
        
        return (address, subnet)
    }
}
