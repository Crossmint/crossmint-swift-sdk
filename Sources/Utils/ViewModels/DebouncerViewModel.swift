import Combine
import Foundation

public class DebouncerViewModel<T: Equatable>: ObservableObject {
    @Published public private(set) var liveValue: T
    @Published public private(set) var debouncedValue: T

    private var cancellables = Set<AnyCancellable>()
    private var delay: TimeInterval

    /// Main initializer that configures automatic binding
    /// - Parameters:
    ///   - sourcePublisher: Publisher that emits values to be debounced
    ///   - destinationBinding: Closure that receives the debounced values
    ///   - initialValue: Initial value for both live and debounced values
    ///   - delay: Debounce delay in seconds
    public init(
        sourcePublisher: AnyPublisher<T, Never>,
        destinationBinding: @escaping (T) -> Void,
        initialValue: T,
        delay: TimeInterval
    ) {
        self.liveValue = initialValue
        self.debouncedValue = initialValue
        self.delay = delay

        setupDebounce()

        // Connect the source publisher to liveValue
        sourcePublisher
            .sink { [weak self] newValue in
                self?.liveValue = newValue
            }
            .store(in: &cancellables)

        // Connect debouncedValue to the destination
        $debouncedValue
            .sink(receiveValue: destinationBinding)
            .store(in: &cancellables)
    }

    /// Simplified initializer that doesn't require publishers
    /// - Parameters:
    ///   - initialValue: Initial value for both live and debounced values
    ///   - delay: Debounce delay in seconds
    public init(initialValue: T, delay: TimeInterval) {
        self.liveValue = initialValue
        self.debouncedValue = initialValue
        self.delay = delay

        setupDebounce()
    }

    private func setupDebounce() {
        $liveValue
            .removeDuplicates()
            .debounce(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.debouncedValue = value
            }
            .store(in: &cancellables)
    }

    public func updateLiveValue(_ newValue: T) {
        liveValue = newValue
    }
}
