import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachingContentManagementView extends ConsumerStatefulWidget {
  const CoachingContentManagementView({super.key});

  @override
  ConsumerState<CoachingContentManagementView> createState() => _CoachingContentManagementViewState();
}

class _CoachingContentManagementViewState extends ConsumerState<CoachingContentManagementView> {
  static const List<String> _allowedListeningExtensions = <String>[
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'webm',
  ];

  Future<void> _showCreateExamDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'general';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Create Coaching Exam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(
                      value: 'academic',
                      child: Text('Academic'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => type = value);
                  },
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
              onPressed: () {
                if (titleController.text.trim().length < 2) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;
    await ref.read(instituteControllerProvider.notifier).createExam({
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'type': type,
      'active': true,
    });
    if (!mounted) return;
    _showActionFeedback();
  }

  Future<void> _showCreateQuestionForExamDialog(
    Map<String, dynamic> exam,
  ) async {
    final examId = _extractExamId(exam);
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
    var section = 'reading';
    PlatformFile? selectedAudio;

    final created = await showDialog<bool>(
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
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'listening',
                        child: Text('Listening'),
                      ),
                      DropdownMenuItem(
                        value: 'reading',
                        child: Text('Reading'),
                      ),
                      DropdownMenuItem(
                        value: 'writing',
                        child: Text('Writing'),
                      ),
                      DropdownMenuItem(
                        value: 'speaking',
                        child: Text('Speaking'),
                      ),
                    ],
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
                  if (section == 'reading' ||
                      section == 'listening') ...<Widget>[
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
                            'Use commas for multiple answers, e.g. A or A,C',
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

    if (created != true) {
      return;
    }

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      return;
    }

    final isObjectiveQuestion = section == 'reading' || section == 'listening';
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reading and listening questions require options and at least one correct answer.',
          ),
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'examId': examId,
      'section': section,
      'category': 'general',
      'difficulty': 'medium',
      'questionType': isObjectiveQuestion ? 'multiple_choice' : 'text',
      'title': title,
      'content': content,
      'options': options,
      'answerKey': answerKey,
    };
    final audioUrl = audioUrlController.text.trim();
    if (_isListeningSection(section) && audioUrl.isNotEmpty) {
      payload['mediaUrl'] = audioUrl;
    }

    await ref
        .read(instituteControllerProvider.notifier)
        .createQuestionForExam(
          examId,
          payload,
          listeningAudioFile: _isListeningSection(section)
              ? selectedAudio
              : null,
        );
    if (!mounted) return;
    _showActionFeedback();
  }

  Future<void> _showCreateTemplateForExamDialog(
    Map<String, dynamic> exam,
  ) async {
    final examId = _extractExamId(exam);
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

    final created = await showDialog<bool>(
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

    if (created != true || nameController.text.trim().isEmpty) {
      return;
    }

    await ref.read(instituteControllerProvider.notifier).createTemplateForExam(
      examId,
      {
        'name': nameController.text.trim(),
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
      },
    );
    if (!mounted) return;
    _showActionFeedback();
  }

  bool _isListeningSection(String section) {
    return section.trim().toLowerCase() == 'listening';
  }

  String _extractExamId(Map<String, dynamic> item) {
    final direct = (item['examId'] ?? item['_id'] ?? item['id'] ?? '')
        .toString();
    if (direct.isNotEmpty) {
      return direct;
    }
    final exam = item['exam'];
    if (exam is Map<String, dynamic>) {
      return (exam['_id'] ?? exam['id'] ?? '').toString();
    }
    return '';
  }

  List<Map<String, dynamic>> _itemsForExam(
    List<Map<String, dynamic>> items,
    String examId,
  ) {
    return items.where((item) => _extractExamId(item) == examId).toList();
  }

  void _showActionFeedback() {
    final latest = ref.read(instituteControllerProvider);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(instituteControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Content Management'),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                ref.read(instituteControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                        'Coaching-Owned Content',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an exam first. Then add its questions, options, correct answers, and templates inside that exam.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showCreateExamDialog,
                        icon: const Icon(Icons.add_chart),
                        label: const Text('Create Exam'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (state.exams.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No exams found. Create an exam first, then add its questions and templates.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ...state.exams.map((exam) {
                  final examId = _extractExamId(exam);
                  final examQuestions = _itemsForExam(state.questions, examId);
                  final examTemplates = _itemsForExam(state.templates, examId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.assessment),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      (exam['title'] ?? 'Untitled exam')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Type: ${(exam['type'] ?? '').toString()} â€¢ Questions: ${examQuestions.length} â€¢ Templates: ${examTemplates.length}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: examId.isEmpty
                                    ? null
                                    : () async {
                                        await ref
                                            .read(
                                              instituteControllerProvider
                                                  .notifier,
                                            )
                                            .deleteExam(examId);
                                        if (!context.mounted) return;
                                        _showActionFeedback();
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              FilledButton.icon(
                                onPressed: examId.isEmpty
                                    ? null
                                    : () => _showCreateQuestionForExamDialog(
                                        exam,
                                      ),
                                icon: const Icon(Icons.quiz),
                                label: const Text('Add Question'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: examId.isEmpty
                                    ? null
                                    : () => _showCreateTemplateForExamDialog(
                                        exam,
                                      ),
                                icon: const Icon(Icons.post_add),
                                label: const Text('Add Template'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}




