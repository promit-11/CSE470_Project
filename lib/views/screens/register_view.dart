import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/auth_models.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _instituteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.student;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Create Your Account'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Theme.of(context).colorScheme.primary.withValues(),
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Get Started',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create an account to access IELTS practice tests',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        FormInputField(
                          controller: _nameController,
                          label: 'Full Name',
                          prefixIcon: Icons.person,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        FormInputField(
                          controller: _emailController,
                          label: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        FormInputField(
                          controller: _passwordController,
                          label: 'Password',
                          obscureText: true,
                          prefixIcon: Icons.lock,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Use at least 8 characters';
                            }
                            if (!RegExp(
                              r'(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
                            ).hasMatch(value)) {
                              return 'Use uppercase, lowercase, and a number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 13),
                        DropdownButtonFormField<UserRole>(
                          initialValue: _selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Account Type',
                            prefixIcon: const Icon(Icons.security),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          items: const <DropdownMenuItem<UserRole>>[
                            DropdownMenuItem(
                              value: UserRole.student,
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.teacher,
                              child: Text('Teacher'),
                            ),
                            DropdownMenuItem(
                              value: UserRole.coachingAdmin,
                              child: Text('Coaching Center Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedRole = value);
                            }
                          },
                        ),
                        if (_selectedRole ==
                            UserRole.coachingAdmin) ...<Widget>[
                          const SizedBox(height: 16),
                          FormInputField(
                            controller: _instituteController,
                            label: 'Institute Name',
                            prefixIcon: Icons.business,
                            validator: (value) {
                              if (_selectedRole != UserRole.coachingAdmin) {
                                return null;
                              }
                              if (value == null || value.trim().length < 2) {
                                return 'Institute name is required';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (auth.errorMessage != null) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    auth.errorMessage!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        PrimaryButton(
                          label: auth.isLoading
                              ? 'Creating account...'
                              : 'Register',
                          isLoading: auth.isLoading,
                          isEnabled: !auth.isLoading,
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }
                            final ok = await ref
                                .read(authControllerProvider.notifier)
                                .register(
                                  name: _nameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                  role: _selectedRole,
                                  instituteName: _instituteController.text,
                                );
                            if (!context.mounted || !ok) {
                              return;
                            }
                            final user = ref
                                .read(authControllerProvider)
                                .currentUser;
                            if (_selectedRole == UserRole.teacher) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.teacherPendingApproval,
                                (_) => false,
                                arguments: _emailController.text.trim(),
                              );
                              return;
                            }
                            if (user == null) {
                              return;
                            }
                            if (user.isStudent) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.studentDashboard,
                                (_) => false,
                              );
                            } else if (user.isTeacher) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.teacherDashboard,
                                (_) => false,
                              );
                            } else {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.coachingDashboard,
                                (_) => false,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'Already have an account? ',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Sign in'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}




