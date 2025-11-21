import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    await Future.delayed(Duration(milliseconds: 200));

    final bool isValid = await AuthService.login(username, password);

    setState(() => _isLoading = false);

    if (isValid) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Identifiants invalides. Veuillez réessayer.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // backgroundColor: Colors.white10,
      backgroundColor: Color(0xFF1A1A1A),  // Noir explicite au lieu de Colors.white10

      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Icon(
                  Icons.business,
                  size: 100,
               //   color: Theme.of(context).primaryColor,
                  color: roseVE,
                ),
                SizedBox(height: 24),
                Text(
                  'Versant Event',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Connexion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 48),

                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Nom d\'utilisateur',

                    prefixIcon: Icon(Icons.person),
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: greyAmont,

                      ),
                    ),

                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: roseVE,
                      ),
                    ),
                    floatingLabelStyle: TextStyle(
                      color: roseVE,
                    ),


                  ),
                  style: TextStyle(
                     color: Colors.white,
                  ),
                   validator: (value) =>
                  value!.isEmpty ? 'Entrez votre identifiant' : null,
                  enabled: !_isLoading,
                ),
                SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock),
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: greyAmont,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: roseVE,
                      ),
                    ),
                      suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    floatingLabelStyle: TextStyle(
                      color: roseVE,
                    ),

                  ),
                  style: TextStyle(
                     color: Colors.white,
                  ),
                  validator: (value) =>
                  value!.isEmpty ? 'Entrez votre mot de passe' : null,
                  enabled: !_isLoading,
                ),
                SizedBox(height: 32),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    'Se connecter',
                    style: TextStyle(fontSize: 18, color: roseVE),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}