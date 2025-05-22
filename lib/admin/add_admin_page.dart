// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'admin_service.dart'; // Import AdminService
import 'admin.dart'; // Import Admin model

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  @override
  _AddAdminPageState createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final AdminService _adminService = AdminService();

  void _saveAdmin() async {
    String name = _nameController.text;
    String email = _emailController.text;

    String adminId = email;

    Admin admin = Admin(id: adminId, name: name, email: email);

    await _adminService.addAdmin(admin);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Admin added successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Admin")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Admin Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Admin Email'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveAdmin,
              child: const Text("Save Admin"),
            ),
          ],
        ),
      ),
    );
  }
}
