import SwiftUI

/// A text field that automatically formats phone numbers as xxx-xxx-xxxx
struct PhoneTextField: View {
    @Binding var text: String
    var placeholder: String = "Phone Number"
    
    var body: some View {
        TextField(placeholder, text: Binding(
            get: { text },
            set: { newValue in
                // Only allow digits
                let digits = newValue.filter { $0.isNumber }
                
                // Format with dashes for display
                if digits.count <= 10 {
                    var formattedNumber = ""
                    for (index, digit) in digits.enumerated() {
                        // Add dash after area code (3 digits)
                        if index == 3 {
                            formattedNumber.append("-")
                        }
                        // Add dash after first 6 digits
                        else if index == 6 {
                            formattedNumber.append("-")
                        }
                        formattedNumber.append(digit)
                    }
                    text = formattedNumber
                }
            }
        ))
        .textContentType(.telephoneNumber)
        .keyboardType(.phonePad)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var phoneNumber = "5551234567"
        
        var body: some View {
            PhoneTextField(text: $phoneNumber)
                .padding()
        }
    }
    
    return PreviewWrapper()
}
