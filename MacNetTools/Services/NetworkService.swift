import Foundation
import SystemConfiguration

/// Retrieves basic network information for the active interface: local IP,
/// subnet mask, router/gateway, MTU, and public IPv4/IPv6 addresses.
/// All blocking System Configuration and socket calls are dispatched to a
/// background GCD queue; it is therefore safe to call from `@unchecked Sendable`
/// contexts without blocking the cooperative thread pool.
class NetworkService: @unchecked Sendable {

    /// Compiles a comprehensive network model for the given interface.
    ///
    /// - Parameter interfaceName: Optional BSD name (e.g., "en0"). If nil, defaults to primary.
    /// - Returns: A `BasicNetModel` containing local and public network state.
    func getBasicNetModel(interfaceName: String? = nil) async -> BasicNetModel?
    {
        // Resolve the interface name or fall back to the primary system interface.
        let name: String
        if let provided = interfaceName {
            name = provided
        } else if let primary = primaryInterfaceName() {
            name = primary
        } else {
            return nil
        }

        // Bridge blocking SystemConfiguration and C ifaddrs work to GCD
        // to prevent saturation of the Swift cooperative thread pool.
        let (addrInfo, networkDetails) = await withCheckedContinuation {
            continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let addr = self.getInterfaceAddressInfo(for: name)
                let details = self.getSystemConfigurationInfo(for: name)
                continuation.resume(returning: (addr, details))
            }
        }

        // Parallel resolution of public IPv4 and IPv6 addresses.
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

    /// Queries SCDynamicStore to identify the current primary network interface.
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
            kSCDynamicStoreGlobalIPv4 as CFString
        ) as? [String: Any],
            let iface = dict[kSCKeyPrimaryInterface] as? String
        {
            return iface
        }
        return nil
    }

    /// Asynchronously fetches the public IP using the specified provider URL.
    private func getPublicIp(apiUrl: String) async -> String? {
        guard let url = URL(string: apiUrl) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(Ipify.self, from: data)
            return result.ip
        } catch {
            return nil
        }
    }

    /// Uses the SystemConfiguration framework to extract the Gateway and MTU.
    ///
    /// MTU is retrieved via `SCNetworkInterfaceCopyMTU`, while the Gateway/Router
    /// is sourced from the global IPv4 state in the dynamic store.
    private func getSystemConfigurationInfo(for interfaceName: String) -> (
        router: String?, mtu: String
    ) {
        var router: String?
        var mtu = kUnknown

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

        // Extract Gateway (Router)
        if let dict = SCDynamicStoreCopyValue(
            dynamicStore,
            kSCDynamicStoreGlobalIPv4 as CFString
        ) as? [String: Any],
            let gateway = dict[kSCKeyRouter] as? String
        {
            router = gateway
        }

        // Extract MTU for the specific BSD interface name
        guard
            let interfaces = SCNetworkInterfaceCopyAll()
                as? [SCNetworkInterface]
        else {
            return (router, mtu)
        }

        for interface in interfaces {
            if let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                bsdName == interfaceName
            {
                var currentMTU: Int32 = 0
                if SCNetworkInterfaceCopyMTU(interface, &currentMTU, nil, nil) {
                    mtu = String(currentMTU)
                }
                break
            }
        }

        return (router, mtu)
    }

    /// Uses the low-level `getifaddrs` C API to retrieve IP and Subnet mask.
    ///
    /// This bypasses high-level frameworks to get raw interface configuration
    /// directly from the network stack. Matches on `AF_INET` for IPv4.
    private func getInterfaceAddressInfo(for interfaceName: String) -> (
        ip: String?, subnet: String?
    ) {
        var address: String?
        var subnet: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (nil, nil)
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addr = interface.ifa_addr.pointee

            // Match IPv4 and the requested BSD interface name (e.g., en0)
            guard addr.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name == interfaceName else { continue }

            // Ensure the interface is operational (IFF_UP)
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0 else { continue }

            // Convert sockaddr to numeric hostname string
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

            // Convert netmask sockaddr to numeric string
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

            if address != nil { break }
        }

        return (address, subnet)
    }
}
