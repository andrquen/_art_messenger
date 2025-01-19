import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // For image selection
import 'dart:io'; // For File handling
import 'dart:convert'; // For base64 encoding
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared preferences
import 'package:flutter_localizations/flutter_localizations.dart'; // Add for localization

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseInitialized = false;
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
          options: const FirebaseOptions(
              apiKey: "AIzaSyChlnCWj1PBtIzmJYYQ6PLjiYF_B3ivAfI",
              appId: "1:913902128058:web:4014de205850f68dcc2b83",
              messagingSenderId: "913902128058",
              projectId: "art-mess"));
    } else {
      await Firebase.initializeApp();
    }
    firebaseInitialized = true;
  } catch (e) {
    print('Firebase initialization failed: $e');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

bool? _isDarkMode;

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, required this.firebaseInitialized});

  // Define a locale to hold the current language selection
  static Locale _locale = const Locale('en', 'US'); // Default to English

  // Load the saved language setting from SharedPreferences
  static Future<void> loadSavedLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('languageCode');
    String? countryCode = prefs.getString('countryCode');

    if (languageCode != null && countryCode != null) {
      _locale = Locale(languageCode, countryCode);
    } else {
      // More robust locale parsing:
      String platformLocaleName = Platform.localeName;
      List<String> localeParts = platformLocaleName.split('_');
      if (localeParts.isNotEmpty) {
        String language = localeParts[0];
        String? country;
        if (localeParts.length > 1) {
          country = localeParts[1];
        }
        _locale = Locale(language, country); // Use parsed parts
      } else {
        // Fallback to a default locale:
        _locale = const Locale('en', 'US');
        print('Error parsing locale, defaulting to en_US');
      }
    }
  }

  Future<void> _loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
  }

  // Function to set the locale
  static void setLocale(Locale locale) {
    _locale = locale;
  }

  @override
  Widget build(BuildContext context) {
    loadSavedLocale(); // Load saved locale when the app starts
    _loadThemePreference();
    return FutureBuilder(
      future: _loadThemePreference(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        } else {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            // Configure localization
            locale: _locale, // Use the current locale
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              // Locale('en', ''), // English (Generic)
              Locale('en', 'US'), // English
              Locale('es', 'ES'), // Spanish
              Locale('fr', 'FR'), // French
              Locale('ru', 'RU'), // Russian
              Locale('uk', 'UA'), // Ukrainian
              Locale('ka', 'GE'), // Georgian
              Locale('hy', 'AM'), // Armenian
              // Add more supported locales here
            ],
            home: const AuthGate(),
            themeMode: _isDarkMode! ? ThemeMode.dark : ThemeMode.light,
            routes: {
              '/home': (context) =>
                  const MainScreen(), // Add a route for the main page
            },
          );
        }
      },
    );
  }
}

// Authentication Gate
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // User is signed in
          return FutureBuilder(
            future: _checkUserHasArtworks(snapshot.data!.uid),
            builder: (context, artworksSnapshot) {
              if (artworksSnapshot.connectionState == ConnectionState.done) {
                
                  return const MainScreen(); // Navigate to the MainScreen
                
              } else {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
            },
          );
        } else {
          // User is not signed in
          return const AuthScreen(); // Show the authentication screen
        }
      },
    );
  }

  Future<bool> _checkUserHasArtworks(String userId) async {
    final artworksSnapshot = await FirebaseFirestore.instance
        .collection('artworks')
        .doc(userId) // Use userId directly
        .collection('images')
        .get();
    return artworksSnapshot.docs.isNotEmpty;
  }
}

// Authentication Screen (Sign In / Sign Up)
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()));
                },
                child: const Text('Login')),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegistrationScreen()));
                },
                child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage; // To store the error message

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: _emailController.text,
                password: _passwordController.text);
        // Navigate to the home screen after successful login
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      } on FirebaseAuthException catch (e) {
        // Handle login errors
        print('Login error: ${e.message}');
        setState(() {
          _errorMessage = e.message; // Update the error message
        });
        // Show an error message to the user
      }
    }
  }

  /*Future<void> _ensureDatabaseFields() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Ensure 'likedArtworks' field in user document
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.set({'likedArtworks': {}}, SetOptions(merge: true));

      // Ensure 'likeCount' field in artwork documents
      final artworksSnapshot = await FirebaseFirestore.instance
          .collection('artworks')
          .doc(user.uid)
          .collection('images')
          .get();
      for (var doc in artworksSnapshot.docs) {
        if (!doc.data().containsKey('likeCount')) {
          await doc.reference.update({'likeCount': 0});
        }
      }
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _login,
                child: const Text('Login'),
              ),
              // Display the error message if it's not null
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screen to prompt user to add artworks
class AddArtworksScreen extends StatelessWidget {
  const AddArtworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome!')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'You haven\'t added any artworks yet.',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to artwork upload screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ArtworkUploadScreen()),
                );
              },
              child: const Text('Add Artworks'),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () {
                // Navigate to artwork upload screen
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (route) => false);
              },
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}

// Screen for uploading artworks
class ArtworkUploadScreen extends StatefulWidget {
  const ArtworkUploadScreen({super.key});

  @override
  ArtworkUploadScreenState createState() => ArtworkUploadScreenState();
}


class ArtworkUploadScreenState extends State<ArtworkUploadScreen> {
  final TextEditingController _artworkNameController = TextEditingController();
  String? profileName; // To store the profile name
  final ImagePicker _picker = ImagePicker();
  XFile? image;
  //Uint8List? imagevalue;
  Uint8List? imagevalue;
  //var image;

  Future<void> _pickImages() async {
    image = await _picker.pickImage(source: ImageSource.gallery);
  }

  uploadImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'svg', 'jpeg']);

    if (result != null) {
      PlatformFile file = result.files.first;

      setState(() {
        imagevalue = file.bytes;
      });
    } else {
      // User canceled the picker
    }
  }

  final bool _isLoading = false;

  Widget _buildProgressBar() {
    return _isLoading
        ? const LinearProgressIndicator()
        : const SizedBox.shrink(); // Empty widget when not loading
  }

  Future<void> _getProfileName() async {
    final user = FirebaseAuth.instance.currentUser;
    profileName = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get()
        .then((doc) => doc['name'] as String?);
  }

  @override
  void initState() {
    super.initState();
    _getProfileName(); // Fetch the profile name when the widget initializes
  }

  Future<void> _uploadImageToFirestore(String base64Image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final artworkRef = FirebaseFirestore.instance
            .collection('artworks')
            .doc(user.uid) // Use user.uid directly
            .collection('images')
            .doc();
        await artworkRef.set({
          'imageData': base64Image,
          'artworkName': _artworkNameController.text, // Store artwork name
          'timestamp': FieldValue.serverTimestamp(),
          'likeCount': 0, // Initialize likeCount to 0
        });
        print('Image uploaded to Firestore successfully!');
      } catch (e) {
        print('Error uploading image to Firestore: $e');
        // Handle error, maybe show a snackbar or dialog
      }
    }
  }

  // Consolidated image selection and upload function

  String? _validateArtworkName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an artwork name';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Artwork')),
      body: Center(
        child: Column(
            //mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment
                .center, // Align items to the center horizontally
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextFormField(
                    controller: _artworkNameController,
                    decoration: const InputDecoration(
                        labelText: 'Artwork Name',
                        border: OutlineInputBorder()),
                    validator: _validateArtworkName, // Add validator
                  )),
              const SizedBox(height: 20),
              _buildProgressBar(), // Add progress bar
              const SizedBox(height: 20),
              // Image selection button
              ElevatedButton(
                onPressed: kIsWeb ? uploadImage : _pickImages,
                child: const Text('Choose Photos'),
              ),
              const SizedBox(height: 20),
              if (image != null || imagevalue != null)
                Expanded(
                    child: kIsWeb
                        ? Image.memory(imagevalue!)
                        : Image.file(File(image!.path))),
            ]),
      ),

      floatingActionButton: (image != null || imagevalue != null)
          ? FloatingActionButton(
              onPressed: () async {
                bool confirmUpload = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Upload'),
                    content: const Text(
                        'Are you sure you want to upload these images?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                );
                if (confirmUpload == true) {
                  // Check if the user confirmed
                  String? base64Image;
                  if (kIsWeb) {
                    base64Image = base64Encode(imagevalue!);
                  } else {
                    image!.readAsBytes().then((bytes) {
                      base64Image = base64Encode(bytes);
                    });
                  }
                  _uploadImageToFirestore(base64Image!);
                }
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false);
              },
              child: const Icon(Icons.cloud_upload),
            )
          : null, // Hide FAB if no images are selected
    );
  }
}

// Main Screen with Bottom Navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static final List<Widget> _widgetOptions = <Widget>[
    const ArtFeed(),
    // Add Settings page to navigation
    const ProfilePage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate back to the authentication screen
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Art App'), // Change to a more general title
        actions: [
          if (FirebaseAuth.instance.currentUser !=
              null) // Show logout button only if user is signed in
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context), // Handle logout
            ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Artworks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), // Settings icon
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0 // Show FAB only on ArtFeed page
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ArtworkUploadScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// Settings Page
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false; // Track current theme mode

  @override
  void initState() {
    super.initState();
    _loadThemePreference(); // Load theme preference on startup
  }

  // Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  // Save theme preference to SharedPreferences
  Future<void> _saveThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                    _saveThemePreference(); // Save preference when changed
                    // Apply theme change using Theme.of(context).platform
                  });
                },
              ),
            ),
            /*DropdownButton<String>(
              value: _selectedLanguage,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                  // Update the locale and save it to SharedPreferences
                  if (newValue != null) {
                    Locale newLocale;
                    if (newValue == 'Russian') {
                      newLocale = const Locale('ru', 'RU');
                    } else if (newValue == 'Ukrainian') {
                      newLocale = const Locale('uk', 'UA');
                    } else if (newValue == 'Georgian') {
                      newLocale = const Locale('ka', 'GE');
                    } else if (newValue == 'Armenian') {
                      newLocale = const Locale('hy', 'AM');
                    } else if (newValue == 'English') {
                      newLocale = const Locale('en', 'US');
                    } else if (newValue == 'Spanish') {
                      newLocale = const Locale('es', 'ES');
                    } else if (newValue == 'French') {
                      newLocale = const Locale('fr', 'FR');
                    } else {
                      newLocale = const Locale('en', 'US'); // Default
                    }
                    MyApp.setLocale(newLocale);
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setString('languageCode', newLocale.languageCode);
                      prefs.setString('countryCode', newLocale.countryCode!);
                    });
                  }
                  // Add more language options here
                });
              },
              items: <String>[
                'English',
                'Spanish',
                'French',
                'Russian',
                'Ukrainian',
                'Georgian',
                'Armenian'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),*/
            // Add more settings here...
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  User? user;
  //File? _profileImage; // Add this line
  //String? _profileImageBase64; // To store the base64 string
  final ImagePicker _picker = ImagePicker();
  XFile? image;
  //Uint8List? imagevalue;
  Uint8List? imagevalue;
  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user!.displayName ?? "";
    }
  }

  Future<void> _pickImages() async {
    image = await _picker.pickImage(source: ImageSource.gallery);
    String? base64Image;

    image!.readAsBytes().then((bytes) {
      base64Image = base64Encode(bytes);
    });
    _updateProfileImageInFirestore(base64Image!);
  }

  uploadImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'svg', 'jpeg']);

    if (result != null) {
      PlatformFile file = result.files.first;

      setState(() {
        imagevalue = file.bytes;
      });
      String? base64Image;

      base64Image = base64Encode(imagevalue!);
      _updateProfileImageInFirestore(base64Image);
    } else {
      // User canceled the picker
    }
  }

  Future<void> _updateProfileImageInFirestore(String base64Image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageBase64': base64Image});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('User not signed in.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        // Wrap with SingleChildScrollView
        child: FutureBuilder<DocumentSnapshot>(
          future: _getProfileName(user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final profileName = userData?['name'] as String?;

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // Display the profile image
                    FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data!.data() != null) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                if (userData['profileImageBase64'] != null) {
                  return GestureDetector(
                    onTap: kIsWeb
                          ? uploadImage
                          : _pickImages,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: MemoryImage(
                          base64Decode(userData['profileImageBase64'] as String)),
                    ),
                  );
                }else {
  return GestureDetector(
    onTap: kIsWeb
                          ? uploadImage
                          : _pickImages,
    child: const CircleAvatar(
      radius: 50,
      // Example : show an icon for default profile image
      child: Icon(Icons.person, size: 50),
    ),
  );}
              }
              return const SizedBox
                  .shrink(); // Or a placeholder widget if no image is found
            },
          ),
                    
                    const SizedBox(height: 20),
                    // Display the selected or existing profile image

                    Text(
                      'Your Profile Name: ${profileName ?? 'N/A'}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _showChangeProfileNameDialog(
                            context, profileName ?? '');
                      },
                      child: const Text('Change Profile Name'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _showChangePasswordDialog(context);
                      },
                      child: const Text('Change Password'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Your Artworks'),
                    const SizedBox(height: 10),
                    _buildUserArtworksGrid(user!.uid),
                  ],
                ),
              );
            } else {
              return const Center(child: Text('User data not found.'));
            }
          },
        ),
      ),
    );
  }

  Widget _buildUserArtworksGrid(String userId) {
    return FutureBuilder<List<Artwork>>(
      future: _getUserArtworks(userId),
      builder: (context, artworksSnapshot) {
        if (artworksSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (artworksSnapshot.hasError) {
          return Center(child: Text('Error: ${artworksSnapshot.error}'));
        } else {
          final artworks = artworksSnapshot.data ?? [];
          return GridView.builder(
            shrinkWrap: true, // Prevent GridView from taking infinite height
            physics:
                const NeverScrollableScrollPhysics(), // Disable GridView scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 16.0, // Increased spacing
            ),
            itemCount: artworks.length,
            itemBuilder: (context, index) {
  return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),

    child: ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: Image.memory(
        base64Decode(artworks[index].imageData),
        fit: BoxFit.cover,
      ),
    ),
  );
},
            
          );
        }
      },
    );
  }

  Future<DocumentSnapshot> _getProfileName(String userId) async {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  Future<void> _showChangeProfileNameDialog(
      BuildContext context, String currentName) async {
    final nameController = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .update({'name': newName});
                  setState(
                      () {}); // Rebuild the widget to update the profile name
                  Navigator.pop(context);
                } catch (e) {
                  print('Error updating profile name: $e');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(hintText: 'Enter new password'),
            obscureText: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // ... Handle password change logic here ...
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<List<Artwork>> _getUserArtworks(String userId) async {
    final artworksSnapshot = await FirebaseFirestore.instance
        .collection('artworks')
        .doc(userId) // Use userId directly
        .collection('images')
        .get();
    return artworksSnapshot.docs.map((doc) {
      final artworkData = doc.data();
      return Artwork(
        imageData: artworkData['imageData'] as String,
        artworkName: artworkData['artworkName'] as String,
      );
    }).toList();
  }
}

// Registration Screen
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  File? _imageFile; // Store the selected image

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Create user in Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: _emailController.text,
                password: _passwordController.text);

        // 2. Upload profile image to Firebase Storage (if selected)
        String? profileImageBase64;
        if (_imageFile != null) {
          final bytes = await _imageFile!.readAsBytes();
          profileImageBase64 = base64Encode(bytes);
        }

        // 3. Store user data in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text,
          'email': _emailController.text,
          'profileImageBase64': profileImageBase64, // Store image URL
        });

        // 4. Navigate to the art feed or home screen
        Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (route) => false);
      } on FirebaseAuthException catch (e) {
        //Handle registration errors
        print('Registration error: ${e.message}');
        // Show error message to the user using a SnackBar or Dialog
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Profile Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your profile name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Select Profile Image'),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                onPressed: _register,
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtFeed extends StatefulWidget {
  final String? artistName;
  const ArtFeed({super.key, this.artistName});

  @override
  ArtFeedState createState() => ArtFeedState();
}

class ArtFeedState extends State<ArtFeed> {
  List<Map<String, dynamic>> _artworksData = [];
  String _searchQuery = ''; // Add a variable to store the search query
  List<Map<String, dynamic>> _filteredArtworks = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArtworksWithArtistNames(); // Call this method in initState
  }

  @override
  Widget build(BuildContext context) {
    // Filter artworks based on search query
    _filteredArtworks = _artworksData.where((artwork) {
      final artworkName = artwork['artworkName'] as String;
      final artistName = artwork['artistName'] as String;
      final searchTerm = _searchQuery.toLowerCase();

      return artworkName.toLowerCase().contains(searchTerm) ||
          artistName.toLowerCase().contains(searchTerm);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search by artwork or artist name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildArtworksList(),
        ),
      ],
    );
  }

  Widget _buildArtworksList() {
    return ListView.builder(
      itemCount: _filteredArtworks.length, // Use filtered list
      itemBuilder: (context, index) {
        final artwork = _filteredArtworks[index]; // Use filtered list
        return ArtworkCard(
          artworkUrl: artwork['imageData'] as String,
          artworkName: artwork['artworkName'] as String,
          artistName: artwork['artistName'] as String,
          documentId: artwork['documentId'] as String,
          artistId: artwork['artistId'] as String,
          // Use artistName from map
        );
      },
    );
  }

  Future<void> _fetchArtworksWithArtistNames() async {
    try {
      final QuerySnapshot artworksSnapshot =
          await FirebaseFirestore.instance.collectionGroup('images').get();

      _artworksData = await Future.wait(artworksSnapshot.docs.map((doc) async {
        final artworkData = doc.data() as Map<String, dynamic>;
        final artistId = doc.reference.parent.parent!.id;

        // Fetch artist name from users collection
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(artistId)
            .get();

        String artistName = userSnapshot.exists
            ? userSnapshot.get('name') as String
            : 'Unknown Artist'; // Handle case where user document is not found

        return {
          'imageData': artworkData['imageData'],
          'artworkName': artworkData['artworkName'],
          'artistName': artistName, // Use fetched artist name
          'documentId': doc.id,
          'artistId': artistId,
        };
      }));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching artworks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }
}

class ArtistProfile extends StatelessWidget {
  final Artist artist;
  final int currentArtworkIndex;
  final Function(int) onArtworkChanged;
  final List<Map<String, dynamic>> artworksData;

  const ArtistProfile({
    super.key,
    required this.artist,
    required this.currentArtworkIndex,
    required this.onArtworkChanged,
    required this.artworksData,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: artist.artworks.length,
      onPageChanged: onArtworkChanged,
      itemBuilder: (context, artworkIndex) {
        if (artworkIndex < artworksData.length) {
          // Check index is within bounds
          final artworkInfo = artworksData[artworkIndex];
          return ArtworkCard(
            artworkUrl: artist.artworks[artworkIndex],
            artistName: artist.name,
            artworkName: artworkInfo['artworkName'] ?? '',
            documentId: artworkInfo['documentId'],
            artistId: artworkInfo['artistId'],
          );
        } else {
          // Handle the case where artworkIndex is out of bounds
          return const SizedBox.shrink(); // Or a placeholder widget
        }
      },
    );
  }
}

class ArtworkCard extends StatefulWidget {
  final String artworkUrl;
  final String artistName;
  final String artworkName;
  final String documentId; // Add documentId
  final String artistId; // Add artistId

  const ArtworkCard({
    super.key,
    required this.artworkUrl,
    required this.artistName,
    required this.documentId,
    required this.artistId,
    required this.artworkName,
  });

  @override
  ArtworkCardState createState() => ArtworkCardState();
}

class ArtworkCardState extends State<ArtworkCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ArtworkDetailsPage(
                      artworkUrl: widget.artworkUrl,
                      artworkName: widget.artworkName,
                      artistName: widget.artistName,
                      documentId: widget.documentId, // Pass documentId
                      artistId: widget.artistId, // Pass artistId
                    )));
      },
      child: Card(
        child: Column(children: [
          Hero(
            tag: widget.artworkUrl, // Same tag as in FullScreenImage
            child: Image.memory(
              base64Decode(widget.artworkUrl),
              fit: BoxFit.cover,
            ),
          ),
          // Display profile image (if available)
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.artistId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data!.data() != null) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                if (userData['profileImageBase64'] != null) {
                  return CircleAvatar(
                    backgroundImage: MemoryImage(
                        base64Decode(userData['profileImageBase64'] as String)),
                  );
                }else {
  return const CircleAvatar(
    // Example : show an icon for default profile image
    child: Icon(Icons.person),
  );}
              }
              return const SizedBox
                  .shrink(); // Or a placeholder widget if no image is found
            },
          ),
          Text(widget.artistName), // Display artist name
          Text(widget.artworkName),
          //LikeButton(artworkUrl: widget.artworkUrl),
        ]),
      ),
    );
  }

  /*Future<void> _toggleLike() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final likeRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('likedArtworks')
            .doc(widget.artworkUrl); // Assuming artworkUrl as artworkId

        final likeDoc = await likeRef.get();
        if (likeDoc.exists) {
          await likeRef.delete(); // Unlike
        } else {
          await likeRef.set({'liked': true}); // Like
        }
      } else {
        print('User not logged in');
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }*/
}

// Define the Artwork class here
class Artwork {
  final String
      imageData; // Store base64 encoded images, make it required in constructor
  final String artworkName; // Store the artwork's name, make it required

  Artwork(
      {required this.imageData,
      required this.artworkName}); // Required parameters
}

class Artist {
  final String name;
  final List<String> artworks;

  Artist({required this.name, required this.artworks});
}

class LikeButton extends StatefulWidget {
  final String artworkUrl;

  const LikeButton({super.key, required this.artworkUrl});

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
    _getLikeCount();
  }

  Future<void> _checkLikeStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final likeRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('likedArtworks')
            .doc(widget.artworkUrl);

        final likeDoc = await likeRef.get();
        setState(() {
          _isLiked = likeDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _getLikeCount() async {
    try {
      // Get the artwork document using artworkUrl (assuming artworkUrl is formatted as {userUID}/{imageUID})
      final artworkIdParts = widget.artworkUrl.split('/');
      final userUid = artworkIdParts[0];
      final imageUid = artworkIdParts[1];

      final artworkDoc = await FirebaseFirestore.instance
          .collection('artworks')
          .doc(userUid)
          .collection('images')
          .doc(imageUid)
          .get();

      setState(() {
        _likeCount = artworkDoc.get('likeCount') ?? 0;
      });
    } catch (e) {
      print('Error getting like count: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final likeRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('likedArtworks')
            .doc(widget.artworkUrl);

        // Get the artwork document using artworkUrl (assuming artworkUrl is formatted as {userUID}/{imageUID})
        final artworkIdParts = widget.artworkUrl.split('/');
        final userUid = artworkIdParts[0];
        final imageUid = artworkIdParts[1];

        final artworkRef = FirebaseFirestore.instance
            .collection('artworks')
            .doc(userUid)
            .collection('images')
            .doc(imageUid);

        // Perform the like/unlike and like count update atomically using a transaction

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final likeDoc = await transaction.get(likeRef);

          if (likeDoc.exists) {
            transaction.delete(likeRef);
            transaction
                .update(artworkRef, {'likeCount': FieldValue.increment(-1)});
            setState(() {
              _isLiked = false;
              _likeCount--;
            });
          } else {
            transaction.set(likeRef, {'liked': true});
            transaction
                .update(artworkRef, {'likeCount': FieldValue.increment(1)});
            setState(() {
              _isLiked = true;
              _likeCount++;
            });
          }
        });

        _checkLikeStatus(); // Refresh like status
        _getLikeCount(); // Refresh like count
      } else {
        print('User not logged in');
      }
    } catch (e) {
      print('Error toggling like: $e');
      // Handle error, maybe show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
          onPressed: _toggleLike,
        ),
        Text(_likeCount.toString()), // Display like count
      ],
    );
  }
}

class ArtworkDetailsPage extends StatefulWidget {
  final String artworkUrl;
  final String artworkName;
  final String artistName;
  final String? documentId;
  final String? artistId;

  const ArtworkDetailsPage({
    super.key,
    required this.artworkUrl,
    required this.artworkName,
    required this.artistName,
    required this.documentId,
    required this.artistId,
  });

  @override
  State<ArtworkDetailsPage> createState() => _ArtworkDetailsPageState();
}

class _ArtworkDetailsPageState extends State<ArtworkDetailsPage> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          if (widget.artistId != null && widget.documentId != null) {
            await FirebaseFirestore.instance
                .collection('artworks')
                .doc(widget.artistId)
                .collection('images')
                .doc(widget.documentId)
                .collection('comments')
                .add({
              'comment': commentText,
              'userId': user.uid,
              'timestamp': FieldValue.serverTimestamp(),
            });
            _commentController.clear();
            _fetchComments(); // Refresh comments after adding
          }
        }
      } catch (e) {
        print('Error adding comment: $e');
      }
    }
  }

  Future<void> _fetchComments() async {
    try {
      if (widget.artistId != null && widget.documentId != null) {
        final commentsSnapshot = await FirebaseFirestore.instance
            .collection('artworks')
            .doc(widget.artistId)
            .collection('images')
            .doc(widget.documentId)
            .collection('comments')
            .orderBy('timestamp', descending: true)
            .get();

        setState(() {
          _comments = commentsSnapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      print('Error fetching comments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artworkName),
      ),
      body: SingleChildScrollView(
        child: Column(children: <Widget>[
          Image.memory(
            base64Decode(widget.artworkUrl),
            fit: BoxFit.cover,
            // Adjust the fit as needed
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Artist: ${widget.artistName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getCommentsWithUsernames(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                final commentsWithUsernames = snapshot.data!;
                return _buildCommentsList(commentsWithUsernames);
              } else {
                return const Center(child: Text('No comments yet.'));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration:
                        const InputDecoration(hintText: 'Add a comment'),
                  ),
                ),
                ElevatedButton(
                  onPressed: _addComment,
                  child: const Text('Post'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getCommentsWithUsernames() async {
    List<Map<String, dynamic>> commentsWithUsernames = [];

    if (widget.artistId != null && widget.documentId != null) {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('artworks')
          .doc(widget.artistId)
          .collection('images')
          .doc(widget.documentId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in commentsSnapshot.docs) {
        final commentData = doc.data();
        final userId = commentData['userId'] as String;

        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        final username = userSnapshot.exists
            ? userSnapshot.get('name') as String
            : 'Unknown User';

        final timestamp = commentData['timestamp'] as Timestamp?;
        final formattedTimestamp = timestamp != null
            ? timestamp.toDate().toString()
            : 'N/A'; // Format timestamp

        commentsWithUsernames.add({
          'comment': commentData['comment'],
          'username': username,
          'timestamp': formattedTimestamp,
        });
      }
    }
    return commentsWithUsernames;
  }

  Widget _buildCommentsList(List<Map<String, dynamic>> comments) {
    return SizedBox(
      height: 200, // Adjust the height as needed
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: comments.length,
        itemBuilder: (context, index) {
          final comment = comments[index];
          return ListTile(
            title: Text(comment['comment']),
            subtitle:
                Text('By ${comment['username']} - ${comment['timestamp']}'),
          );
        },
      ),
    );
  }
}
