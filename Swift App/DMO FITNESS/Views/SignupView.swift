import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct SignupView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    
    @AppStorage("uid") var userID: String = ""
    @Binding var currentShowingView: String
    
    private func createUser() {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print(error)
                return
            }
            
            if let authResult = authResult {
                userID = authResult.user.uid
                saveExtraInfo(authResult.user.uid)
            }
        }
    }

    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = NSPredicate(format: "SELF MATCHES %@", "^(?=.*[a-z])(?=.*[$@$#!%*?&])(?=.*[A-Z]).{6,}$")
        return passwordRegex.evaluate(with: password)
    }

    private func saveExtraInfo(_ uid: String) {
        let isDoctor = email.lowercased() == "omar.salem@dmo.com"
        let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
        let ref = Database.database(url: databaseURL).reference()
        
        // User data
        ref.child("users").child(uid).setValue([
            "firstName": firstName,
            "lastName": lastName,
            "phoneNumber": phoneNumber,
            "weightProgress": [],
            "targetWeight": "",
            "isDoctor": isDoctor,
            "diet": "",
            "points": 0
        ])
        
        let defaultMilestoneWeight = 0.0
        let defaultMilestonePoints = 0  
        ref.child("milestones").child(uid).setValue([
            "milestoneWeight": defaultMilestoneWeight,
            "awardPoints": defaultMilestonePoints
        ])
        
        if !isDoctor {
            ref.child("chats").child(uid).child("messages").setValue([])
        }
    }


    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // User Interface Components
                createTitle()
                createFields()
                createLoginLink()
                createNewAccountButton()
            }
        }
    }
    
    private func createTitle() -> some View {
        return HStack {
            Text("Create an Account!")
                .foregroundColor(.white)
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .padding()
        .padding(.top)
    }
    
    private func createFields() -> some View {
        return VStack {
            customTextField(imageName: "mail", placeholder: "Email", text: $email, isValid: email.isValidEmail())
            customTextField(imageName: "lock", placeholder: "Password", text: $password, isValid: isValidPassword(password), isSecure: true)
            customTextField(imageName: "person", placeholder: "First Name", text: $firstName)
            customTextField(imageName: "person", placeholder: "Last Name", text: $lastName)
            customTextField(imageName: "phone", placeholder: "Phone Number", text: $phoneNumber, isValid: isValidPhoneNumber(phoneNumber))
        }
    }
    
    private func createLoginLink() -> some View {
        return Button(action: {
            withAnimation {
                self.currentShowingView = "login"
            }
        }) {
            Text("Already have an account?")
                .foregroundColor(.gray)
        }
    }
    
    private func createNewAccountButton() -> some View {
        return Button(action: createUser) {
            Text("Create New Account")
                .foregroundColor(.black)
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .padding(.horizontal)
        }
    }
    
    private func customTextField(imageName: String, placeholder: String, text: Binding<String>, isValid: Bool = true, isSecure: Bool = false) -> some View {
        return HStack {
            Image(systemName: imageName)
                .foregroundColor(.white)
            if isSecure {
                SecureField(placeholder, text: text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: text)
                    .foregroundColor(.white)
            }
            Spacer()

            if text.wrappedValue.count != 0 {
                Image(systemName: isValid ? "checkmark" : "xmark")
                    .foregroundColor(isValid ? .green : .red)
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(lineWidth: 2).foregroundColor(.white))
        .padding(.horizontal)
    }
    
    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneNumberRegex = "^(01)[0-9]{9}$"
        let valid = NSPredicate(format: "SELF MATCHES %@", phoneNumberRegex).evaluate(with: phoneNumber)
        return valid
    }
}


