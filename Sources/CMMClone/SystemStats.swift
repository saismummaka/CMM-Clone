import Foundation
import Combine
import Darwin

@MainActor
final class SystemStats: ObservableObject {
    @Published var memoryUsedGB: Double = 0
    @Published var memoryTotalGB: Double = 0
    @Published var memoryFreeGB: Double = 0
    @Published var memoryPressure: Double = 0  // 0...1
    @Published var diskUsedGB: Double = 0
    @Published var diskTotalGB: Double = 0

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        updateMemory()
        updateDisk()
    }

    private func updateMemory() {
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }
        let pageSize = Double(vm_kernel_page_size)

        let free = Double(stats.free_count) * pageSize
        let active = Double(stats.active_count) * pageSize
        let inactive = Double(stats.inactive_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize

        let used = active + wired + compressed
        let gb = 1024.0 * 1024.0 * 1024.0

        memoryTotalGB = total / gb
        memoryUsedGB = used / gb
        memoryFreeGB = (free + inactive) / gb
        memoryPressure = min(1.0, max(0.0, used / total))
    }

    private func updateDisk() {
        let path = "/"
        do {
            let values = try URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = Double(values.volumeTotalCapacity ?? 0)
            let available = Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let gb = 1024.0 * 1024.0 * 1024.0
            diskTotalGB = total / gb
            diskUsedGB = (total - available) / gb
        } catch {
            // ignore
        }
    }
}
