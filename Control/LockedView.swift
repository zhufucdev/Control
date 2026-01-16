import Foundation
import SwiftUI

struct LockedView : View {
    let unlock: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64)
                .foregroundStyle(Color.accentColor)
            Text("Control is locked")
                .font(.headline)
            Button("Unlock", action: unlock)
        }
    }
}

#Preview {
    LockedView {
        // noop
    }
}
