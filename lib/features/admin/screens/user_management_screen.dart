import 'package:flutter/material.dart';

import '../../../services/dio_client.dart';

/// Staff accounts are created and managed by the school admin in FastAPI.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _staffRoles = [
    'SCHOOL_ADMIN',
    'TEACHER',
    'ACCOUNTANT',
    'TRANSPORT_MANAGER',
  ];

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await DioClient.get('/users');
      final users = (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => _staffRoles.contains(item['role']))
          .toList();
      if (mounted) setState(() => _users = users);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? user]) async {
    final name = TextEditingController(text: user?['fullName']?.toString() ?? '');
    final email = TextEditingController(text: user?['email']?.toString() ?? '');
    final phone = TextEditingController(text: user?['phone']?.toString() ?? '');
    final password = TextEditingController();
    var role = user?['role']?.toString() ?? 'TEACHER';
    var saving = false;
    final formKey = GlobalKey<FormState>();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: Text(user == null ? 'Add staff account' : 'Edit staff account'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    TextFormField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null ||
                              !value.contains('@') ||
                              value.trim().endsWith('@')
                          ? 'Enter a valid email'
                          : null,
                    ),
                    TextFormField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _staffRoles
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.replaceAll('_', ' ')),
                              ))
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => updateDialog(() => role = value ?? role),
                    ),
                    TextFormField(
                      controller: password,
                      decoration: InputDecoration(
                        labelText: user == null
                            ? 'Initial password'
                            : 'New password (leave blank to keep current)',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (user == null && (value == null || value.isEmpty)) {
                          return 'Enter a password';
                        }
                        if (value != null && value.isNotEmpty && value.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ]),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        updateDialog(() => saving = true);
                        final payload = {
                          'fullName': name.text.trim(),
                          'email': email.text.trim(),
                          'phone': phone.text.trim(),
                          'role': role,
                          'linkedEntityId': null,
                          'extraPermissions': user?['extraPermissions'] ?? <String>[],
                          if (password.text.isNotEmpty) 'password': password.text,
                        };
                        try {
                          if (user == null) {
                            await DioClient.post('/users', data: payload);
                          } else {
                            await DioClient.put('/users/${user['id']}', data: payload);
                          }
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          await _load();
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Could not save: $error')));
                            updateDialog(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
      email.dispose();
      phone.dispose();
      password.dispose();
    }
  }

  Future<void> _deactivate(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Text('${user['fullName']} will no longer be able to sign in.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DioClient.delete('/users/${user['id']}');
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not deactivate account: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff accounts')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.person_add),
          label: const Text('Add staff')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Could not load staff accounts: $_error'),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user['fullName']?.toString() ?? ''),
                        subtitle: Text(
                            '${user['email'] ?? ''} · ${user['role']?.toString().replaceAll('_', ' ') ?? ''}'),
                        onTap: () => _edit(user),
                        trailing: IconButton(
                          tooltip: 'Deactivate',
                          icon: const Icon(Icons.person_off_outlined),
                          onPressed: () => _deactivate(user),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
