import Foundation
import SystemConfiguration

/// Retrieves basic network information for the active interface: local IP,
/// subnet mask, router/gateway, MTU, and public IPv4/IPv6 addresses.
/// All blocking System Configuration and socket calls are dispatched to a
/// background GCD queue; it is therefore safe to call from `@unchecked Sendable`
/// contexts without blocking the cooperative thread pool.
class NetworkService: @unchecked Sendable {

    func getBasicNetModel(interfaceName: String? = nil) async -> BasicNetModel?
    {
        // Resolve the interface name: use the supplied value, or fall back to
        // the primary interface reported by SystemConfiguration.
        let name: String
        if let provided = interfaceName {
            name = provided
        } else if let primary = primaryInterfaceName() {
            name = primary
        } else {
            return nil
        }

        // Move blocking SystemConfiguration and ifaddrs work to a background
        // GCD queue to avoid blocking the Swift cooperative thread pool
        let (addrInfo, networkDetails) = await withCheckedContinuation {
            (
                continuation: CheckedContinuation<
                    (
                        (ip: String?, subnet: String?),
                        (router: String?, mtu: String)
                    ), Never
                >
            ) in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let addr = self.getInterfaceAddressInfo(for: name)
                let details = self.getSystemConfigurationInfo(for: name)
                continuation.resume(returning: (addr, details))
            }
        }

        // Run public IP lookups in parallel (non-blocking async network calls)
        async let ipV4 = getPublicIp(apiUrl: kIpifyV4Url)
        async let ipV6 = getPublicIp(apiUrl: kIpifyV6Url)

        return BasicNetModel(
            mtu: networkDetails.mtu,
            localIp: addrInfo.ip ?? "0.0.0.0",
            routerIp: networkDetails.router ?? "0.0.0.0",
            subnetMask: addrInfo.subnet ?? "255.255.255.0",
            publicIpV4: await ipV4 ?? "",
            publicIpV6: await ipV6 ?? "",
        )
    }

    // MARK: - Private helpers

    /// Returns the name of the current primary network interface using
    /// SystemConfiguration, without requiring CoreWLAN.
    private func primaryInterfaceName() -> String? {
        guard
            let store = SCDynamicStoreCreate(
                nil,
                "MacNetTools" as CFString,
                nil,
                nil
            )
        else { return nil }

        if let dict = SCDynamicStoreCopyValue(
            store,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any],
            let iface = dict["PrimaryInterface"] as? String
        {
            return iface
        }
        return nil
    }

    /// Get our public IP from the specified API provider (via API URL)
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
    private func getSystemConfigurationInfo(for interfaceName: String) -> (
        router: String?, mtu: String
    ) {
        var router: String?
        var mtu = "Unknown"

        guard
            let dynamicStore = SCDynamicStoreCreate(
                nil,
                "MacNetTools" as CFString,
                nil,
                nil
            )
        else {
            return (nil, mtu)
        }

        // Get Router/Gateway (Global IPv4 State)
        if let dict = SCDynamicStoreCopyValue(
            dynamicStore,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any],
            let gateway = dict["Router"] as? String
        {
            router = gateway
        }

        // Get MTU for the specific interface
        guard
            let interfaces = SCNetworkInterfaceCopyAll()
                as? [SCNetworkInterface]
        else {
            return (router, mtu)  // Safely fallback to returning what we have so far
        }

        for interface in interfaces {
            // Compare the interface's BSD name (e.g., "en0") to the requested interfaceName
            if let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                bsdName == interfaceName
            {
                var currentMTU: Int32 = 0

                // SCNetworkInterfaceCopyMTU returns a Bool and populates our currentMTU reference
                if SCNetworkInterfaceCopyMTU(interface, &currentMTU, nil, nil) {
                    mtu = String(currentMTU)
                }

                break  // Exit the loop once the target interface is found and processed
            }
        }

        return (router, mtu)
    }

    /// Uses low-level C API getifaddrs to find IP and Subnet
    private func getInterfaceAddressInfo(for interfaceName: String) -> (
        ip: String?, subnet: String?
    ) {
        var address: String?
        var subnet: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        // Retrieve the current interfaces - returns 0 on success
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (nil, nil)
        }

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
            if getnameinfo(
                interface.ifa_addr,
                socklen_t(addr.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
            }

            // Get the Subnet Mask
            if let netmask = interface.ifa_netmask {
                var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    netmask,
                    socklen_t(netmask.pointee.sa_len),
                    &netmaskName,
                    socklen_t(netmaskName.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST
                ) == 0 {
                    subnet = String(cString: netmaskName)
                }
            }

            // Break early if we found a valid active address to avoid duplicates
            if address != nil { break }
        }

        return (address, subnet)
    }
}
