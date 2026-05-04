import 'dart:convert';

import 'package:cse470_app/controllers/admin_dashboard_controller.dart';
import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/core/utils/ielts_sections.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdminDashboardSection {
  overview,
  evaluationStats,
  teacherQueue,
  content,
  database,
  payouts,
  notes,
}

extension AdminDashboardSectionX on AdminDashboardSection {
  String get title {
    switch (this) {
      case AdminDashboardSection.overview:
        return 'Overview Counts';
      case AdminDashboardSection.evaluationStats:
        return 'Evaluation Request Statistics';
      case AdminDashboardSection.teacherQueue:
        return 'Teacher Approval Queue';
      case AdminDashboardSection.content:
        return 'App-Owned Content Management';
      case AdminDashboardSection.database:
        return 'Database Manager';
      case AdminDashboardSection.payouts:
        return 'Payout Review Queue';
      case AdminDashboardSection.notes:
        return 'Decision Notes';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminDashboardSection.overview:
        return Icons.dashboard;
      case AdminDashboardSection.evaluationStats:
        return Icons.query_stats;
      case AdminDashboardSection.teacherQueue:
        return Icons.how_to_reg;
      case AdminDashboardSection.content:
        return Icons.inventory_2;
      case AdminDashboardSection.database:
        return Icons.storage;
      case AdminDashboardSection.payouts:
        return Icons.account_balance_wallet;
      case AdminDashboardSection.notes:
        return Icons.notes;
    }
  }
}

class AdminExamWorkspaceView extends ConsumerStatefulWidget {
  const AdminExamWorkspaceView({super.key, this.section});

  final AdminDashboardSection? section;

  @override
  ConsumerState<AdminExamWorkspaceView> createState() => _AdminExamWorkspaceViewState();
}

class _AdminExamWorkspaceViewState extends ConsumerState<AdminExamWorkspaceView> {
  final _examTitle = TextEditingController();
  final _questionTitle = TextEditingController();
  final _questionContent = TextEditingController();
  final _questionAudioUrl = TextEditingController();
  final _templateName = TextEditingController();
  final _templateEasyRatio = TextEditingController(text: '0.3');
  final _templateMediumRatio = TextEditingController(text: '0.4');
  final _templateHardRatio = TextEditingController(text: '0.3');
  final _templateListening = TextEditingController(text: '40');
  final _templateReading = TextEditingController(text: '40');
  final _templateWriting = TextEditingController(text: '2');
  final _templateSpeaking = TextEditingController(text: '3');
  final _teacherDecisionNote = TextEditingController();
  final _payoutDecisionNote = TextEditingController();
  final _dbSearchController = TextEditingController();
  PlatformFile? _selectedListeningAudioFile;

  String _selectedSection = IeltsSections.reading;
  String _templateExamType = 'academic';
  String _selectedDbCollection = 'users';
  int _dbPage = 1;
  final int _dbLimit = 15;
  int _dbTotal = 0;
  bool _dbLoading = false;
  List<Map<String, dynamic>> _dbCollectionSummaries =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _dbDocuments = const <Map<String, dynamic>>[];

  static const List<String> _allowedListeningExtensions = <String>[
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'webm',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminDashboardControllerProvider.notifier).load();
      _loadDatabaseCollections(refreshDocuments: true);
    });
  }

  @override
  void dispose() {
    _examTitle.dispose();
    _questionTitle.dispose();
    _questionContent.dispose();
    _questionAudioUrl.dispose();
    _templateName.dispose();
    _templateEasyRatio.dispose();
    _templateMediumRatio.dispose();
    _templateHardRatio.dispose();
    _templateListening.dispose();
    _templateReading.dispose();
    _templateWriting.dispose();
    _templateSpeaking.dispose();
    _teacherDecisionNote.dispose();
    _payoutDecisionNote.dispose();
    _dbSearchController.dispose();
    super.dispose();
  }

  String _sectionLabel(String section) {
    final normalized = IeltsSections.normalize(section);
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  int _count(Map<String, dynamic>? overview, String key, {int fallback = 0}) {
    return (overview?[key] as num?)?.toInt() ?? fallback;
  }

  void _showActionFeedback() {
    final latest = ref.read(adminDashboardControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          latest.errorMessage == null
              ? 'Operation completed successfully.'
              : latest.errorMessage!,
        ),
        backgroundColor: latest.errorMessage == null
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  String _examTitleById(AdminDashboardState state, String? examId) {
    final normalizedId = (examId ?? '').toString();
    if (normalizedId.isEmpty) {
      return 'App-Owned';
    }
    final exam = state.exams.firstWhere(
      (item) => (item['_id'] ?? '').toString() == normalizedId,
      orElse: () => const <String, dynamic>{},
    );
    return (exam['title'] ?? 'Linked Exam').toString();
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showCreateStudentDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final creditsController = TextEditingController(text: '20');

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Student'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: creditsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Starting credits',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (shouldCreate != true) {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
      creditsController.dispose();
      return;
    }

    await ref
        .read(adminDashboardControllerProvider.notifier)
        .createStudent(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
          testCredits: int.tryParse(creditsController.text.trim()) ?? 20,
        );
    if (!mounted) return;
    _showActionFeedback();
    await _loadDatabaseCollections(refreshDocuments: true);

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    creditsController.dispose();
  }

  Future<void> _showCreateTeacherDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Teacher'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (shouldCreate != true) {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
      return;
    }

    await ref
        .read(adminDashboardControllerProvider.notifier)
        .createTeacher(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
        );
    if (!mounted) return;
    _showActionFeedback();
    await _loadDatabaseCollections(refreshDocuments: true);

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _showCreateCoachingDialog() async {
    final instituteController = TextEditingController();
    final adminNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Coaching'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: instituteController,
                decoration: const InputDecoration(labelText: 'Institute name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: adminNameController,
                decoration: const InputDecoration(labelText: 'Admin name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Admin email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Admin password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact phone (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (shouldCreate != true) {
      instituteController.dispose();
      adminNameController.dispose();
      emailController.dispose();
      passwordController.dispose();
      descriptionController.dispose();
      addressController.dispose();
      phoneController.dispose();
      return;
    }

    await ref
        .read(adminDashboardControllerProvider.notifier)
        .createCoaching(
          adminName: adminNameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
          instituteName: instituteController.text.trim(),
          description: descriptionController.text.trim(),
          address: addressController.text.trim(),
          contactPhone: phoneController.text.trim(),
        );
    if (!mounted) return;
    _showActionFeedback();
    await _loadDatabaseCollections(refreshDocuments: true);

    instituteController.dispose();
    adminNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    phoneController.dispose();
  }

  Future<void> _showCreateQuestionForExamDialog(
    AdminDashboardState state,
    Map<String, dynamic> exam,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final examId = (exam['_id'] ?? '').toString();
    if (examId.isEmpty) {
      return;
    }

    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final audioUrlController = TextEditingController();
    final optionAController = TextEditingController();
    final optionBController = TextEditingController();
    final optionCController = TextEditingController();
    final optionDController = TextEditingController();
    final answerKeyController = TextEditingController(text: 'A');
    var section = IeltsSections.reading;
    PlatformFile? selectedAudio;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final isListening = _isListeningSection(section);
          return AlertDialog(
            title: Text(
              'Add Question to ${(exam['title'] ?? 'Exam').toString()}',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: section,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: IeltsSections.values
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_sectionLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() {
                        section = value;
                        if (!_isListeningSection(section)) {
                          selectedAudio = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Question title',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Question content',
                    ),
                  ),
                  if (section == IeltsSections.reading ||
                      section == IeltsSections.listening) ...<Widget>[
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionAController,
                      decoration: const InputDecoration(labelText: 'Option A'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionBController,
                      decoration: const InputDecoration(labelText: 'Option B'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionCController,
                      decoration: const InputDecoration(labelText: 'Option C'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: optionDController,
                      decoration: const InputDecoration(labelText: 'Option D'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Correct answer key(s)',
                        helperText:
                            'Use commas for multiple correct answers, for example A or A,C',
                      ),
                    ),
                  ],
                  if (isListening) ...<Widget>[
                    const SizedBox(height: 8),
                    TextField(
                      controller: audioUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Listening media URL fallback',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: _allowedListeningExtensions,
                              withData: true,
                            );
                            if (picked == null || picked.files.isEmpty) {
                              return;
                            }
                            setLocalState(() {
                              selectedAudio = picked.files.first;
                            });
                          },
                          icon: const Icon(Icons.audio_file_outlined),
                          label: Text(
                            selectedAudio == null
                                ? 'Upload Audio'
                                : 'Replace Audio',
                          ),
                        ),
                        if (selectedAudio != null)
                          OutlinedButton(
                            onPressed: () => setLocalState(() {
                              selectedAudio = null;
                            }),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedAudio == null
                          ? 'No audio file selected.'
                          : 'Selected file: ${selectedAudio!.name}',
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) {
      titleController.dispose();
      contentController.dispose();
      audioUrlController.dispose();
      optionAController.dispose();
      optionBController.dispose();
      optionCController.dispose();
      optionDController.dispose();
      answerKeyController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      titleController.dispose();
      contentController.dispose();
      audioUrlController.dispose();
      optionAController.dispose();
      optionBController.dispose();
      optionCController.dispose();
      optionDController.dispose();
      answerKeyController.dispose();
      return;
    }

    final isObjectiveQuestion =
        section == IeltsSections.reading || section == IeltsSections.listening;
    final optionValues = <Map<String, String>>[
      {'key': 'A', 'text': optionAController.text.trim()},
      {'key': 'B', 'text': optionBController.text.trim()},
      {'key': 'C', 'text': optionCController.text.trim()},
      {'key': 'D', 'text': optionDController.text.trim()},
    ];
    final options = isObjectiveQuestion
        ? optionValues.where((option) => option['text']!.isNotEmpty).toList()
        : <Map<String, String>>[];
    final answerKey = isObjectiveQuestion
        ? answerKeyController.text
              .split(RegExp(r'[;,\n\s]+'))
              .map((value) => value.trim().toUpperCase())
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];

    if (isObjectiveQuestion && (options.length < 2 || answerKey.isEmpty)) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Reading and listening questions need options and at least one correct answer key.',
          ),
        ),
      );
      titleController.dispose();
      contentController.dispose();
      audioUrlController.dispose();
      optionAController.dispose();
      optionBController.dispose();
      optionCController.dispose();
      optionDController.dispose();
      answerKeyController.dispose();
      return;
    }

    final payload = <String, dynamic>{
      'section': section,
      'category': 'general',
      'difficulty': 'medium',
      'questionType': isObjectiveQuestion ? 'multiple_choice' : 'text',
      'title': title,
      'content': content,
      'options': options,
      'answerKey': answerKey,
      'examId': examId,
    };

    final audioUrl = audioUrlController.text.trim();
    if (_isListeningSection(section) && audioUrl.isNotEmpty) {
      payload['mediaUrl'] = audioUrl;
    }

    await ref
        .read(adminDashboardControllerProvider.notifier)
        .createQuestionForExam(
          examId,
          payload,
          listeningAudioFile: _isListeningSection(section)
              ? selectedAudio
              : null,
        );
    if (!mounted) return;
    _showActionFeedback();

    titleController.dispose();
    contentController.dispose();
    audioUrlController.dispose();
    optionAController.dispose();
    optionBController.dispose();
    optionCController.dispose();
    optionDController.dispose();
    answerKeyController.dispose();
  }

  Future<void> _showCreateTemplateForExamDialog(
    AdminDashboardState state,
    Map<String, dynamic> exam,
  ) async {
    final examId = (exam['_id'] ?? '').toString();
    if (examId.isEmpty) {
      return;
    }

    final nameController = TextEditingController();
    final easyController = TextEditingController(text: '0.3');
    final mediumController = TextEditingController(text: '0.4');
    final hardController = TextEditingController(text: '0.3');
    final listeningController = TextEditingController(text: '40');
    final readingController = TextEditingController(text: '40');
    final writingController = TextEditingController(text: '2');
    final speakingController = TextEditingController(text: '3');
    var examType = (exam['type'] ?? 'academic').toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(
            'Add Template to ${(exam['title'] ?? 'Exam').toString()}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Template name'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: examType,
                  decoration: const InputDecoration(labelText: 'Exam type'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'academic',
                      child: Text('Academic'),
                    ),
                    DropdownMenuItem(value: 'general', child: Text('General')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => examType = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: easyController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Easy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: mediumController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Medium'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hardController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Hard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: listeningController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Listening',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: readingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Reading'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: writingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Writing'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: speakingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Speaking',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      nameController.dispose();
      easyController.dispose();
      mediumController.dispose();
      hardController.dispose();
      listeningController.dispose();
      readingController.dispose();
      writingController.dispose();
      speakingController.dispose();
      return;
    }

    final name = nameController.text.trim();
    if (name.isEmpty) {
      nameController.dispose();
      easyController.dispose();
      mediumController.dispose();
      hardController.dispose();
      listeningController.dispose();
      readingController.dispose();
      writingController.dispose();
      speakingController.dispose();
      return;
    }

    await ref
        .read(adminDashboardControllerProvider.notifier)
        .createTemplateForExam(examId, {
          'name': name,
          'examType': examType,
          'sectionOrder': ['listening', 'reading', 'writing', 'speaking'],
          'difficultyDistribution': {
            'easy': double.tryParse(easyController.text.trim()) ?? 0,
            'medium': double.tryParse(mediumController.text.trim()) ?? 0,
            'hard': double.tryParse(hardController.text.trim()) ?? 0,
          },
          'sectionQuestionCount': {
            'listening': int.tryParse(listeningController.text.trim()) ?? 40,
            'reading': int.tryParse(readingController.text.trim()) ?? 40,
            'writing': int.tryParse(writingController.text.trim()) ?? 2,
            'speaking': int.tryParse(speakingController.text.trim()) ?? 3,
          },
          'active': true,
        });
    if (!mounted) return;
    _showActionFeedback();

    nameController.dispose();
    easyController.dispose();
    mediumController.dispose();
    hardController.dispose();
    listeningController.dispose();
    readingController.dispose();
    writingController.dispose();
    speakingController.dispose();
  }

  bool _isListeningSection(String section) {
    return IeltsSections.normalize(section) == IeltsSections.listening;
  }

  int _collectionCount(String collection) {
    final item = _dbCollectionSummaries.firstWhere(
      (entry) => (entry['collection'] ?? '').toString() == collection,
      orElse: () => const <String, dynamic>{},
    );
    return (item['count'] as num?)?.toInt() ?? 0;
  }

  String _documentPreview(Map<String, dynamic> document) {
    final buffer = Map<String, dynamic>.from(document);
    buffer.remove('_id');
    final preview = jsonEncode(buffer);
    if (preview.length <= 180) {
      return preview;
    }
    return '${preview.substring(0, 180)}...';
  }

  Future<void> _loadDatabaseCollections({bool refreshDocuments = false}) async {
    setState(() {
      _dbLoading = true;
    });
    try {
      final rows = await ref
          .read(adminServiceProvider)
          .getDatabaseCollectionsSummary();
      final available = rows
          .map((row) => (row['collection'] ?? '').toString())
          .where((value) => value.isNotEmpty)
          .toList();

      var selected = _selectedDbCollection;
      if (!available.contains(selected) && available.isNotEmpty) {
        selected = available.first;
      }

      setState(() {
        _dbCollectionSummaries = rows;
        _selectedDbCollection = selected;
      });

      if (refreshDocuments) {
        _dbPage = 1;
        await _loadDatabaseDocuments();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load database collections.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _dbLoading = false;
        });
      }
    }
  }

  Future<void> _loadDatabaseDocuments() async {
    if (_selectedDbCollection.trim().isEmpty) {
      return;
    }
    setState(() {
      _dbLoading = true;
    });
    try {
      final response = await ref
          .read(adminServiceProvider)
          .listDatabaseDocuments(
            _selectedDbCollection,
            page: _dbPage,
            limit: _dbLimit,
            search: _dbSearchController.text.trim(),
          );
      final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      setState(() {
        _dbDocuments = items;
        _dbTotal = (response['total'] as num?)?.toInt() ?? items.length;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load documents for selected collection.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _dbLoading = false;
        });
      }
    }
  }

  Future<void> _deleteDatabaseDocument(Map<String, dynamic> document) async {
    final documentId = (document['_id'] ?? '').toString();
    if (documentId.isEmpty) {
      return;
    }

    final confirmed = await _confirmDelete(
      title: 'Delete Record',
      message:
          'Delete this document from $_selectedDbCollection? This action cannot be undone.',
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _dbLoading = true;
    });
    try {
      await ref
          .read(adminServiceProvider)
          .deleteDatabaseDocument(_selectedDbCollection, documentId);
      await _loadDatabaseCollections();
      await _loadDatabaseDocuments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete the selected document.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _dbLoading = false;
        });
      }
    }
  }

  Future<void> _pickCreateListeningAudio() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedListeningExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    setState(() {
      _selectedListeningAudioFile = picked.files.first;
    });
  }

  String _listeningAudioState(Map<String, dynamic> question) {
    final listeningAudio =
        question['listeningAudio'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final hasUploaded =
        (listeningAudio['publicUrl'] ?? '').toString().trim().isNotEmpty ||
        (listeningAudio['mediaId'] ?? '').toString().trim().isNotEmpty;
    final hasMediaUrl = (question['mediaUrl'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    if (hasUploaded) {
      return 'uploaded audio';
    }
    if (hasMediaUrl) {
      return 'media URL fallback';
    }
    if (_isListeningSection((question['section'] ?? '').toString())) {
      return 'no audio';
    }
    return 'n/a';
  }

  Future<void> _showEditQuestionDialog(Map<String, dynamic> question) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final id = (question['_id'] ?? '').toString();
    if (id.isEmpty) {
      return;
    }

    final titleController = TextEditingController(
      text: (question['title'] ?? '').toString(),
    );
    final contentController = TextEditingController(
      text: (question['content'] ?? '').toString(),
    );
    final mediaUrlController = TextEditingController(
      text: (question['mediaUrl'] ?? '').toString(),
    );
    var section = IeltsSections.normalize(
      (question['section'] ?? '').toString(),
    );
    var difficulty = (question['difficulty'] ?? 'medium').toString();
    var category = (question['category'] ?? 'general').toString();
    PlatformFile? selectedAudio;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final isListening = _isListeningSection(section);
          return AlertDialog(
            title: const Text('Edit App-Owned Question'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: section,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: IeltsSections.values
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_sectionLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() {
                        section = value;
                        if (!_isListeningSection(section)) {
                          selectedAudio = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Question title',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Question content',
                    ),
                  ),
                  if (isListening) ...<Widget>[
                    const SizedBox(height: 8),
                    TextField(
                      controller: mediaUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Listening media URL fallback',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: _allowedListeningExtensions,
                              withData: true,
                            );
                            if (picked == null || picked.files.isEmpty) {
                              return;
                            }
                            setLocalState(() {
                              selectedAudio = picked.files.first;
                            });
                          },
                          icon: const Icon(Icons.audio_file_outlined),
                          label: Text(
                            selectedAudio == null
                                ? 'Upload/Replace Audio'
                                : 'Replace Selected Audio',
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (selectedAudio != null)
                          OutlinedButton(
                            onPressed: () {
                              setLocalState(() {
                                selectedAudio = null;
                              });
                            },
                            child: const Text('Clear Selection'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (selectedAudio != null)
                      Text('Selected file: ${selectedAudio!.name}')
                    else
                      Text(
                        'Current audio source: ${_listeningAudioState(question)}',
                      ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty ||
                      contentController.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) {
      return;
    }

    if (!_isListeningSection(section) && selectedAudio != null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Listening audio upload is only available for Listening questions.',
          ),
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'section': section,
      'category': category,
      'difficulty': difficulty,
      'questionType': (question['questionType'] ?? 'text').toString(),
      'title': titleController.text.trim(),
      'content': contentController.text.trim(),
      'options': (question['options'] as List<dynamic>? ?? const <dynamic>[]),
      'answerKey':
          (question['answerKey'] as List<dynamic>? ?? const <dynamic>[]),
    };

    final mediaUrl = mediaUrlController.text.trim();
    if (_isListeningSection(section) && mediaUrl.isNotEmpty) {
      payload['mediaUrl'] = mediaUrl;
    }

    // Precedence rule: uploaded listening audio overrides mediaUrl fallback.
    await ref
        .read(adminDashboardControllerProvider.notifier)
        .updateQuestion(
          id,
          payload,
          listeningAudioFile: _isListeningSection(section)
              ? selectedAudio
              : null,
        );
    if (!mounted) return;
    _showActionFeedback();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminDashboardControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);
    final overview = state.overview;

    final studentCount = _count(
      overview,
      'students',
      fallback: _count(overview, 'studentCount'),
    );
    final teacherCount = _count(overview, 'teachers');
    final coachingCount = _count(
      overview,
      'coachings',
      fallback: _count(overview, 'instituteCount'),
    );
    final completedSessions = _count(
      overview,
      'completedSessions',
      fallback: _count(overview, 'sessionsCompleted'),
    );
    final pendingEvaluations = _count(
      overview,
      'pendingEvaluationRequests',
      fallback: state.pendingEvaluations,
    );

    bool shouldShow(AdminDashboardSection section) {
      return widget.section == null || widget.section == section;
    }

    final sectionWidgets = <Widget>[];

    void addSection(AdminDashboardSection section, Widget child) {
      if (!shouldShow(section)) {
        return;
      }
      if (sectionWidgets.isNotEmpty) {
        sectionWidgets.add(const SizedBox(height: 12));
      }
      sectionWidgets.add(child);
    }

    addSection(
      AdminDashboardSection.overview,
      SectionCard(
        title: 'Overview Counts',
        icon: Icons.dashboard,
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          children: <Widget>[
            StatCard(
              label: 'Students',
              value: '$studentCount',
              icon: Icons.school,
            ),
            StatCard(
              label: 'Teachers',
              value: '$teacherCount',
              icon: Icons.person,
            ),
            StatCard(
              label: 'Coachings',
              value: '$coachingCount',
              icon: Icons.apartment,
            ),
            StatCard(
              label: 'Completed Sessions',
              value: '$completedSessions',
              icon: Icons.task_alt,
            ),
            StatCard(
              label: 'Pending Evaluations',
              value: '$pendingEvaluations',
              icon: Icons.rate_review,
            ),
            StatCard(
              label: 'Pending Teacher Approvals',
              value: '${state.pendingTeacherApprovals}',
              icon: Icons.verified_user,
            ),
            StatCard(
              label: 'Pending Payouts',
              value: '${state.pendingPayouts}',
              icon: Icons.payments,
            ),
          ],
        ),
      ),
    );

    addSection(
      AdminDashboardSection.evaluationStats,
      SectionCard(
        title: 'Evaluation Request Statistics',
        icon: Icons.query_stats,
        child: Column(
          children: <Widget>[
            InfoRow(
              label: 'Pending (App-owned)',
              value: '${state.pendingEvaluations}',
              icon: Icons.hourglass_top,
            ),
            InfoRow(
              label: 'Claimed (App-owned)',
              value: '${state.claimedEvaluations}',
              icon: Icons.assignment_ind,
            ),
            InfoRow(
              label: 'Reviewed (App-owned)',
              value: '${state.reviewedEvaluations}',
              icon: Icons.check_circle,
            ),
          ],
        ),
      ),
    );

    addSection(
      AdminDashboardSection.teacherQueue,
      SectionCard(
        title: 'Teacher Approval Queue',
        icon: Icons.how_to_reg,
        child: state.pendingApprovalTeachers.isEmpty
            ? const EmptyStateView(
                title: 'No Pending Teacher Approvals',
                message: 'New teacher approval requests will appear here.',
              )
            : Column(
                children: state.pendingApprovalTeachers.map((teacher) {
                  final teacherId = (teacher['id'] ?? '').toString();
                  final tags =
                      (teacher['teacherProfile']?['expertiseTags']
                                  as List<dynamic>? ??
                              const <dynamic>[])
                          .join(', ');
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${teacher['name'] ?? 'Teacher'} (${teacher['email'] ?? ''})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${teacher['approvalStatus'] ?? 'pending_approval'}',
                          ),
                          if (tags.isNotEmpty) Text('Expertise: $tags'),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      state.isWorking || teacherId.isEmpty
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                adminDashboardControllerProvider
                                                    .notifier,
                                              )
                                              .approveTeacher(teacherId);
                                          if (!mounted) return;
                                          _showActionFeedback();
                                        },
                                  child: const Text('Approve'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed:
                                      state.isWorking || teacherId.isEmpty
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                adminDashboardControllerProvider
                                                    .notifier,
                                              )
                                              .rejectTeacher(
                                                teacherId,
                                                reason: _teacherDecisionNote
                                                    .text
                                                    .trim(),
                                              );
                                          if (!mounted) return;
                                          _showActionFeedback();
                                        },
                                  child: const Text('Reject'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );

    addSection(
      AdminDashboardSection.content,
      SectionCard(
        title: 'Exam-Linked Content Management',
        icon: Icons.inventory_2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildCreateExamCard(state),
            const SizedBox(height: 12),
            _buildCreateQuestionCard(state),
            const SizedBox(height: 12),
            _buildCreateTemplateCard(state),
            const SizedBox(height: 12),
            _buildExamListCard(state),
            const SizedBox(height: 12),
            _buildQuestionListCard(state),
            const SizedBox(height: 12),
            _buildTemplateListCard(state),
          ],
        ),
      ),
    );

    addSection(
      AdminDashboardSection.database,
      SectionCard(
        title: 'Database Manager',
        icon: Icons.storage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Browse and manage database collections directly from admin dashboard.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _dbLoading
                      ? null
                      : () => _showCreateStudentDialog(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Student'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _dbLoading
                      ? null
                      : () => _showCreateTeacherDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Teacher'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _dbLoading
                      ? null
                      : () => _showCreateCoachingDialog(),
                  icon: const Icon(Icons.apartment),
                  label: const Text('Add Coaching'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        _dbCollectionSummaries.any(
                          (row) =>
                              (row['collection'] ?? '').toString() ==
                              _selectedDbCollection,
                        )
                        ? _selectedDbCollection
                        : null,
                    decoration: const InputDecoration(labelText: 'Collection'),
                    items: _dbCollectionSummaries
                        .map(
                          (row) => DropdownMenuItem<String>(
                            value: (row['collection'] ?? '').toString(),
                            child: Text(
                              '${row['collection']} (${(row['count'] as num?)?.toInt() ?? 0})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _dbLoading
                        ? null
                        : (value) async {
                            if (value == null ||
                                value == _selectedDbCollection) {
                              return;
                            }
                            setState(() {
                              _selectedDbCollection = value;
                              _dbPage = 1;
                            });
                            await _loadDatabaseDocuments();
                          },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _dbLoading
                      ? null
                      : () => _loadDatabaseCollections(refreshDocuments: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _dbSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search (name/email/title/status)',
                    ),
                    onSubmitted: (_) async {
                      _dbPage = 1;
                      await _loadDatabaseDocuments();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _dbLoading
                      ? null
                      : () async {
                          _dbPage = 1;
                          await _loadDatabaseDocuments();
                        },
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Showing ${_dbDocuments.length} of $_dbTotal documents. Collection total: ${_collectionCount(_selectedDbCollection)}',
            ),
            const SizedBox(height: 8),
            if (_dbLoading)
              const LinearProgressIndicator()
            else if (_dbDocuments.isEmpty)
              const Text('No records found for selected collection.')
            else
              ..._dbDocuments.map(
                (doc) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.description_outlined),
                  title: Text((doc['_id'] ?? '').toString()),
                  subtitle: Text(_documentPreview(doc)),
                  trailing: IconButton(
                    tooltip: 'Delete record',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _dbLoading
                        ? null
                        : () => _deleteDatabaseDocument(doc),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: _dbLoading || _dbPage <= 1
                      ? null
                      : () async {
                          setState(() {
                            _dbPage = _dbPage - 1;
                          });
                          await _loadDatabaseDocuments();
                        },
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _dbLoading || (_dbPage * _dbLimit) >= _dbTotal
                      ? null
                      : () async {
                          setState(() {
                            _dbPage = _dbPage + 1;
                          });
                          await _loadDatabaseDocuments();
                        },
                  child: const Text('Next'),
                ),
                const SizedBox(width: 12),
                Text('Page $_dbPage'),
              ],
            ),
          ],
        ),
      ),
    );

    addSection(
      AdminDashboardSection.payouts,
      SectionCard(
        title: 'Payout Review Queue',
        icon: Icons.account_balance_wallet,
        child: state.pendingPayoutRequests.isEmpty
            ? const EmptyStateView(
                title: 'No Pending Payout Requests',
                message:
                    'Teacher payout requests will appear here when submitted.',
              )
            : Column(
                children: state.pendingPayoutRequests.map((payout) {
                  final payoutId = (payout['_id'] ?? '').toString();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Teacher: ${payout['teacherId'] ?? '-'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Requested Credits: ${payout['requestedRewardCredits'] ?? 0}',
                          ),
                          Text('Payout Amount: ${payout['payoutAmount'] ?? 0}'),
                          Text('Status: ${payout['status'] ?? 'pending'}'),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton(
                                  onPressed: state.isWorking || payoutId.isEmpty
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                adminDashboardControllerProvider
                                                    .notifier,
                                              )
                                              .approvePayout(
                                                payoutId,
                                                note: _payoutDecisionNote.text
                                                    .trim(),
                                              );
                                          if (!mounted) return;
                                          _showActionFeedback();
                                        },
                                  child: const Text('Approve'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: state.isWorking || payoutId.isEmpty
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                adminDashboardControllerProvider
                                                    .notifier,
                                              )
                                              .rejectPayout(
                                                payoutId,
                                                reason: _payoutDecisionNote.text
                                                    .trim(),
                                              );
                                          if (!mounted) return;
                                          _showActionFeedback();
                                        },
                                  child: const Text('Reject'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );

    addSection(
      AdminDashboardSection.notes,
      SectionCard(
        title: 'Decision Notes',
        icon: Icons.notes,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _teacherDecisionNote,
              decoration: const InputDecoration(
                labelText: 'Optional teacher approval/rejection note',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _payoutDecisionNote,
              decoration: const InputDecoration(
                labelText: 'Optional payout approval/rejection note',
              ),
            ),
          ],
        ),
      ),
    );

    final screenTitle = widget.section == null
        ? 'Platform Admin Console'
        : widget.section!.title;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(screenTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await authController.logout();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AsyncView(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        onRetry: () =>
            ref.read(adminDashboardControllerProvider.notifier).load(),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(adminDashboardControllerProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            children: sectionWidgets,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateExamCard(AdminDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Create App-Owned Exam',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _examTitle,
              decoration: const InputDecoration(labelText: 'Exam title'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: state.isWorking
                  ? null
                  : () async {
                      final title = _examTitle.text.trim();
                      if (title.isEmpty) return;
                      await ref
                          .read(adminDashboardControllerProvider.notifier)
                          .createExam({
                            'title': title,
                            'description': 'Created by platform admin',
                            'type': 'academic',
                            'active': true,
                          });
                      if (!mounted) return;
                      _examTitle.clear();
                      _showActionFeedback();
                    },
              child: const Text('Create Exam'),
            ),
          ],
        ),
      ),
    );
  }

  // _buildCreateQuestionCard and _buildCreateTemplateCard removed - not referenced

  Widget _buildCreateQuestionCard(AdminDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Create App-Owned Question',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _questionTitle,
              decoration: const InputDecoration(labelText: 'Question title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _questionContent,
              decoration: const InputDecoration(labelText: 'Question content'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedSection,
              decoration: const InputDecoration(labelText: 'Section'),
              items: IeltsSections.values
                  .map(
                    (section) => DropdownMenuItem<String>(
                      value: section,
                      child: Text(_sectionLabel(section)),
                    ),
                  )
                  .toList(),
              onChanged: state.isWorking
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedSection = value;
                        if (!_isListeningSection(_selectedSection)) {
                          _selectedListeningAudioFile = null;
                          _questionAudioUrl.clear();
                        }
                      });
                    },
            ),
            if (_isListeningSection(_selectedSection)) ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                controller: _questionAudioUrl,
                decoration: const InputDecoration(
                  labelText: 'Listening media URL fallback',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: state.isWorking
                        ? null
                        : _pickCreateListeningAudio,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: Text(
                      _selectedListeningAudioFile == null
                          ? 'Upload Audio File'
                          : 'Replace Audio File',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedListeningAudioFile != null)
                    OutlinedButton(
                      onPressed: state.isWorking
                          ? null
                          : () {
                              setState(() {
                                _selectedListeningAudioFile = null;
                              });
                            },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _selectedListeningAudioFile == null
                    ? 'No audio file selected. Preview is available after save.'
                    : 'Selected file: ${_selectedListeningAudioFile!.name}',
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: state.isWorking
                  ? null
                  : () async {
                      final title = _questionTitle.text.trim();
                      final content = _questionContent.text.trim();
                      if (title.isEmpty || content.isEmpty) return;

                      final payload = <String, dynamic>{
                        'section': _selectedSection,
                        'category': 'general',
                        'difficulty': 'medium',
                        'questionType': 'text',
                        'title': title,
                        'content': content,
                        'options': <String>[],
                        'answerKey': <String>[],
                      };

                      final audioUrl = _questionAudioUrl.text.trim();
                      if (_isListeningSection(_selectedSection) &&
                          audioUrl.isNotEmpty) {
                        payload['mediaUrl'] = audioUrl;
                      }

                      if (!_isListeningSection(_selectedSection) &&
                          _selectedListeningAudioFile != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Listening audio upload is only available for Listening questions.',
                            ),
                          ),
                        );
                        return;
                      }

                      // Precedence rule: uploaded listening audio overrides mediaUrl fallback.
                      await ref
                          .read(adminDashboardControllerProvider.notifier)
                          .createQuestionWithOptionalListeningAudio(
                            payload,
                            listeningAudioFile:
                                _isListeningSection(_selectedSection)
                                ? _selectedListeningAudioFile
                                : null,
                          );
                      if (!mounted) return;
                      _questionTitle.clear();
                      _questionContent.clear();
                      _questionAudioUrl.clear();
                      setState(() {
                        _selectedListeningAudioFile = null;
                      });
                      _showActionFeedback();
                    },
              child: const Text('Create Question'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTemplateCard(AdminDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Create App-Owned Template',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _templateName,
              decoration: const InputDecoration(labelText: 'Template name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _templateExamType,
              decoration: const InputDecoration(labelText: 'Exam type'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'academic', child: Text('Academic')),
                DropdownMenuItem(value: 'general', child: Text('General')),
              ],
              onChanged: state.isWorking
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _templateExamType = value);
                    },
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _templateEasyRatio,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Easy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _templateMediumRatio,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Medium'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _templateHardRatio,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Hard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: state.isWorking
                  ? null
                  : () async {
                      final name = _templateName.text.trim();
                      if (name.isEmpty) return;

                      await ref
                          .read(adminDashboardControllerProvider.notifier)
                          .createTemplate({
                            'name': name,
                            'examType': _templateExamType,
                            'sectionOrder': [
                              'listening',
                              'reading',
                              'writing',
                              'speaking',
                            ],
                            'difficultyDistribution': {
                              'easy':
                                  double.tryParse(
                                    _templateEasyRatio.text.trim(),
                                  ) ??
                                  0,
                              'medium':
                                  double.tryParse(
                                    _templateMediumRatio.text.trim(),
                                  ) ??
                                  0,
                              'hard':
                                  double.tryParse(
                                    _templateHardRatio.text.trim(),
                                  ) ??
                                  0,
                            },
                            'sectionQuestionCount': {
                              'listening':
                                  int.tryParse(
                                    _templateListening.text.trim(),
                                  ) ??
                                  40,
                              'reading':
                                  int.tryParse(_templateReading.text.trim()) ??
                                  40,
                              'writing':
                                  int.tryParse(_templateWriting.text.trim()) ??
                                  2,
                              'speaking':
                                  int.tryParse(_templateSpeaking.text.trim()) ??
                                  3,
                            },
                            'active': true,
                          });
                      if (!mounted) return;
                      _templateName.clear();
                      _showActionFeedback();
                    },
              child: const Text('Create Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamListCard(AdminDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'App-Owned Exams (${state.exams.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (state.exams.isEmpty)
              const Text('No app-owned exams found.')
            else
              ...state.exams.take(8).map((exam) {
                final id = (exam['_id'] ?? '').toString();
                final title = (exam['title'] ?? '').toString();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(title),
                  subtitle: Text('Type: ${exam['type'] ?? ''} ï¿½ APP-OWNED'),
                  trailing: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Add question for this exam',
                        icon: const Icon(Icons.post_add),
                        onPressed: state.isWorking || id.isEmpty
                            ? null
                            : () =>
                                  _showCreateQuestionForExamDialog(state, exam),
                      ),
                      IconButton(
                        tooltip: 'Add template for this exam',
                        icon: const Icon(Icons.library_add),
                        onPressed: state.isWorking || id.isEmpty
                            ? null
                            : () =>
                                  _showCreateTemplateForExamDialog(state, exam),
                      ),
                      IconButton(
                        tooltip: 'Delete exam',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: state.isWorking || id.isEmpty
                            ? null
                            : () async {
                                await ref
                                    .read(
                                      adminDashboardControllerProvider.notifier,
                                    )
                                    .deleteExam(id);
                                if (!mounted) return;
                                _showActionFeedback();
                              },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionListCard(AdminDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Exam-Linked Questions (${state.questions.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (state.questions.isEmpty)
              const Text('No exam-linked questions found.')
            else
              ...state.questions.take(8).map((question) {
                final id = (question['_id'] ?? '').toString();
                final section = (question['section'] ?? '').toString();
                final examLabel = _examTitleById(
                  state,
                  question['examId']?.toString(),
                );
                final audioState = _listeningAudioState(question);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text((question['title'] ?? '').toString()),
                  subtitle: Text(
                    '$section ï¿½ $examLabel${_isListeningSection(section) ? ' ï¿½ $audioState' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: state.isWorking || id.isEmpty
                            ? null
                            : () => _showEditQuestionDialog(question),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: state.isWorking || id.isEmpty
                            ? null
                            : () async {
                                await ref
                                    .read(
                                      adminDashboardControllerProvider.notifier,
                                    )
                                    .deleteQuestion(id);
                                if (!mounted) return;
                                _showActionFeedback();
                              },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateListCard(AdminDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Exam-Linked Templates (${state.templates.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (state.templates.isEmpty)
              const Text('No exam-linked templates found.')
            else
              ...state.templates.take(8).map((template) {
                final id = (template['_id'] ?? '').toString();
                final active = (template['active'] as bool?) ?? true;
                final examLabel = _examTitleById(
                  state,
                  template['examId']?.toString(),
                );
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text((template['name'] ?? '').toString()),
                  subtitle: Text(
                    'Type: ${template['examType'] ?? ''} ï¿½ $examLabel',
                  ),
                  trailing: Switch(
                    value: active,
                    onChanged: state.isWorking || id.isEmpty
                        ? null
                        : (nextValue) async {
                            await ref
                                .read(adminDashboardControllerProvider.notifier)
                                .toggleTemplateActive(id, nextValue);
                            if (!mounted) return;
                            _showActionFeedback();
                          },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}




