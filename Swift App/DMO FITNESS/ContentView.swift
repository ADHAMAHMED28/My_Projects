import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import Charts

struct ContentView: View {
    @AppStorage("uid") var userID: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var weightProgress: [Double] = []
    @State private var isDoctor: Bool = false
    @State private var selectedTab = 0
    @State private var isLoadingUserData: Bool = true
    @State private var targetWeight: Double = 0.0
    @State private var dietIdForCurrentUser: String = ""
    @State private var showingSignOutActionSheet: Bool = false
    @State private var points: Int = 0
    @State private var pointsInput: String = ""

    var body: some View {
        if userID == "" {
            AuthView()
        } else {
            if isDoctor {
                DoctorView()
            } else {
                TabView(selection: $selectedTab) {
                    homeView
                        .tabItem {
                            Image(systemName: "house.fill")
                        }
                        .tag(0)
                    
                    DietView(dietId: dietIdForCurrentUser)
                        .tabItem {
                            Image(systemName: "leaf.arrow.circlepath")
                        }
                        .tag(1)
                    
                    WorkingHoursView()
                        .tabItem {
                            Image(systemName: "calendar")
                        }
                        .tag(2)

                    AboutUsView()
                        .tabItem {
                            Image(systemName: "info.circle")
                        }
                        .tag(3)

                    ChatView(userUID: userID)
                        .tabItem {
                            Image(systemName: "message")
                        }
                        .tag(4)

                    signOutButton().tag(5)
                }

                .accentColor(Color.purple)
            }
        }
    }

    var homeView: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color.purple, Color.white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Hello, \(firstName) \(lastName)!")
                            .bold()
                            .font(.custom("Avenir", size: 22))
                            .foregroundColor(.white)
                            .shadow(radius: 3)

                        Text("Points: \(points)")
                            .font(.custom("Avenir", size: 18))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding(.leading)

                    Spacer()

                    Image("DMOLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                }
                .padding([.top, .horizontal])

                if isLoadingUserData {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if weightProgress.isEmpty {
                    Text("Book your first consultation to get started!")
                        .font(.custom("Avenir", size: 18))
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                } else {
                    if Locale.current.languageCode == "ar" {
                        LineView(data: weightProgress, title: "تقدم الوزن", legend: "أنت تقوم بعمل رائع!")
                            .frame(height: 250)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(15)
                            .shadow(radius: 10)
                    } else {
                        LineView(data: weightProgress, title: "Weight Progress", legend: "You're doing a great job!")
                            .frame(height: 250)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(15)
                            .shadow(radius: 10)
                    }
                }


                if !weightProgress.isEmpty {
                    weightDetails
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(15)
                        .shadow(radius: 10)
                }
                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadUserData()
        }
    }


    var weightDetails: some View {
        let currentWeight = weightProgress.last ?? 0
        let remainingWeight = currentWeight - targetWeight

        return VStack {
            HStack {
                Text("Current Weight:")
                    .font(.custom("Avenir", size: 18))
                    .bold()
                Spacer()
                Text("\(currentWeight, specifier: "%.1f") kg")
                    .font(.custom("Avenir", size: 16))
                    .foregroundColor(.black)
            }
            .padding([.horizontal, .top])

            HStack {
                Text("Remaining Weight:")
                    .font(.custom("Avenir", size: 18))
                    .bold()
                Spacer()
                Text("\(remainingWeight, specifier: "%.1f") kg")
                    .font(.custom("Avenir", size: 16))
                    .foregroundColor(remainingWeight > 0 ? .red : .green)
            }
            .padding([.horizontal, .bottom])
        }
        .environment(\.colorScheme, .light)
    }


    private func buttonView(image: String) -> some View {
        VStack {
            Image(systemName: image)
                .resizable()
                .frame(width: 24, height: 24)
        }
        .tabItem {
            Image(systemName: image)
        }
    }

    private func signOutButton() -> some View {
        Button(action: {
            self.showingSignOutActionSheet = true
        }) {
            VStack {
                Image(systemName: "arrow.right.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
        .tabItem {
            Image(systemName: "arrow.right.circle.fill")
        }
        .actionSheet(isPresented: $showingSignOutActionSheet) {
            ActionSheet(title: Text("Sign Out"),
                        message: Text("Do you want to sign out?"),
                        buttons: [
                            .destructive(Text("Sign Out")) {
                                signOutUser()
                            },
                            .cancel()
                        ])
        }
    }
    
    private func signOutUser() {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            DispatchQueue.main.async {
                withAnimation {
                    userID = ""
                }
            }
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }




    private func loadUserData() {
        isLoadingUserData = true
        guard !userID.isEmpty else {
            isLoadingUserData = false
            return
        }

        let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
        let ref = Database.database(url: databaseURL).reference().child("users").child(userID)

        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userData = snapshot.value as? [String: AnyObject] {
                firstName = userData["firstName"] as? String ?? ""
                lastName = userData["lastName"] as? String ?? ""
                weightProgress = userData["weightProgress"] as? [Double] ?? []
                isDoctor = userData["isDoctor"] as? Bool ?? false
                targetWeight = Double(userData["targetWeight"] as? String ?? "") ?? 0.0
                dietIdForCurrentUser = userData["diet"] as? String ?? ""
                points = userData["points"] as? Int ?? 0 // Fetch the points attribute
            }
            isLoadingUserData = false
        }) { (error) in
            print("Error fetching user data: \(error.localizedDescription)")
            isLoadingUserData = false
        }
    }


}

import SwiftUI
import FirebaseDatabase
import FirebaseAuth

class DoctorViewModel: ObservableObject {
    @Published var showAlert = false
    @Published var selectedDays: [String: Bool] = [
        "Monday": false,
        "Tuesday": false,
        "Wednesday": false,
        "Thursday": false,
        "Friday": false,
        "Saturday": false,
        "Sunday": false
    ]
    
    @Published var workingHours: [String: (start: Date, end: Date)] = [
        "Monday": (start: Date(), end: Date()),
        "Tuesday": (start: Date(), end: Date()),
        "Wednesday": (start: Date(), end: Date()),
        "Thursday": (start: Date(), end: Date()),
        "Friday": (start: Date(), end: Date()),
        "Saturday": (start: Date(), end: Date()),
        "Sunday": (start: Date(), end: Date())
    ]
    
    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
    var userID: String = Auth.auth().currentUser?.uid ?? ""

    func saveWorkingHours() {
        let ref = Database.database(url: databaseURL).reference().child("workingHours")
        var workingHoursData: [String: Any] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
            
        for (day, isSelected) in selectedDays where isSelected {
            let start = dateFormatter.string(from: workingHours[day]!.start)
            let end = dateFormatter.string(from: workingHours[day]!.end)
            workingHoursData[day] = [
                "start": start,
                "end": end
            ]
        }

        ref.setValue(workingHoursData) { error, _ in
            if let error = error {
                print("Error saving working hours: \(error.localizedDescription)")
            } else {
                print("Working hours saved successfully.")
                self.showAlert = true
            }
        }
    }

}

struct EditHoursView: View {
    @ObservedObject var viewModel: DoctorViewModel
    
    var body: some View {
        Form {
            ForEach(Array(viewModel.workingHours.keys).sorted(), id: \.self) { day in
                Section(header: Text(day)) {
                    Toggle(day, isOn: Binding(
                        get: { self.viewModel.selectedDays[day] ?? false },
                        set: { self.viewModel.selectedDays[day] = $0 }
                    ))
                    if viewModel.selectedDays[day] ?? false {
                        DatePicker("Start Time", selection: Binding(
                            get: { self.viewModel.workingHours[day]?.start ?? Date() },
                            set: { newValue in
                                if var times = self.viewModel.workingHours[day] {
                                    times.start = newValue
                                    self.viewModel.workingHours[day] = times
                                }
                            }
                        ), displayedComponents: .hourAndMinute)
                        
                        DatePicker("End Time", selection: Binding(
                            get: { self.viewModel.workingHours[day]?.end ?? Date() },
                            set: { newValue in
                                if var times = self.viewModel.workingHours[day] {
                                    times.end = newValue
                                    self.viewModel.workingHours[day] = times
                                }
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            }
            Button("Save", action: viewModel.saveWorkingHours)
        }
        .navigationBarTitle("Edit Working Hours", displayMode: .inline)
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Success"), message: Text("Working hours updated successfully."), dismissButton: .default(Text("Okay")))
        }
    }
}


struct DoctorView: View {
    @AppStorage("uid") var userID: String = ""
    @State private var showCreateDiet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    GreetingSection()
                    OptionsSection(showCreateDiet: $showCreateDiet)
                    Spacer()
                    SignOutButton()
                }
                .padding()
            }
        }
    }
}

struct GreetingSection: View {
    var body: some View {
        HStack {
            Text("Hello Dr. Omar")
                .bold()
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
    }
}
struct OptionsSection: View {
    @Binding var showCreateDiet: Bool
    @State private var showClientsView = false
    @State private var showChatsListView: Bool = false
    @State private var showEditHours = false
    
    private var isArabic: Bool {
        Locale.current.languageCode == "ar"
    }

    var body: some View {
        VStack(spacing: 20) {
            NavigationLink(destination: CreateDietView(showCreateDiet: $showCreateDiet), isActive: $showCreateDiet) {
                EmptyView()
            }

            OptionButton(title: isArabic ? "إنشاء نظام غذائي" : "Create Diet", action: {
                self.showCreateDiet = true
            })

            NavigationLink(destination: ClientsView(), isActive: $showClientsView) {
                OptionButton(title: isArabic ? "عرض العملاء" : "View Clients", action: {
                    self.showClientsView = true
                })
            }
            .isDetailLink(false)

            NavigationLink(destination: ChatsListView(), isActive: $showChatsListView) {
                OptionButton(title: isArabic ? "دردشة" : "Chat", action: {
                    self.showChatsListView = true
                })
            }
            .isDetailLink(false)

            NavigationLink(destination: EditHoursView(viewModel: DoctorViewModel()), isActive: $showEditHours) {
                OptionButton(title: isArabic ? "تعديل الساعات" : "Edit Hours", action: {
                    self.showEditHours = true
                })
            }
        }
    }
}

struct OptionButton: View {
    var title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: action ?? {}) {
            Text(title)
                .bold()
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .padding(.horizontal)
        }
    }
}


struct SignOutButton: View {
    @AppStorage("uid") var userID: String = ""

    var body: some View {
        Button(action: signOut) {
            Text("Sign Out")
                .foregroundColor(.red)
                .bold()
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 2))
                .padding(.horizontal)
        }
        .padding(.bottom)
    }

    private func signOut() {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            withAnimation {
                userID = ""
            }
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

struct CreateDietView: View {
    @Binding var showCreateDiet: Bool
    @ObservedObject var viewModel = CreateDietViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Diet Name")) {
                    TextField("Enter diet name", text: $viewModel.dietName)
                }
                DietInputSection(title: "Breakfast", items: $viewModel.breakfast)
                DietInputSection(title: "Lunch", items: $viewModel.lunch)
                DietInputSection(title: "Dinner", items: $viewModel.dinner)
                DietInputSection(title: "Snacks", items: $viewModel.snacks)
                
                Button("Save Diet", action: viewModel.saveDiet)
            }
            .navigationBarTitle("Create Diet", displayMode: .inline)
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Success"),
                  message: Text("Diet added successfully."),
                  dismissButton: .default(Text("Okay")) {
                      self.showCreateDiet = false
                  })
        }
    }
}




class CreateDietViewModel: ObservableObject {
    @Published var showAlert = false
    @Published var breakfast: [String] = []
    @Published var lunch: [String] = []
    @Published var dinner: [String] = []
    @Published var snacks: [String] = []
    @Published var dietName: String = ""
    var userIds: [String] = []

    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"

    func saveDiet() {
        let ref = Database.database(url: databaseURL).reference().child("diets").childByAutoId()
        let dietData: [String: Any] = [
            "name": dietName,
            "breakfast": breakfast,
            "lunch": lunch,
            "dinner": dinner,
            "snacks": snacks,
        ]
        ref.setValue(dietData) { error, _ in
            if let error = error {
                print("Error saving diet: \(error.localizedDescription)")
            } else {
                print("Diet saved successfully.")
                self.showAlert = true
            }
        }
    }
}



import SwiftUI
import Firebase

struct ClientsView: View {
    @ObservedObject var viewModel = ClientsViewModel()
    
    @State private var isPickerPresented: Bool = false
    @State private var isDietPickerPresented: Bool = false
    @State private var milestoneWeight: String = ""
    @State private var awardPoints: String = ""
    @State private var pointsInput: String = "" // For points management
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationView {
            ScrollView { // Wrap content in a ScrollView
                VStack {
                    Button(action: {
                        self.isPickerPresented.toggle()
                    }) {
                        Text(viewModel.selectedUserIndex != nil ? viewModel.users[viewModel.selectedUserIndex!].name : "Please choose a client")
                            .foregroundColor(Color.black)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding([.horizontal, .top])
                    .sheet(isPresented: $isPickerPresented) {
                        VStack {
                            ForEach(0..<viewModel.users.count, id: \.self) { index in
                                Button(action: {
                                    viewModel.selectedUserIndex = index
                                    self.isPickerPresented = false
                                }) {
                                    Text(viewModel.users[index].name)
                                }
                                .padding()
                            }
                        }
                    }

                    if let index = viewModel.selectedUserIndex {
                        let user = viewModel.users[index]
                        Text("Name: \(user.name)")
                        Text("Target Weight: \(user.targetWeight ?? "N/A")")
                        
                        if let lastWeight = viewModel.getLastWeight(for: user.id) {
                            Text("Current Weight: \(lastWeight)")
                        } else {
                            Text("No weight recorded yet.")
                        }
                        
                        TextField("Enter new target weight", text: $viewModel.newTargetWeight)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        Button("Save Target Weight") {
                            viewModel.saveTargetWeight(for: user.id)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Divider()
                        
                        TextField("Enter current weight", text: $viewModel.newWeight)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        Button("Update Weight") {
                            viewModel.updateWeight(for: user.id)
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        // Milestone and points UI
                        TextField("Milestone Weight (kg)", text: $milestoneWeight)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        TextField("Award Points", text: $awardPoints)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        Button("Set Milestone") {
                            if let mw = Double(milestoneWeight), let ap = Int(awardPoints) {
                                viewModel.saveMilestone(for: user.id, milestoneWeight: mw, awardPoints: ap)
                                milestoneWeight = ""
                                awardPoints = ""
                            }
                        }
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        TextField("Points", text: $pointsInput)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)

                        HStack {
                            Button("Add Points") {
                                if let pointsToAdd = Int(pointsInput) {
                                    viewModel.adjustUserPoints(for: user.id, pointsToAward: pointsToAdd)
                                    pointsInput = "" // Clear the input field
                                }
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            Button("Deduct Points") {
                                if let pointsToDeduct = Int(pointsInput) {
                                    let userID = user.id // Directly use user.id since it's not optional
                                    viewModel.deductPointsForUser(userID: userID, pointsToDeduct: pointsToDeduct)
                                    pointsInput = "" // Clear the input field
                                }
                            }
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        Button("Assign Diet") {
                            self.isDietPickerPresented.toggle()
                        }
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .sheet(isPresented: $isDietPickerPresented, content: dietPickerSheet)
                    }
                }
                .navigationBarTitle("Client Details", displayMode: .inline)
                .alert(isPresented: $viewModel.isDietAssignedSuccessfully, content: dietAssignedAlert)
                .onAppear {
                    viewModel.fetchUsers()
                    viewModel.fetchDiets()
                }
            }
        }
    }

    private func dietPickerSheet() -> some View {
        VStack {
            ForEach(viewModel.diets.indices, id: \.self) { dietIndex in
                Button(action: {
                    viewModel.assignDietToUser(userId: viewModel.users[viewModel.selectedUserIndex!].id, dietId: viewModel.diets[dietIndex].id)
                }) {
                    Text(viewModel.diets[dietIndex].name)
                }
                .padding()
            }
        }
    }

    private func dietAssignedAlert() -> Alert {
        Alert(title: Text("Action Complete"),
              message: Text("Diet assigned successfully."),
              dismissButton: .default(Text("OK")) {
                  self.isDietPickerPresented = false
                  viewModel.isDietAssignedSuccessfully = false
                  self.presentationMode.wrappedValue.dismiss()
              })
    }
}






class ClientsViewModel: ObservableObject {
    @Published var users: [(id: String, name: String, targetWeight: String?, weightProgress: [String])] = []
    @Published var diets: [(id: String, name: String)] = [] // Assuming you have this property for diets
    @Published var selectedUserIndex: Int?
    @Published var newTargetWeight: String = ""
    @Published var newWeight: String = ""
    @Published var isDietAssignedSuccessfully = false

    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
    private var ref: DatabaseReference { Database.database(url: databaseURL).reference() }

    func fetchUsers() {
        ref.child("users").observeSingleEvent(of: .value, with: { snapshot in
            var loadedUsers: [(id: String, name: String, targetWeight: String?, weightProgress: [String])] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any],
                   let firstName = dict["firstName"] as? String,
                   let lastName = dict["lastName"] as? String {
                    let targetWeight = dict["targetWeight"] as? String
                    let weightProgressNumbers = dict["weightProgress"] as? [Double] ?? []
                    let weightProgress = weightProgressNumbers.map { String($0) }

                    loadedUsers.append((id: childSnapshot.key, name: "\(firstName) \(lastName)", targetWeight: targetWeight, weightProgress: weightProgress))
                }
            }
            self.users = loadedUsers
        })
    }
    
    func saveMilestone(for userID: String, milestoneWeight: Double, awardPoints: Int) {
        // Ensure milestoneWeight and awardPoints are not 0 when setting a new milestone
        if milestoneWeight > 0 && awardPoints > 0 {
            let milestoneData: [String: Any] = [
                "milestoneWeight": milestoneWeight,
                "awardPoints": awardPoints
            ]
            ref.child("milestones").child(userID).setValue(milestoneData)
        }
    }

    
    func checkAndAwardPoints(for userID: String, newWeight: Double) {
        ref.child("milestones").child(userID).observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any],
                  let milestoneWeight = value["milestoneWeight"] as? Double,
                  let awardPoints = value["awardPoints"] as? Int else {
                return
            }

            if newWeight <= milestoneWeight && milestoneWeight > 0 {
                self.adjustUserPoints(for: userID, pointsToAward: awardPoints)
                self.ref.child("milestones").child(userID).updateChildValues(["milestoneWeight": 0, "awardPoints": 0])
            }
        })
    }
    
     func adjustUserPoints(for userID: String, pointsToAward: Int) {
        ref.child("users").child(userID).child("points").observeSingleEvent(of: .value, with: { snapshot in
            let currentPoints = snapshot.value as? Int ?? 0
            let updatedPoints = currentPoints + pointsToAward
            self.ref.child("users").child(userID).updateChildValues(["points": updatedPoints])
        })
    }
    
    


    func saveTargetWeight(for userID: String) {
        ref.child("users").child(userID).updateChildValues(["targetWeight": newTargetWeight]) { [weak self] error, _ in
            if let error = error {
                print("Failed to update target weight:", error)
                return
            }
            self?.fetchUsers()
        }
    }

    func updateWeight(for userID: String) {
        if let newWeightValue = Double(newWeight) {
            ref.child("users").child(userID).child("weightProgress").observeSingleEvent(of: .value, with: { snapshot in
                var updatedWeights = snapshot.value as? [Double] ?? []
                updatedWeights.append(newWeightValue)
                self.ref.child("users").child(userID).child("weightProgress").setValue(updatedWeights) { [weak self] error, _ in
                    if let error = error {
                        print("Failed to update weight:", error)
                        return
                    }
                    self?.newWeight = ""
                    self?.fetchUsers()
                }
            })
            checkAndAwardPoints(for: userID, newWeight: newWeightValue)
        } else {
            print("Failed to convert new weight to Double")
        }
    }

    
    func fetchDiets() {
        ref.child("diets").observeSingleEvent(of: .value, with: { snapshot in
            var loadedDiets: [(id: String, name: String)] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any],
                   let dietName = dict["name"] as? String {
                    loadedDiets.append((id: childSnapshot.key, name: dietName))
                }
            }
            self.diets = loadedDiets
        })
    }

    func assignDietToUser(userId: String, dietId: String) {
        ref.child("users").child(userId).updateChildValues(["diet": dietId]) { [weak self] error, _ in
            if let error = error {
                print("Failed to assign diet:", error)
            }

            self?.isDietAssignedSuccessfully = true
            self?.fetchUsers()
        }
    }
    
    func getLastWeight(for userID: String) -> String? {
        // Find the user with the given ID
        if let user = users.first(where: { $0.id == userID }) {
            return user.weightProgress.last
        }
        return nil
    }
    
    func deductPointsForUser(userID: String, pointsToDeduct: Int) {
        ref.child("users").child(userID).child("points").observeSingleEvent(of: .value, with: { snapshot in
            let currentPoints = snapshot.value as? Int ?? 0
            let updatedPoints = max(currentPoints - pointsToDeduct, 0)
            self.ref.child("users").child(userID).updateChildValues(["points": updatedPoints])
        })
    }

}

struct ResignableTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ResignableTextField

        init(_ textField: ResignableTextField) {
            self.parent = textField
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            textField.resignFirstResponder()
            return true
        }
    }
}


struct DietInputSection: View {
    var title: String
    @Binding var items: [String]
    @State private var input: String = ""

    var body: some View {
        Section(header: Text(title)) {
            ForEach(items, id: \.self) { item in
                Text(item)
            }

            HStack {
                TextField("Add new item", text: $input)
                Button(action: {
                    if !input.isEmpty {
                        items.append(input)
                        input = ""
                    }
                }) {
                    Text("Add")
                }
            }
        }
    }
}

struct LineView: View {
    let data: [Double]
    let title: String
    let legend: String

    private let labelOffset: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                Text(title)
                    .font(.custom("Avenir", size: 20))
                    .bold()
                    .foregroundColor(.purple)
                    .environment(\.layoutDirection, .leftToRight)

                Text(legend)
                    .font(.custom("Avenir", size: 16))
                    .foregroundColor(.gray)
                    .environment(\.layoutDirection, .leftToRight)
                ZStack {
                    ForEach(0..<data.count, id: \.self) { i in
                        let x = CGFloat(i) * geometry.size.width / CGFloat(data.count)
                        let y = CGFloat(data[i]) * (geometry.size.height - labelOffset) / CGFloat(data.max() ?? 1)

                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .position(x: x, y: (geometry.size.height - labelOffset) - y)
                    }
                    
                    Path { path in
                        let heightScale = (geometry.size.height - labelOffset) / CGFloat(data.max() ?? 1)
                        let widthScale = geometry.size.width / CGFloat(data.count)

                        for i in 0..<data.count {
                            let x = CGFloat(i) * widthScale
                            let y = CGFloat(data[i]) * heightScale

                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: (geometry.size.height - labelOffset) - y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: (geometry.size.height - labelOffset) - y))
                            }
                        }
                    }
                    .stroke(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(radius: 5)
                    
                    ForEach(0..<data.count, id: \.self) { i in
                        let x = CGFloat(i) * geometry.size.width / CGFloat(data.count)
                        let y = CGFloat(data[i]) * (geometry.size.height - labelOffset) / CGFloat(data.max() ?? 1)
                        
                        Text("\(data[i], specifier: "%.1f")") // 1 decimal place
                            .position(x: x, y: (geometry.size.height - labelOffset) - y + labelOffset / 2) // Offset below the line
                            .foregroundColor(.purple)
                            .font(.custom("Avenir", size: 12))
                    }
                }
            }
            .padding()
        }
    }
}

import SwiftUI
import Firebase

struct DietView: View {
    @State private var breakfastItems: [String: Bool] = [:]
    @State private var lunchItems: [String: Bool] = [:]
    @State private var dinnerItems: [String: Bool] = [:]
    @State private var snackItems: [String: Bool] = [:]
    @State private var lastCheckDate = Date()
    
    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
    private var ref: DatabaseReference { Database.database(url: databaseURL).reference() }
    let dietId: String
    
    init(dietId: String) {
        self.dietId = dietId
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color.purple, Color.white]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    if dietId.isEmpty {
                        Text("Book your first consultation to start your journey!")
                            .font(.custom("Avenir", size: 18))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                            .padding()
                    } else {
                        mealSectionContainer(title: "Breakfast", items: $breakfastItems)
                        mealSectionContainer(title: "Lunch", items: $lunchItems)
                        mealSectionContainer(title: "Dinner", items: $dinnerItems)
                        mealSectionContainer(title: "Snacks", items: $snackItems)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            fetchDiet()
            
            loadCheckmarks(items: $breakfastItems, key: "breakfast")
            loadCheckmarks(items: $lunchItems, key: "lunch")
            loadCheckmarks(items: $dinnerItems, key: "dinner")
            loadCheckmarks(items: $snackItems, key: "snacks")
            
            let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            _ = timer.sink { currentDate in
                let calendar = Calendar.current
                if calendar.isDateInToday(self.lastCheckDate) == false {
                    breakfastItems = [:]
                    lunchItems = [:]
                    dinnerItems = [:]
                    snackItems = [:]
                    lastCheckDate = currentDate
                    fetchDiet() // Refetch the diet to reset the checkmarks
                }
            }
        }
        
        
    }
    
    private func mealSectionContainer(title: String, items: Binding<[String: Bool]>) -> some View {
        VStack {
            if !items.wrappedValue.isEmpty {
                VStack {
                    Text(title)
                        .font(.custom("Avenir", size: 18))
                        .bold()
                        .foregroundColor(.purple)
                        .padding()
                    
                    ForEach(Array(items.wrappedValue.keys), id: \.self) { item in
                        HStack {
                            Text(item)
                                .font(.custom("Avenir", size: 16))
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: items.wrappedValue[item]! ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 28))
                                .foregroundColor(.purple)
                                .onTapGesture {
                                    items.wrappedValue[item]?.toggle()
                                    saveCheckmarks(items: items.wrappedValue, key: title.lowercased()) // Save the checkmarks
                                }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.white))
                .shadow(radius: 10)
                .padding(.horizontal)
            }
        }
    }
    
    
    private func fetchDiet() {
        guard !dietId.isEmpty else {
            print("No diet assigned to this user.")
            return
        }
        
        let ref = Database.database(url: databaseURL).reference().child("diets").child(dietId)
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dietData = snapshot.value as? [String: Any] {
                if let breakfastData = dietData["breakfast"] as? [String] {
                    convertToChecklist(data: breakfastData, items: $breakfastItems)
                }
                if let lunchData = dietData["lunch"] as? [String] {
                    convertToChecklist(data: lunchData, items: $lunchItems)
                }
                if let dinnerData = dietData["dinner"] as? [String] {
                    convertToChecklist(data: dinnerData, items: $dinnerItems)
                }
                if let snackData = dietData["snacks"] as? [String] {
                    convertToChecklist(data: snackData, items: $snackItems)
                }
            } else {
                print("Error: could not load diet data.")
            }
        }
    }
    
    
    private func convertToChecklist(data: [String], items: Binding<[String: Bool]>) {
        let userDefaults = UserDefaults.standard
        let key = "\(dietId)-\(data.first ?? "")" // Unique key for each meal
        if let savedData = userDefaults.data(forKey: key),
           let savedItems = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            items.wrappedValue = savedItems
        } else {
            for item in data {
                items.wrappedValue[item] = false
            }
        }
    }
    
    
    private func mealSection(title: String, items: Binding<[String: Bool]>, key: String) -> some View {
        Section(header: Text(title).font(.headline).padding()) {
            ForEach(Array(items.wrappedValue.keys), id: \.self) { item in
                HStack {
                    Text(item)
                        .font(.title2)
                        .bold()
                    Spacer()
                    Image(systemName: items.wrappedValue[item]! ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .onTapGesture {
                            items.wrappedValue[item]?.toggle()
                            saveCheckmarks(items: items.wrappedValue, key: key) // Replace "breakfast" with the correct key for the meal
                        }
                }
                .padding(.vertical, 8) // Add more padding to each item
            }
        }
    }
    
    private func saveCheckmarks(items: [String: Bool], key: String) {
        let userDefaults = UserDefaults.standard
        let uniqueKey = "\(dietId)-\(key)" // Unique key for each meal
        if let data = try? JSONEncoder().encode(items) {
            userDefaults.set(data, forKey: uniqueKey)
        }
    }
    private func loadCheckmarks(items: Binding<[String: Bool]>, key: String) {
        let userDefaults = UserDefaults.standard
        let uniqueKey = "\(dietId)-\(key)" // Unique key for each meal
        if let savedData = userDefaults.data(forKey: uniqueKey),
           let savedItems = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            items.wrappedValue = savedItems
        }
    }
}

struct Message {
    let senderUID: String
    let timestamp: Double
    let content: String
}

struct ChatSession {
    let chatID: String
    let userUID: String
}

struct ChatManager {
    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"

    func createChat(for userUID: String, completion: @escaping (String?) -> Void) {
        let ref = Database.database(url: databaseURL).reference().child("chats").childByAutoId()
        ref.setValue(["userUID": userUID]) { error, _ in
            if let error = error {
                print("Error creating chat: \(error.localizedDescription)")
                completion(nil)
            } else {
                print("Chat session created successfully.")
                completion(ref.key) // Return chat session ID.
            }
        }
    }

    func sendMessage(to chatID: String, from senderUID: String, content: String) {
        let messageData: [String: Any] = [
            "senderUID": senderUID,
            "timestamp": ServerValue.timestamp(),
            "content": content
        ]
        let ref = Database.database(url: databaseURL).reference().child("chats").child(chatID).child("messages").childByAutoId()
        ref.setValue(messageData) { error, _ in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            } else {
                print("Message sent successfully.")
            }
        }
    }
    
    func fetchLastMessage(from chatID: String, completion: @escaping (Message?) -> Void) {
        let ref = Database.database(url: databaseURL).reference().child("chats").child(chatID).child("messages")
        ref.queryLimited(toLast: 1).observeSingleEvent(of: .value) { snapshot in
            if let childSnapshot = snapshot.children.allObjects.first as? DataSnapshot,
               let dict = childSnapshot.value as? [String: Any],
               let senderUID = dict["senderUID"] as? String,
               let timestamp = dict["timestamp"] as? Double,
               let content = dict["content"] as? String {
                let message = Message(senderUID: senderUID, timestamp: timestamp, content: content)
                completion(message)
            } else {
                completion(nil)
            }
        }
    }


    func fetchMessages(from chatID: String, completion: @escaping ([Message]) -> Void) {
        let ref = Database.database(url: databaseURL).reference().child("chats").child(chatID).child("messages")
        ref.observe(.value, with: { snapshot in
            var loadedMessages: [Message] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any],
                   let senderUID = dict["senderUID"] as? String,
                   let timestamp = dict["timestamp"] as? Double,
                   let content = dict["content"] as? String {
                    let message = Message(senderUID: senderUID, timestamp: timestamp, content: content)
                    loadedMessages.append(message)
                }
            }
            completion(loadedMessages)
        })
    }


    func fetchChatSessions(completion: @escaping ([ChatSession]) -> Void) {
        let ref = Database.database(url: databaseURL).reference().child("chats")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            var loadedChatSessions: [ChatSession] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any],
                   let userUID = dict["userUID"] as? String {
                    let chatSession = ChatSession(chatID: childSnapshot.key, userUID: userUID)
                    loadedChatSessions.append(chatSession)
                }
            }
            completion(loadedChatSessions)
        })
    }
    
    func fetchChatID(for userUID: String, completion: @escaping (String?) -> Void) {
        let ref = Database.database(url: databaseURL).reference().child("chats")
        ref.queryOrdered(byChild: "userUID").queryEqual(toValue: userUID).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.exists(), let childSnapshot = snapshot.children.allObjects.first as? DataSnapshot {
                completion(childSnapshot.key)
            } else {
                completion(nil)
            }
        }
    }
}

import SwiftUI
import Firebase

struct ChatView: View {
    @State private var newMessage = ""
    @State private var messages: [Message] = []
    let chatManager = ChatManager()
    let userUID: String
    let recipientName: String = "Dr. Omar Salem"
    
    @State private var currentChatID: String? = nil

    init(userUID: String) {
        self.userUID = userUID
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(recipientName)
                    .font(.headline)
                    .padding(.top, 10)
                
                Divider()
                    .padding(.horizontal)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(messages, id: \.self) { message in
                                if message.senderUID == userUID {
                                    ClientMessageView(message: message.content, timestamp: message.timestamp)
                                } else {
                                    DoctorMessageView(message: message.content, timestamp: message.timestamp)
                                }
                            }
                            
                            Spacer().frame(height: 100) // Just to give some bottom spacing
                        }
                        .onChange(of: messages.count) { _ in
                            withAnimation {
                                if let lastMessage = messages.last {
                                    proxy.scrollTo(lastMessage, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                HStack {
                    TextField("Type your message", text: $newMessage)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    
                    Button("Send") {
                        if let chatID = currentChatID {
                            chatManager.sendMessage(to: chatID, from: userUID, content: newMessage)
                            newMessage = ""
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .onAppear {
                chatManager.fetchChatID(for: userUID) { chatID in
                    if let id = chatID {
                        currentChatID = id
                        fetchMessages()
                    } else {
                        chatManager.createChat(for: userUID) { newChatID in
                            if let id = newChatID {
                                currentChatID = id
                            }
                        }
                    }
                }
            }
        }
    }
    
    func fetchMessages() {
        if let chatID = currentChatID {
            chatManager.fetchMessages(from: chatID) { loadedMessages in
                messages = loadedMessages
            }
        }
    }
}


extension Message: Hashable {
    static func ==(lhs: Message, rhs: Message) -> Bool {
        return lhs.timestamp == rhs.timestamp
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
    }
}







func formatDate(_ timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp/1000)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"
    return dateFormatter.string(from: date)
}



struct ClientMessageView: View {
    let message: String
    let timestamp: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(message)
                    .padding(12)
                    .background(BubbleShape(direction: .left).fill(Color.blue))
                    .foregroundColor(.white)
                    .padding(.leading, 16)
                    .padding(.trailing, 50)
                Text(formatDate(timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 16)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
}

struct DoctorMessageView: View {
    let message: String
    let timestamp: Double
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                Text(message)
                    .padding(12)
                    .background(BubbleShape(direction: .right).fill(Color.green))
                    .foregroundColor(.white)
                    .padding(.leading, 50)
                    .padding(.trailing, 16)
                Text(formatDate(timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 16)
            }
        }
        .padding(.horizontal)
    }
}


struct BubbleShape: Shape {
    enum Direction {
        case left
        case right
    }
    
    let direction: Direction
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 20, height: 20))
        
        let triangleSize: CGFloat = 10
        let triangleRect: CGRect
        switch direction {
        case .left:
            triangleRect = CGRect(x: 0, y: rect.midY - triangleSize, width: triangleSize, height: triangleSize * 2)
        case .right:
            triangleRect = CGRect(x: rect.width - triangleSize, y: rect.midY - triangleSize, width: triangleSize, height: triangleSize * 2)
        }
        
        path.addLines([CGPoint(x: triangleRect.minX, y: triangleRect.minY),
                       CGPoint(x: triangleRect.minX, y: triangleRect.maxY),
                       CGPoint(x: triangleRect.midX, y: triangleRect.midY)])
        
        return path
    }
}

struct ChatsListView: View {
    @State private var chatSessions: [ChatSession] = []
    @State private var users: [String: (name: String, lastMessage: String?, lastMessageTimestamp: Double?)] = [:]
    let chatManager = ChatManager()
    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
    private var ref: DatabaseReference { Database.database(url: databaseURL).reference() }
    
    var body: some View {
        NavigationView {
            List(chatSessions.sorted(by: {
                (users[$0.userUID]?.lastMessageTimestamp ?? 0) > (users[$1.userUID]?.lastMessageTimestamp ?? 0)
            }), id: \.chatID) { chatSession in
                NavigationLink(destination: DoctorMessagingView(chatID: chatSession.chatID, clientUID: chatSession.userUID)) {
                    VStack(alignment: .leading) {
                        Text(users[chatSession.userUID]?.name ?? "")
                            .font(.headline)
                        Text(users[chatSession.userUID]?.lastMessage ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Chats")
            .onAppear {
                fetchUsers {
                    loadChatSessions {
                        fetchLastMessages()
                    }
                }
            }
        }
    }
    
    func loadChatSessions(completion: @escaping () -> Void) {
        chatManager.fetchChatSessions { sessions in
            self.chatSessions = sessions
            completion()
        }
    }
    
    func fetchLastMessages() {
        for session in chatSessions {
            chatManager.fetchLastMessage(from: session.chatID) { message in
                if let message = message {
                    self.users[session.userUID]?.lastMessage = message.content
                    self.users[session.userUID]?.lastMessageTimestamp = message.timestamp
                }
            }
        }
    }

    func fetchUsers(completion: @escaping () -> Void) {
        ref.child("users").observeSingleEvent(of: .value, with: { snapshot in
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any],
                   let firstName = dict["firstName"] as? String,
                   let lastName = dict["lastName"] as? String {
                    self.users[childSnapshot.key] = (name: "\(firstName) \(lastName)", lastMessage: nil, lastMessageTimestamp: nil)
                }
            }
            completion()
        })
    }
}



import SwiftUI
import Firebase

struct DoctorMessagingView: View {
    @State private var newMessage = ""
    @State private var messages: [Message] = []
    let chatManager = ChatManager()
    let chatID: String
    let clientUID: String
    
    init(chatID: String, clientUID: String) {
        self.chatID = chatID
        self.clientUID = clientUID
    }
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(messages, id: \.self) { message in
                            if message.senderUID == clientUID {
                                ClientMessageView(message: message.content, timestamp: message.timestamp)
                            } else {
                                DoctorMessageView(message: message.content, timestamp: message.timestamp)
                            }
                        }
                        Spacer().frame(height: 100)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            HStack {
                TextField("Type your message", text: $newMessage)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                
                Button("Send") {
                    chatManager.sendMessage(to: chatID, from: "DoctorUID", content: newMessage) // Replace "DoctorUID" with the actual doctor's UID.
                    newMessage = ""
                }
                .padding()
            }
            .padding()
        }
        .onAppear {
            fetchMessages()
        }
    }
    
    func fetchMessages() {
        chatManager.fetchMessages(from: chatID) { loadedMessages in
            messages = loadedMessages
        }
    }
}

import SwiftUI
import FirebaseDatabase
import Combine

class WorkingHoursViewModel: ObservableObject {
    @Published var workingHours: [String: (start: String, end: String)] = [:]
    
    private let databaseURL = "https://dmo-clinic-default-rtdb.europe-west1.firebasedatabase.app"
    private var cancellables: Set<AnyCancellable> = []

    init() {
        fetchWorkingHours()
    }
    
    func fetchWorkingHours() {
         let ref = Database.database(url: databaseURL).reference().child("workingHours")
         ref.observeSingleEvent(of: .value) { snapshot in
             if let data = snapshot.value as? [String: [String: String]] {
                 for (day, hours) in data {
                     self.workingHours[day] = (start: hours["start"] ?? "", end: hours["end"] ?? "")
                 }
             } else {
                 print("Fetching Error: could not convert snapshot data or no data found.")
             }
         }
     }
}

struct WorkingHoursView: View {
    @ObservedObject var viewModel = WorkingHoursViewModel()

    var body: some View {
        ZStack {
            // Setting the entire background as white
            Color.white.edgesIgnoringSafeArea(.all)

            List {
                ForEach(viewModel.workingHours.keys.sorted(), id: \.self) { day in
                    HStack {
                        Text(day)
                            .font(.custom("Avenir", size: 22))
                            .bold()
                            .foregroundColor(Color.black)
                        
                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Start: \(viewModel.workingHours[day]?.start ?? "")")
                                .font(.custom("Avenir", size: 18))
                                .foregroundColor(Color.black)

                            Text("End: \(viewModel.workingHours[day]?.end ?? "")")
                                .font(.custom("Avenir", size: 18))
                                .foregroundColor(Color.black)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationBarTitle("Doctor's Working Hours", displayMode: .inline)
        .environment(\.colorScheme, .light)  // Disable dark mode for this view
    }
}


import SwiftUI

struct AboutUsView: View {
    
    let instagramURL = "https://instagram.com/dmo.nutrition.clinics?igshid=MzRlODBiNWFlZA=="
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("About DMO Nutrition Clinics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.black)
                        .padding(.top, 20)

                    Divider()
                        .background(Color.black.opacity(0.5))

                    Text("DMO nutrition clinics were founded by Dr. Mohamed Omar. With his experience of over 25 years in nutrition weight management, he has helped over 500,000 cases reach their dream bodies and achieve their weight goals. Dr. Mohamed passed his experience and knowledge to his son, Dr. Omar Salem, who now continues the legacy, helping thousands achieve their health and life goals.")
                        .font(.body)
                        .foregroundColor(Color.black.opacity(0.8))
                        .padding(.vertical, 10)

                    Divider()
                        .background(Color.black.opacity(0.5))

                    HStack(spacing: 10) {
                        Text("Follow us on Instagram:")
                            .font(.headline)
                            .foregroundColor(Color.black.opacity(0.8))

                        Spacer()

                        Button(action: {
                            if let url = URL(string: instagramURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Image("InstagramLogo")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }
                    .padding([.top, .bottom], 20)
                    
                }
                .padding(20)
            }
            
            Image("DMOLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .padding(.all, 20)
            
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("About Us", displayMode: .inline)
    }
}





























































    

