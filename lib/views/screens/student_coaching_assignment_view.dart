import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/coaching_assignment_models.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentCoachingAssignmentView extends ConsumerStatefulWidget {
  const StudentCoachingAssignmentView({super.key});

  @override
  ConsumerState<StudentCoachingAssignmentView> createState() => _StudentCoachingAssignmentViewState();
}

class _StudentCoachingAssignmentViewState extends ConsumerState<StudentCoachingAssignmentView> {
  final _formKey = GlobalKey<FormState>();
  final _admissionCodeController = TextEditingController();
  String? _selectedCoachingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentCoachingAssignmentControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _admissionCodeController.dispose();
    super.dispose();
  }

  bool _canSubmit(CoachingAssignmentFormData data) {
    if (data.assignment.hasActiveAssignment) {
      return false;
    }
    if ((data.assignment.requestStatus ?? '').toLowerCase() == 'pending') {
      return false;
    }
    return true;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Future<void> _submit(CoachingAssignmentFormData data) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedId = _selectedCoachingId;
    if (selectedId == null || selectedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a coaching center.')),
      );
      return;
    }

    final ok = await ref
        .read(studentCoachingAssignmentControllerProvider.notifier)
        .submitRequest(
          coachingId: selectedId,
          admissionCode: _admissionCodeController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    final state = ref.read(studentCoachingAssignmentControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (state.lastSuccessMessage ?? 'Request submitted successfully.')
              : (state.errorMessage ?? 'Request could not be submitted.'),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentCoachingAssignmentControllerProvider);
    final data = state.formData;

    if (data != null &&
        (_selectedCoachingId == null || _selectedCoachingId!.isEmpty)) {
      _selectedCoachingId =
          data.assignment.currentRequest?.coachingId ??
          data.assignment.activeCoachingId;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Coaching Assignment')),
      body: AsyncView(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        onRetry: () => ref
            .read(studentCoachingAssignmentControllerProvider.notifier)
            .load(),
        child: data == null
            ? const EmptyStateView(
                title: 'No Assignment Data',
                message: 'Could not load coaching assignment information.',
              )
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(studentCoachingAssignmentControllerProvider.notifier)
                    .load(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    SectionCard(
                      title: 'Student Details',
                      icon: Icons.person,
                      child: Column(
                        children: <Widget>[
                          InfoRow(
                            label: 'Name',
                            value: data.prefilled.name,
                            icon: Icons.badge,
                          ),
                          InfoRow(
                            label: 'Email',
                            value: data.prefilled.email,
                            icon: Icons.email,
                          ),
                          InfoRow(
                            label: 'Current Mode',
                            value: data.prefilled.studentMode,
                            icon: Icons.account_tree,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (data.assignment.currentRequest != null)
                      SectionCard(
                        title: 'Current Request Status',
                        icon: Icons.pending_actions,
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Text('Status: '),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      data.assignment.currentRequest!.status,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    data.assignment.currentRequest!.status
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: _statusColor(
                                        data.assignment.currentRequest!.status,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data
                                      .assignment
                                      .currentRequest!
                                      .decisionNote
                                      .isEmpty
                                  ? 'No decision note provided yet.'
                                  : data
                                        .assignment
                                        .currentRequest!
                                        .decisionNote,
                            ),
                          ],
                        ),
                      ),
                    if (data.assignment.hasActiveAssignment)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionCard(
                          title: 'Assigned Coaching',
                          icon: Icons.apartment,
                          child: data.assignment.activeCoaching == null
                              ? const Text(
                                  'You are already assigned to a coaching center.',
                                )
                              : _AssignedCoachingDetails(
                                  coaching: data.assignment.activeCoaching!,
                                ),
                        ),
                      ),
                    SectionCard(
                      title: 'Request Coaching Assignment',
                      icon: Icons.assignment,
                      child: data.coachings.isEmpty
                          ? const EmptyStateView(
                              title: 'No Coachings Available',
                              message:
                                  'No registered coaching centers found yet.',
                              icon: Icons.search_off,
                            )
                          : Form(
                              key: _formKey,
                              child: Column(
                                children: <Widget>[
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedCoachingId,
                                    decoration: InputDecoration(
                                      labelText: 'Select Coaching Center',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                    ),
                                    items: data.coachings
                                        .map(
                                          (coaching) =>
                                              DropdownMenuItem<String>(
                                                value: coaching.id,
                                                child: Text(coaching.name),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: _canSubmit(data)
                                        ? (value) => setState(() {
                                            _selectedCoachingId = value;
                                          })
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  FormInputField(
                                    controller: _admissionCodeController,
                                    label: 'Admission Code',
                                    prefixIcon: Icons.pin,
                                    validator: (value) {
                                      if ((value ?? '').trim().length < 2) {
                                        return 'Admission code must be at least 2 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  if (!_canSubmit(data))
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        data.assignment.hasActiveAssignment
                                            ? 'You are already assigned to a coaching center.'
                                            : 'You already have a pending request. Please wait for a decision.',
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  PrimaryButton(
                                    label: state.isSubmitting
                                        ? 'Submitting Request...'
                                        : 'Submit Assignment Request',
                                    icon: Icons.send,
                                    isLoading: state.isSubmitting,
                                    isEnabled:
                                        !state.isSubmitting && _canSubmit(data),
                                    onPressed: () => _submit(data),
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

class _AssignedCoachingDetails extends StatelessWidget {
  const _AssignedCoachingDetails({required this.coaching});

  final CoachingCenterOption coaching;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InfoRow(label: 'Name', value: coaching.name, icon: Icons.business),
        if (coaching.address.isNotEmpty)
          InfoRow(label: 'Address', value: coaching.address, icon: Icons.place),
        if (coaching.contactEmail.isNotEmpty)
          InfoRow(
            label: 'Email',
            value: coaching.contactEmail,
            icon: Icons.email,
          ),
        if (coaching.contactPhone.isNotEmpty)
          InfoRow(
            label: 'Phone',
            value: coaching.contactPhone,
            icon: Icons.phone,
          ),
      ],
    );
  }
}




