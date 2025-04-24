import Testing
import SwiftUI
@testable import Arkyve

@Suite("FormatPickerViewModel Tests")
final class FormatPickerViewModelTests {
    @Test("Initialization without panel")
    func initializationWithoutPanel() {
        let viewModel = FormatPickerViewModel()
        #expect(viewModel.panel == nil)
        #expect(viewModel.format == .ZIP)
    }
    
    @Test("Initialization with panel")
    @MainActor
    func initializationWithPanel() {
        let panel = NSSavePanel()
        let viewModel = FormatPickerViewModel(panel: panel)
        #expect(viewModel.panel === panel)
        #expect(viewModel.format == .ZIP)
    }
    
    @Test("Format setter")
    func formatSetter() {
        let viewModel = FormatPickerViewModel()
        viewModel.format = .TAR
        #expect(viewModel.format == .TAR)
    }
    
    @Test("Environment value")
    func environmentValue() {
        let viewModel = FormatPickerViewModel()
        var environment = EnvironmentValues()
        environment.formatPickerViewModel = viewModel
        #expect(environment.formatPickerViewModel === viewModel)
    }
    
    @Test("Format change updates panel name")
    @MainActor
    func formatChangeUpdatesPanelName() async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "test.zip"
        let viewModel = FormatPickerViewModel(panel: panel)
        
        viewModel.format = .TAR_GNUTAR

        // Wait a short time for the async update to complete
        do {
            try await Task.sleep(for: .milliseconds(100))
        } catch {}
        #expect(panel.nameFieldStringValue == "test.tgz")
    }
} 
