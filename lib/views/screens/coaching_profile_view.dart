import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachingProfileView extends ConsumerStatefulWidget {
  const CoachingProfileView({super.key});

  @override
  ConsumerState<CoachingProfileView> createState() => _CoachingProfileViewState();
}

class _CoachingProfileViewState extends ConsumerState<CoachingProfileView> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  bool _profileHydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _showActionFeedback() {
    final latest = ref.read(instituteControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          latest.errorMessage == null
              ? 'Profile updated successfully.'
              : latest.errorMessage!,
        ),
        backgroundColor: latest.errorMessage == null
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(instituteControllerProvider);

    if (!_profileHydrated && state.profile != null) {
      _profileHydrated = true;
      _name.text = (state.profile?['name'] ?? '').toString();
      _description.text = (state.profile?['description'] ?? '').toString();
      _address.text = (state.profile?['address'] ?? '').toString();
      _phone.text = (state.profile?['contactPhone'] ?? '').toString();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Coaching Profile')),
      body: AsyncView(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        onRetry: () => ref.read(instituteControllerProvider.notifier).load(),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(instituteControllerProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Edit Coaching Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Center Name',
                          hintText: 'e.g., Bright IELTS Academy',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Brief description of your coaching center',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Physical location',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone',
                          hintText: 'Phone number',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: state.isWorking
                            ? null
                            : () async {
                                if (_name.text.trim().length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Center name must be at least 2 characters.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                await ref
                                    .read(instituteControllerProvider.notifier)
                                    .updateProfile({
                                      'name': _name.text.trim(),
                                      'description': _description.text.trim(),
                                      'address': _address.text.trim(),
                                      'contactPhone': _phone.text.trim(),
                                    });
                                if (!mounted) return;
                                _showActionFeedback();
                              },
                        icon: const Icon(Icons.save),
                        label: Text(
                          state.isWorking ? 'Saving...' : 'Save Profile',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Quick Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoRow(
                        label: 'Coaching ID',
                        value: (state.profile?['_id'] ?? 'N/A').toString(),
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Status',
                        value: 'Active',
                        icon: Icons.check_circle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




