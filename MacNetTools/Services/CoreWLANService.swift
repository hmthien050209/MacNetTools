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
    
    func getBasicNetModel(interfaceName: String? = nil) async -> BasicNetModel? {
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
            publicIpV4: await getPublicIp(apiUrl: kIpifyV4Url) ?? "",
            publicIpV6: await getPublicIp(apiUrl: kIpifyV6Url) ?? "",
        )
    }
    
    // MARK: - Helpers
    
    private func getPublicIp(apiUrl: String) async -> String? {
        guard let url = URL(string: apiUrl) else { return nil }
        
        do {
            // Fetch data
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Decode JSON
            let result = try JSONDecoder().decode(Ipify.self, from: data)
            return result.ip
        } catch {
            print("Failed to fetch IP: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Uses System Configuration to find the Gateway (Router) and MTU
    private func getSystemConfigurationInfo(for interfaceName: String) -> (router: String?, mtu: String) {
        var router: String?
        var mtu = "Unknown"
        
        guard let dynamicStore = SCDynamicStoreCreate(nil, "MacNetTools" as CFString, nil, nil) else {
            return (nil, mtu)
        }
        
        // 1. Get Router/Gateway (Global IPv4 State)
        if let dict = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let gateway = dict["Router"] as? String {
            router = gateway
        }
        
        // 2. Get MTU for the specific interface
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return (router, mtu) // Safely fallback to returning what we have so far
        }
        
        for interface in interfaces {
            // Compare the interface's BSD name (e.g., "en0") to the requested interfaceName
            if let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?, bsdName == interfaceName {
                
                var currentMTU: Int32 = 0
                
                // SCNetworkInterfaceCopyMTU returns a Bool and populates our currentMTU reference
                if SCNetworkInterfaceCopyMTU(interface, &currentMTU, nil, nil) {
                    mtu = String(currentMTU)
                }
                
                break // Exit the loop once the target interface is found and processed
            }
        }
        
        return (router, mtu)
    }
    
    /// Uses low-level C API getifaddrs to find IP and Subnet
    private func getInterfaceAddressInfo(for interfaceName: String) -> (ip: String?, subnet: String?) {
        var address: String?
        var subnet: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        // Retrieve the current interfaces - returns 0 on success
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (nil, nil) }
        
        // Ensure memory is freed when the function returns
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addr = interface.ifa_addr.pointee
            
            // Check for IPv4 (AF_INET)
            guard addr.sa_family == UInt8(AF_INET) else { continue }
            
            // Match the interface name (e.g., "en0")
            let name = String(cString: interface.ifa_name)
            guard name == interfaceName else { continue }
            
            // Ensure the interface is UP and RUNNING
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0 else { continue }
            
            // Get the IP Address
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(interface.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                address = String(cString: hostname)
            }
            
            // Get the Subnet Mask
            if let netmask = interface.ifa_netmask {
                var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &netmaskName, socklen_t(netmaskName.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    subnet = String(cString: netmaskName)
                }
            }
            
            // Break early if we found a valid active address to avoid duplicates
            if address != nil { break }
        }
        
        return (address, subnet)
    }
}
