import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState  extends State<ProfilePage> {
  File? _image;
  var doc = FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser?.uid);
  final picker = ImagePicker();
  
  void _getData() async{
    var document = await doc.get();
    if(document.exists){
      var data = document.data();
      _nameController.text = data?['name'];
      _emailController.text = data?['email'];
      _phoneController.text = data?['phone'];
      _addressController.text = data?['address'];
    }
  }

  @override
  void initState() {
    super.initState();
    _getData();
  }


  final TextEditingController _nameController = TextEditingController(text: '');
  final TextEditingController _emailController = TextEditingController(text: '');
  final TextEditingController _phoneController = TextEditingController(text: '');
  final TextEditingController _addressController = TextEditingController(text: '');

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _save() async {
    try{
      if(_nameController.text.isEmpty){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name cannot be empty")));
        return;
      }
      if(_phoneController.text.isEmpty){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone number cannot be empty")));
        return;
      }
      if(_addressController.text.isEmpty){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Address cannot be empty")));
        return;
      }

      await doc.update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated")));
    }catch(e){
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed, Try again later")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: _image != null
                    ? FileImage(_image!)
                    : const NetworkImage('https://avatar.iran.liara.run/public'),
                child: _image == null
                    ? Icon(Icons.camera_alt, size: 30, color: Colors.grey[700])
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            _buildTextField('Full Name', _nameController, isDark),
            const SizedBox(height: 20),
            _buildTextField('Email', _emailController, isDark, readOnly: true),
            const SizedBox(height: 20),
            _buildTextField('Phone Number', _phoneController, isDark),
            const SizedBox(height: 20),
            _buildTextField('Address', _addressController, isDark, maxLines: 2),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // Save profile logic
                  _save();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Save", style: GoogleFonts.inter(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {bool readOnly = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[800])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black),
        ),
      ],
    );
  }
}
