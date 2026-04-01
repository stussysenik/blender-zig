import BlendZigShellCore
import Foundation
import Testing

@Test func documentKindParsesSupportedExtensions() {
    #expect(ShellDocumentKind(url: URL(fileURLWithPath: "/tmp/example.bzrecipe")) == .recipe)
    #expect(ShellDocumentKind(url: URL(fileURLWithPath: "/tmp/example.bzscene")) == .scene)
    #expect(ShellDocumentKind(url: URL(fileURLWithPath: "/tmp/example.bzbundle")) == .bundle)
}

@Test func documentKindRejectsUnsupportedExtensions() {
    #expect(ShellDocumentKind(url: URL(fileURLWithPath: "/tmp/example.obj")) == nil)
}
