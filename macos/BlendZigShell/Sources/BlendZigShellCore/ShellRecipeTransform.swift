import Foundation

public struct ShellRecipeTransformValues: Equatable, Sendable {
    public var scaleX: Double
    public var scaleY: Double
    public var scaleZ: Double
    public var rotateZDegrees: Double
    public var translateX: Double
    public var translateY: Double
    public var translateZ: Double

    public static let identity = Self(
        scaleX: 1.0,
        scaleY: 1.0,
        scaleZ: 1.0,
        rotateZDegrees: 0.0,
        translateX: 0.0,
        translateY: 0.0,
        translateZ: 0.0
    )

    public init(
        scaleX: Double,
        scaleY: Double,
        scaleZ: Double,
        rotateZDegrees: Double,
        translateX: Double,
        translateY: Double,
        translateZ: Double
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.scaleZ = scaleZ
        self.rotateZDegrees = rotateZDegrees
        self.translateX = translateX
        self.translateY = translateY
        self.translateZ = translateZ
    }
}

public struct ShellRecipeTransformState: Equatable, Sendable {
    public let values: ShellRecipeTransformValues
    public let isEditable: Bool
    public let message: String?

    public init(values: ShellRecipeTransformValues, isEditable: Bool, message: String?) {
        self.values = values
        self.isEditable = isEditable
        self.message = message
    }
}
