import SwiftUI

extension ToolbarItemPlacement {
    static var appTopBarTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

extension SearchFieldPlacement {
    static var appNavigationDrawer: SearchFieldPlacement {
        #if os(iOS)
        .navigationBarDrawer(displayMode: .always)
        #else
        .automatic
        #endif
    }
}
