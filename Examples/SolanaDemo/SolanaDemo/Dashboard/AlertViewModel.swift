import SwiftUI

class AlertViewModel: ObservableObject {
    struct Data {
        let title: String
        let message: String
    }

    @Published var data: Data?

    var isPresented: Binding<Bool> {
        .init {
            self.data != nil
        } set: { isPresented in
            if !isPresented {
                self.data = nil
            }
        }
    }

    var title: String {
        data?.title ?? ""
    }

    var message: String {
        data?.message ?? ""
    }

    func show(title: String, message: String) {
        data = Data(title: title, message: message)
    }
}
