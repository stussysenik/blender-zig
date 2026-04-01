struct ShellOperationState {
    private(set) var generation: UInt64 = 0

    mutating func nextGeneration() -> UInt64 {
        generation += 1
        return generation
    }

    func contains(_ generation: UInt64) -> Bool {
        self.generation == generation
    }
}
